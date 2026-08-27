import QtQuick

import QGroundControl
import QGroundControl.Controls

// This class stores the data and functions of the check list but NOT the GUI (which is handled somewhere else).
PreFlightCheckButton {
    name:                   qsTr("Battery")
    telemetryFailure:       _batLow
    telemetryTextFailure:   qsTr("Battery charge below %1%. Please recharge.").arg(failurePercent)

    property int    failurePercent:         40  ///< Charge required to pass. Below this the check fails and cannot be clicked past.

    property var    _batteryGroup:          globals.activeVehicle && globals.activeVehicle.batteries.count ? globals.activeVehicle.batteries.get(0) : undefined
    property var    _batteryValue:          _batteryGroup ? _batteryGroup.percentRemaining.value : 0
    property var    _batPercentRemaining:   isNaN(_batteryValue) ? 0 : _batteryValue
    property bool   _batLow:                _batPercentRemaining < failurePercent
}
