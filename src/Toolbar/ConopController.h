#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QStringList>
#include <QtCore/QTimer>
#include <QtQmlIntegration/QtQmlIntegration>

class ParameterEditorController;
class QmlObjectListModel;
class Vehicle;

Q_DECLARE_LOGGING_CATEGORY(ConopControllerLog)

/// \brief Applies a CONOP (concept of operations) parameter file to the vehicle.
///
/// Parsing and diffing reuse ParameterEditorController, so a CONOP file is an ordinary QGC
/// parameter file and only the parameters which actually differ from the vehicle are sent.
///
/// The send differs from a plain parameter editor load in three ways:
///     - writes are paced rather than dispatched all at once, so a bulk apply does not flood a
///       low bandwidth telemetry link and provoke write retries
///     - Fact's per-parameter reboot prompt is suppressed in favour of the single consolidated
///       prompt the UI raises once the whole apply has settled
///     - completion waits for every write to be acked and persisted before a reboot is offered,
///       since rebooting mid-write loses parameters
class ConopController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QmlObjectListModel  *diffList         READ diffList           NOTIFY diffChanged)
    Q_PROPERTY(bool                 fileLoaded       READ fileLoaded         NOTIFY diffChanged)
    Q_PROPERTY(int                  parsedCount      READ parsedCount        NOTIFY diffChanged)
    Q_PROPERTY(int                  unchangedCount   READ unchangedCount     NOTIFY diffChanged)
    Q_PROPERTY(int                  sendableCount    READ sendableCount      NOTIFY diffChanged)
    Q_PROPERTY(int                  noVehicleCount   READ noVehicleCount     NOTIFY diffChanged)
    Q_PROPERTY(QStringList          rebootParamNames READ rebootParamNames   NOTIFY diffChanged)
    Q_PROPERTY(bool                 sending          READ sending            NOTIFY sendingChanged)
    Q_PROPERTY(bool                 canSend          READ canSend            NOTIFY canSendChanged)

public:
    explicit ConopController(QObject *parent = nullptr);
    ~ConopController();

    /// Parses the given parameter file and builds the diff against the vehicle.
    /// @return true: file parsed, diff available
    Q_INVOKABLE bool loadFile(const QString &filename);

    /// Discards the loaded file and its diff.
    Q_INVOKABLE void clear();

    /// Sends the loaded diff to the vehicle. sendComplete is emitted once every write has been
    /// acked and the vehicle has had time to persist it.
    Q_INVOKABLE void send();

    QmlObjectListModel *diffList() const;
    bool fileLoaded() const { return _fileLoaded; }
    int parsedCount() const;
    int unchangedCount() const;
    int sendableCount() const;
    int noVehicleCount() const;
    bool sending() const { return _sending; }
    bool canSend() const;

    /// Names of the parameters in the diff which need a vehicle reboot to take effect.
    QStringList rebootParamNames() const;

signals:
    void diffChanged();
    void sendingChanged();
    void canSendChanged();

    /// Every write has been dispatched, acked and persisted by the vehicle.
    ///     @param sentCount        Number of parameters written
    ///     @param rebootParamNames Parameters needing a reboot to take effect, empty if none do
    void sendComplete(int sentCount, const QStringList &rebootParamNames);

private slots:
    void _activeVehicleChanged(Vehicle *activeVehicle);
    void _sendNextRow();
    void _pendingWritesChanged(bool pendingWrites);

private:
    void _setSending(bool sending);
    void _finishSend();

    /// Interval between parameter writes. Paces a bulk apply so a slow link is not asked to carry
    /// the whole diff at once.
    static constexpr int kSendIntervalMs = 50;

    /// Settle time after the last write is acked, before the vehicle is considered to have
    /// persisted the parameters. PX4 debounces its parameter save by 300 ms and rate limits saves
    /// to one every 2 seconds, so a reboot offered any sooner can drop the last writes.
    static constexpr int kPersistSettleMs = 3000;

    const int _persistSettleMs;             ///< 50 ms in unit tests, kPersistSettleMs otherwise

    QPointer<Vehicle> _vehicle;
    ParameterEditorController *_paramEditorController = nullptr;
    QTimer _sendTimer;
    QTimer _persistSettleTimer;
    QStringList _sendRebootParamNames;
    int _sendRowIndex = 0;
    int _sentCount = 0;
    bool _fileLoaded = false;
    bool _sending = false;
    bool _waitingForPersist = false;
};
