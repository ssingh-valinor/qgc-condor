#include "ConopController.h"
#include "AppMessages.h"
#include "Fact.h"
#include "MultiVehicleManager.h"
#include "ParameterEditorController.h"
#include "ParameterManager.h"
#include "QGCLoggingCategory.h"
#include "QmlObjectListModel.h"
#include "Vehicle.h"

QGC_LOGGING_CATEGORY(ConopControllerLog, "Toolbar.ConopController")

ConopController::ConopController(QObject *parent)
    : QObject(parent)
    , _persistSettleMs(QGC::runningUnitTests() ? 50 : kPersistSettleMs)
{
    _sendTimer.setInterval(kSendIntervalMs);
    (void) connect(&_sendTimer, &QTimer::timeout, this, &ConopController::_sendNextRow);

    _persistSettleTimer.setInterval(_persistSettleMs);
    _persistSettleTimer.setSingleShot(true);
    (void) connect(&_persistSettleTimer, &QTimer::timeout, this, &ConopController::_finishSend);

    (void) connect(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged, this, &ConopController::_activeVehicleChanged);
    _activeVehicleChanged(MultiVehicleManager::instance()->activeVehicle());
}

ConopController::~ConopController()
{

}

void ConopController::_activeVehicleChanged(Vehicle *activeVehicle)
{
    if (_vehicle == activeVehicle) {
        return;
    }

    if (_vehicle) {
        (void) disconnect(_vehicle, nullptr, this, nullptr);
        (void) disconnect(_vehicle->parameterManager(), nullptr, this, nullptr);
    }

    _sendTimer.stop();
    _persistSettleTimer.stop();
    _waitingForPersist = false;
    _fileLoaded = false;
    _setSending(false);

    // ParameterEditorController binds to the vehicle it was constructed against, and a diff is only
    // meaningful for the vehicle it was built from, so both are discarded on a vehicle change. The
    // model is released to QML before it is destroyed so no binding is left holding a dead object.
    ParameterEditorController *const staleController = _paramEditorController;
    _paramEditorController = nullptr;

    _vehicle = activeVehicle;
    if (_vehicle) {
        (void) connect(_vehicle, &Vehicle::armedChanged, this, &ConopController::canSendChanged);
        (void) connect(_vehicle->parameterManager(), &ParameterManager::pendingWritesChanged, this, &ConopController::_pendingWritesChanged);
    }

    emit diffChanged();
    emit canSendChanged();

    if (staleController) {
        staleController->deleteLater();
    }
}

QmlObjectListModel *ConopController::diffList() const
{
    return _paramEditorController ? _paramEditorController->diffList() : nullptr;
}

int ConopController::parsedCount() const
{
    return _paramEditorController ? _paramEditorController->diffParsedCount() : 0;
}

int ConopController::unchangedCount() const
{
    return _paramEditorController ? _paramEditorController->diffUnchangedCount() : 0;
}

int ConopController::sendableCount() const
{
    return _paramEditorController ? _paramEditorController->diffSendableCount() : 0;
}

int ConopController::noVehicleCount() const
{
    return _paramEditorController ? _paramEditorController->diffNoVehicleCount() : 0;
}

bool ConopController::canSend() const
{
    // A bulk parameter write followed by a reboot must not be reachable in flight. The vehicle
    // agrees: PX4 defers writing parameters to flash while armed.
    return _fileLoaded && !_sending && _vehicle && !_vehicle->armed() && (sendableCount() > 0);
}

QStringList ConopController::rebootParamNames() const
{
    QStringList names;

    const QmlObjectListModel *const diff = diffList();
    if (!diff || !_vehicle) {
        return names;
    }

    ParameterManager *const paramMgr = _vehicle->parameterManager();
    for (int i = 0; i < diff->count(); i++) {
        const ParameterEditorDiff *const paramDiff = diff->value<ParameterEditorDiff*>(i);
        if (paramDiff->cannotSend || !paramDiff->load) {
            continue;
        }

        // A parameter the vehicle has never reported has no metadata to consult, so whether it
        // needs a reboot is unknown. Callers are told about those separately via noVehicleCount.
        if (!paramMgr->parameterExists(paramDiff->componentId, paramDiff->name)) {
            continue;
        }

        const Fact *const fact = paramMgr->getParameter(paramDiff->componentId, paramDiff->name);
        if (fact && fact->vehicleRebootRequired()) {
            names.append(paramDiff->name);
        }
    }

    return names;
}

bool ConopController::loadFile(const QString &filename)
{
    if (_sending) {
        qCWarning(ConopControllerLog) << "loadFile ignored, send in progress";
        return false;
    }

    if (!_vehicle) {
        qCWarning(ConopControllerLog) << "loadFile ignored, no active vehicle";
        return false;
    }

    if (!_paramEditorController) {
        _paramEditorController = new ParameterEditorController(this);
    }

    _fileLoaded = _paramEditorController->buildDiffFromFile(filename);
    if (!_fileLoaded) {
        _paramEditorController->clearDiff();
    }

    qCDebug(ConopControllerLog) << "loadFile:" << filename << "loaded:" << _fileLoaded
        << "parsed:" << parsedCount() << "sendable:" << sendableCount();

    emit diffChanged();
    emit canSendChanged();

    return _fileLoaded;
}

void ConopController::clear()
{
    _sendTimer.stop();
    _persistSettleTimer.stop();
    _waitingForPersist = false;
    _fileLoaded = false;
    if (_paramEditorController) {
        _paramEditorController->clearDiff();
    }

    _setSending(false);
    emit diffChanged();
    emit canSendChanged();
}

void ConopController::send()
{
    if (!canSend()) {
        qCWarning(ConopControllerLog) << "send ignored - fileLoaded:" << _fileLoaded << "sending:" << _sending
            << "sendable:" << sendableCount();
        return;
    }

    // Captured up front: the flags are read from live Facts, whose values change as writes land
    _sendRebootParamNames = rebootParamNames();
    _sendRowIndex = 0;
    _sentCount = 0;

    qCDebug(ConopControllerLog) << "send starting - rows:" << diffList()->count()
        << "sendable:" << sendableCount() << "rebootRequired:" << _sendRebootParamNames.count();

    _setSending(true);
    _sendTimer.start();
}

void ConopController::_sendNextRow()
{
    const QmlObjectListModel *const diff = diffList();
    if (!diff) {
        // The diff went away underneath the send (vehicle change). Nothing to report.
        _sendTimer.stop();
        _setSending(false);
        return;
    }

    if (_sendRowIndex >= diff->count()) {
        _sendTimer.stop();
        qCDebug(ConopControllerLog) << "send dispatched - sent:" << _sentCount << "waiting for acks";

        // Nothing left to dispatch. Wait for the outstanding writes to be acked, then give the
        // vehicle time to persist them, before reporting completion.
        ParameterManager *const paramMgr = _vehicle ? _vehicle->parameterManager() : nullptr;
        if (paramMgr && paramMgr->pendingWrites()) {
            _waitingForPersist = true;
        } else {
            _persistSettleTimer.start();
        }
        return;
    }

    if (_paramEditorController->sendDiffRow(_sendRowIndex, true /* suppressRebootMessaging */)) {
        _sentCount++;
    }
    _sendRowIndex++;
}

void ConopController::_pendingWritesChanged(bool pendingWrites)
{
    if (!_waitingForPersist || pendingWrites) {
        return;
    }

    _waitingForPersist = false;
    qCDebug(ConopControllerLog) << "send acked - waiting" << _persistSettleMs << "ms for the vehicle to persist";
    _persistSettleTimer.start();
}

void ConopController::_finishSend()
{
    qCDebug(ConopControllerLog) << "send complete - sent:" << _sentCount
        << "rebootRequired:" << _sendRebootParamNames.count();

    _setSending(false);
    emit sendComplete(_sentCount, _sendRebootParamNames);
}

void ConopController::_setSending(bool sending)
{
    if (_sending == sending) {
        return;
    }

    _sending = sending;
    emit sendingChanged();
    emit canSendChanged();
}
