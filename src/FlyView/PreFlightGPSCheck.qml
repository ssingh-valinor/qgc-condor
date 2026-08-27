import QtQuick

import QGroundControl
import QGroundControl.Controls

PreFlightCheckButton {
    name:                   qsTr("GPS")
    telemetryFailure:       _noGpsFailure || _satCountFailure
    // A low sat count on top of a valid 3D fix is shown as a warning rather than a hard failure, but
    // it still blocks the check. Neither state can be clicked past.
    telemetryWarning:       !_noGpsFailure && _satCountFailure
    telemetryTextFailure:   _noGpsFailure ?
                                qsTr("No GPS / sat") :
                                qsTr("Sat count below %1").arg(minSatCount)

    property int    minSatCount:        5   ///< Sat count required to pass once a 3D fix is available

    property bool   _noGpsFailure:      globals.activeVehicle ? globals.activeVehicle.gps.lock.rawValue < 3 : true
    property int    _satCount:          globals.activeVehicle ? globals.activeVehicle.gps.count.rawValue : 0
    property bool   _satCountFailure:   _satCount < minSatCount
}
