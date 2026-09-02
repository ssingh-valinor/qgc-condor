import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Confirmation shown before a CONOP's parameters are sent to the vehicle. Lists every parameter
// which will change, read-only, so a wrong file is obvious before anything is written.
QGCPopupDialog {
    id:         root
    title:      qsTr("Apply %1").arg(root.conopName)
    buttons:    Dialog.Cancel | Dialog.Ok

    required property var    controller
    required property string conopName

    property var  qgcPal:            QGroundControl.globalPalette
    property var  _rebootParamNames: controller.rebootParamNames
    property real _contentWidth:     ScreenTools.defaultFontPixelWidth * 60

    onAccepted: root.controller.send()

    ColumnLayout {
        spacing: ScreenTools.defaultDialogControlSpacing

        QGCLabel {
            Layout.preferredWidth:  root._contentWidth
            wrapMode:               Text.WordWrap
            text: {
                var clauses = [ qsTr("%1 will be changed").arg(root.controller.sendableCount) ]
                if (root.controller.unchangedCount > 0) {
                    clauses.push(qsTr("%1 already match the vehicle").arg(root.controller.unchangedCount))
                }
                if (root.controller.noVehicleCount > 0) {
                    clauses.push(qsTr("%1 not currently on the vehicle").arg(root.controller.noVehicleCount))
                }
                return qsTr("Loaded %1 parameters: %2.").arg(root.controller.parsedCount).arg(clauses.join(", "))
            }
        }

        QGCLabel {
            Layout.preferredWidth:  root._contentWidth
            wrapMode:               Text.WordWrap
            color:                  root.qgcPal.colorOrange
            visible:                root._rebootParamNames.length > 0
            text:                   root._rebootParamNames.length === 1
                                        ? qsTr("1 of these needs a vehicle reboot to take effect. You will be offered the reboot once the parameters have been sent.")
                                        : qsTr("%1 of these need a vehicle reboot to take effect. You will be offered the reboot once the parameters have been sent.").arg(root._rebootParamNames.length)
        }

        QGCFlickable {
            Layout.preferredWidth:  root._contentWidth
            Layout.preferredHeight: Math.min(paramGrid.height, root.maxContentAvailableHeight * 0.5)
            contentWidth:           paramGrid.width
            contentHeight:          paramGrid.height
            visible:                root.controller.diffList && root.controller.diffList.count > 0

            GridLayout {
                id:             paramGrid
                width:          root._contentWidth
                rows:           root.controller.diffList ? root.controller.diffList.count + 1 : 1
                columns:        4
                flow:           GridLayout.TopToBottom
                rowSpacing:     0
                columnSpacing:  ScreenTools.defaultFontPixelWidth

                QGCLabel { text: qsTr("Name"); font.bold: true }
                Repeater {
                    model: root.controller.diffList
                    QGCLabel { text: object.name }
                }

                QGCLabel { text: qsTr("Vehicle"); font.bold: true }
                Repeater {
                    model: root.controller.diffList
                    QGCLabel {
                        text: object.cannotSend ? qsTr("N/A — not on vehicle") :
                              object.noVehicleValue ? qsTr("N/A — new to vehicle") :
                              object.vehicleValue + " " + object.units
                    }
                }

                QGCLabel { text: qsTr("File"); font.bold: true }
                Repeater {
                    model: root.controller.diffList
                    QGCLabel { text: object.fileValue + " " + object.units }
                }

                QGCLabel { text: qsTr("Reboot"); font.bold: true }
                Repeater {
                    model: root.controller.diffList
                    QGCLabel {
                        text:   root._rebootParamNames.indexOf(object.name) === -1 ? "" : qsTr("Required")
                        color:  root.qgcPal.colorOrange
                    }
                }
            }
        }
    }
}
