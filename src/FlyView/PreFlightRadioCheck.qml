import QtQuick

import QGroundControl
import QGroundControl.Controls

/// Confirms the flight controller is streaming RC channel data. This checks that frames are arriving,
/// not that a transmitter is bound and powered on.
PreFlightCheckButton {
    name:                   qsTr("Radio")
    telemetryFailure:       !_rcStreaming
    telemetryTextFailure:   qsTr("No RC data. Check receiver and console.")

    property bool _rcStreaming: globals.activeVehicle ? globals.activeVehicle.rcDataStreaming : false
}
