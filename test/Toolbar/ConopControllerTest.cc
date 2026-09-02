#include "ConopControllerTest.h"

#include <QtTest/QSignalSpy>
#include <QtTest/QTest>

#include "ConopController.h"
#include "Fact.h"
#include "Fixtures/RAIIFixtures.h"
#include "QmlObjectListModel.h"
#include "UnitTest.h"

UT_REGISTER_TEST(ConopControllerTest, TestLabel::Integration, TestLabel::Vehicle)

// CONOP file changing one reboot-required parameter (SYS_AUTOSTART 4001 → 4002), one which takes
// effect immediately (MPC_XY_VEL_MAX 12 → 8) and one which already matches the vehicle.
static const char *kConopParams =
    "# Onboard parameters for Vehicle 1\n"
    "#\n"
    "# Vehicle-Id Component-Id Name Value Type\n"
    "1\t1\tSYS_AUTOSTART\t4002\t6\n"
    "1\t1\tMPC_XY_VEL_MAX\t8.0\t9\n"
    "1\t1\tBAT_LOW_THR\t0.150000005960464478\t9\n";

// CONOP file changing only a parameter which takes effect without a reboot
static const char *kConopParamsNoReboot =
    "# Onboard parameters for Vehicle 1\n"
    "#\n"
    "# Vehicle-Id Component-Id Name Value Type\n"
    "1\t1\tMPC_XY_VEL_MAX\t8.0\t9\n";

void ConopControllerTest::_loadFileBuildsDiff()
{
    TestFixtures::TempFileFixture tempFile(QStringLiteral("conop_XXXXXX.params"));
    QVERIFY(tempFile.isValid());
    QVERIFY(tempFile.write(QByteArray(kConopParams)));
    QVERIFY(tempFile.file()->flush());

    ConopController controller;
    QVERIFY(!controller.fileLoaded());
    QVERIFY(!controller.canSend());

    QVERIFY(controller.loadFile(tempFile.path()));
    QVERIFY(controller.fileLoaded());
    QCOMPARE(controller.parsedCount(), 3);
    QCOMPARE(controller.sendableCount(), 2);
    QCOMPARE(controller.unchangedCount(), 1);
    QCOMPARE(controller.noVehicleCount(), 0);
    QVERIFY(controller.canSend());

    // Only the reboot-required parameter is reported, and only because it is actually changing -
    // the unchanged parameter never becomes a diff row
    QCOMPARE(controller.rebootParamNames(), QStringList{ QStringLiteral("SYS_AUTOSTART") });
}

void ConopControllerTest::_loadFileWithNoRebootParams()
{
    TestFixtures::TempFileFixture tempFile(QStringLiteral("conop_XXXXXX.params"));
    QVERIFY(tempFile.isValid());
    QVERIFY(tempFile.write(QByteArray(kConopParamsNoReboot)));
    QVERIFY(tempFile.file()->flush());

    ConopController controller;
    QVERIFY(controller.loadFile(tempFile.path()));
    QCOMPARE(controller.sendableCount(), 1);
    QVERIFY(controller.rebootParamNames().isEmpty());
}

void ConopControllerTest::_clearDiscardsDiff()
{
    TestFixtures::TempFileFixture tempFile(QStringLiteral("conop_XXXXXX.params"));
    QVERIFY(tempFile.isValid());
    QVERIFY(tempFile.write(QByteArray(kConopParams)));
    QVERIFY(tempFile.file()->flush());

    ConopController controller;
    QVERIFY(controller.loadFile(tempFile.path()));
    QVERIFY(controller.canSend());

    controller.clear();
    QVERIFY(!controller.fileLoaded());
    QVERIFY(!controller.canSend());
    QCOMPARE(controller.sendableCount(), 0);
    QVERIFY(controller.rebootParamNames().isEmpty());
}

void ConopControllerTest::_sendAppliesParametersAndReportsReboot()
{
    TestFixtures::TempFileFixture tempFile(QStringLiteral("conop_XXXXXX.params"));
    QVERIFY(tempFile.isValid());
    QVERIFY(tempFile.write(QByteArray(kConopParams)));
    QVERIFY(tempFile.file()->flush());

    Fact *const autostartFact = getFact(QStringLiteral("SYS_AUTOSTART"));
    Fact *const velMaxFact = getFact(QStringLiteral("MPC_XY_VEL_MAX"));
    QVERIFY(autostartFact);
    QVERIFY(velMaxFact);
    QCOMPARE(autostartFact->rawValue().toInt(), 4001);

    ConopController controller;
    QVERIFY(controller.loadFile(tempFile.path()));

    QSignalSpy sendCompleteSpy(&controller, &ConopController::sendComplete);
    QVERIFY(sendCompleteSpy.isValid());

    controller.send();
    QVERIFY(controller.sending());

    // Completion waits for every write to be acked and for the persist settle time to elapse
    QVERIFY_SIGNAL_WAIT(sendCompleteSpy, TestTimeout::mediumMs());
    QCOMPARE(sendCompleteSpy.count(), 1);
    QVERIFY(!controller.sending());

    const QList<QVariant> args = sendCompleteSpy.takeFirst();
    QCOMPARE(args.at(0).toInt(), 2);
    QCOMPARE(args.at(1).toStringList(), QStringList{ QStringLiteral("SYS_AUTOSTART") });

    // The writes went through the Facts the parameter editor is bound to, so the values the rest
    // of the UI shows have changed along with the vehicle's
    QCOMPARE(autostartFact->rawValue().toInt(), 4002);
    QCOMPARE(velMaxFact->rawValue().toFloat(), 8.0f);
}
