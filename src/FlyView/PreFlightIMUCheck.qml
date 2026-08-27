import QtQuick

import QGroundControl
import QGroundControl.Controls

/// Confirms the flight controller is streaming IMU data. This checks that samples are arriving, not
/// that they are correct - sensor health itself is reported by PreFlightSensorsHealthCheck.
PreFlightCheckButton {
    name:                   qsTr("IMU")
    telemetryFailure:       !_imuStreaming
    telemetryTextFailure:   qsTr("No IMU data. Check autopilot connection.")

    property bool _imuStreaming: globals.activeVehicle ? globals.activeVehicle.imuDataStreaming : false
}
