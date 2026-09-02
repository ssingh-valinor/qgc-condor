import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Toolbar indicator showing the vehicle's current CONOP (concept of operations). Clicking it
// drops down the list of available CONOPs; clicking a CONOP picks the parameter file which
// defines it, and Send applies that file's parameters to the vehicle.
Item {
    id:                     control
    Layout.preferredWidth:  mainLayout.width

    property bool showIndicator:    true

    property real fontPointSize:    ScreenTools.largeFontPointSize
    property var  activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle

    // Index into conopModel of the CONOP last applied to the vehicle, or -1 when unknown
    property int  _currentConopIndex:   -1
    // Index into conopModel of the CONOP whose file is loaded in the controller. Only one file can
    // be loaded at a time, since the controller holds a single diff against the vehicle.
    property int  _loadedConopIndex:    -1
    property int  _fileChooserIndex:    -1
    property var  _appSettings:         QGroundControl.settingsManager.appSettings

    property string _currentConopName:  _currentConopIndex === -1 ?
                                            qsTr("Unknown") :
                                            conopModel.get(_currentConopIndex).name

    QGCPalette { id: qgcPal }

    ConopController { id: conopController }

    ListModel {
        id: conopModel

        ListElement { name: qsTr("Test Flight");     paramFile: "" }
        ListElement { name: qsTr("Dropper");         paramFile: "" }
        ListElement { name: qsTr("HAB");             paramFile: "" }
        ListElement { name: qsTr("Terminal Strike"); paramFile: "" }
    }

    function baseName(filePath) {
        return filePath.substring(filePath.lastIndexOf("/") + 1)
    }

    /// Opens the file picker to choose the parameter file which defines the given CONOP.
    function chooseParamFile(index) {
        _fileChooserIndex = index
        mainWindow.closeIndicatorDrawer()
        fileDialog.title = qsTr("Select Parameter File for %1").arg(conopModel.get(index).name)
        fileDialog.openForLoad()
    }

    Connections {
        target: conopController

        function onSendComplete(sentCount, rebootParamNames) {
            const index = control._loadedConopIndex
            control._currentConopIndex = index

            // Rebuild the diff against the vehicle's now-current values. A write which failed was
            // refreshed from the vehicle by ParameterManager, so it shows up as still differing.
            if (index !== -1) {
                conopController.loadFile(conopModel.get(index).paramFile)
            }

            if (rebootParamNames.length === 0) {
                return
            }

            QGroundControl.showMessageDialog(control, qsTr("CONOP Applied"),
                                             qsTr("%1 parameters sent. Reboot the vehicle for the following to take effect:\n\n%2")
                                                .arg(sentCount).arg(rebootParamNames.join(", ")),
                                             Dialog.Cancel | Dialog.Ok,
                                             function() {
                                                 if (control.activeVehicle) {
                                                     control.activeVehicle.rebootVehicle()
                                                 }
                                             })
        }
    }

    RowLayout {
        id:                     mainLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing:                ScreenTools.defaultFontPixelWidth / 2

        QGCColoredImage {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 3
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            color:                  qgcPal.text
            source:                 "/res/GearWithPaperPlane.svg"
        }

        QGCLabel {
            text:           control._currentConopName
            color:          qgcPal.text
            font.pointSize: fontPointSize
        }

        // Distinguishes this indicator from the flight mode indicator sitting next to it
        QGCLabel {
            Layout.alignment:       Qt.AlignVCenter
            horizontalAlignment:    Text.AlignHCenter
            text:                   qsTr("CONOP")
            font.pointSize:         ScreenTools.smallFontPointSize
        }
    }

    MouseArea {
        anchors.fill:   mainLayout
        onClicked:      mainWindow.showIndicatorDrawer(drawerComponent, control)
    }

    // Lives outside the drawer component so it survives the drawer closing as the picker opens
    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings.parameterSavePath
        nameFilters:    [ qsTr("Parameter Files (*.%1 *.param)").arg(_appSettings.parameterFileExtension), qsTr("All Files (*)") ]

        onAcceptedForLoad: (file) => {
            close()
            if (control._fileChooserIndex === -1) {
                return
            }
            const index = control._fileChooserIndex
            control._fileChooserIndex = -1

            if (!conopController.loadFile(file)) {
                return
            }
            conopModel.setProperty(index, "paramFile", file)
            control._loadedConopIndex = index
        }

        onRejected: control._fileChooserIndex = -1
    }

    QGCPopupDialogFactory {
        id:                 sendDialogFactory
        dialogComponent:    sendDialogComponent
    }

    Component {
        id: sendDialogComponent

        ConopSendDialog {
            controller: conopController
            conopName:  control._loadedConopIndex === -1 ? "" : conopModel.get(control._loadedConopIndex).name
        }
    }

    Component {
        id: drawerComponent

        ToolIndicatorPage {
            contentComponent: conopContentComponent
        }
    }

    Component {
        id: conopContentComponent

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("CONOP")
                font.bold:          true
            }

            Repeater {
                model: conopModel

                ColumnLayout {
                    id:                 conopRow
                    Layout.fillWidth:   true
                    spacing:            0

                    property bool isLoaded: index === control._loadedConopIndex

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            Layout.fillWidth:   true
                            text:               name
                            checked:            index === control._currentConopIndex
                            enabled:            !conopController.sending
                            onClicked:          control.chooseParamFile(index)
                        }

                        QGCButton {
                            text:       qsTr("Send")
                            visible:    conopRow.isLoaded
                            enabled:    conopController.canSend

                            onClicked: {
                                mainWindow.closeIndicatorDrawer()
                                sendDialogFactory.open()
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth:   true
                        font.pointSize:     ScreenTools.smallFontPointSize
                        elide:              Text.ElideMiddle
                        color:              paramFile === "" ? qgcPal.colorGrey : qgcPal.text
                        text: {
                            if (paramFile === "") {
                                return qsTr("No parameter file loaded")
                            }
                            if (!conopRow.isLoaded) {
                                return control.baseName(paramFile)
                            }
                            if (conopController.sendableCount === 0) {
                                return qsTr("%1 — all %2 parameters match the vehicle")
                                        .arg(control.baseName(paramFile))
                                        .arg(conopController.parsedCount)
                            }
                            return qsTr("%1 — %2 of %3 parameters will change")
                                    .arg(control.baseName(paramFile))
                                    .arg(conopController.sendableCount)
                                    .arg(conopController.parsedCount)
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:       true
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 40
                font.pointSize:         ScreenTools.smallFontPointSize
                wrapMode:               Text.WordWrap
                color:                  qgcPal.colorOrange
                visible:                control.activeVehicle && control.activeVehicle.armed
                text:                   qsTr("Disarm the vehicle to apply a CONOP.")
            }

            QGCLabel {
                Layout.fillWidth:   true
                font.pointSize:     ScreenTools.smallFontPointSize
                visible:            conopController.sending
                text:               qsTr("Sending parameters…")
            }
        }
    }
}
