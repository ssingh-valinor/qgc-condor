import QtQuick
import QtQuick.Controls
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    property var model: listModel
    PreFlightCheckModel {
        id:             listModel
        // Let the operator open any group at will instead of unlocking them one at a time
        enforceOrder:   false
        PreFlightCheckGroup {
            name: qsTr("First Flight")

            PreFlightCheckButton {
                name:           qsTr("Motor")
                manualText:     qsTr("Motor direction?")
            }

            PreFlightCheckButton {
                name:           qsTr("Prop")
                manualText:     qsTr("Prop installation?")
            }

            PreFlightCheckButton {
                name:           qsTr("Tail")
                manualText:     qsTr("Tail secured?")
            }

            PreFlightRTLAltCheck {
            }

            PreFlightRCCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Automated Checks")

            PreFlightBatteryCheck {
                failurePercent: 40
            }

            PreFlightSensorsHealthCheck {
            }

            PreFlightIMUCheck {
            }

            PreFlightRadioCheck {
            }

            PreFlightGPSCheck {
                minSatCount: 5
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Please arm the vehicle here")

            PreFlightCheckButton {
                name:            qsTr("Actuators")
                manualText:      qsTr("Move all control surfaces. Did they work properly?")
            }

            PreFlightCheckButton {
                name:            qsTr("Motors")
                manualText:      qsTr("Propellers free? Then throttle up gently. Working properly?")
            }

            PreFlightCheckButton {
                name:        qsTr("Mission")
                manualText:  qsTr("Please confirm mission is valid (waypoints valid, no terrain collision).")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Last preparations before launch")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:        qsTr("Payload")
                manualText:  qsTr("Configured and started? Payload lid closed?")
            }

            PreFlightCheckButton {
                name:        "Wind & weather"
                manualText:  qsTr("OK for your platform? Lauching into the wind?")
            }

            PreFlightCheckButton {
                name:        qsTr("Flight area")
                manualText:  qsTr("Launch area and path free of obstacles/people?")
            }
        }
    }
}
