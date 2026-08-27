import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Toolbar indicator showing the vehicle's current CONOP (concept of operations). Clicking it
// drops down the list of available CONOPs, each of which maps to a parameter file.
//
// This is the UI layer only: selecting a CONOP records the choice and remembers which parameter
// file backs it. Pushing those parameters to the vehicle, and the reboot prompt which follows,
// are not wired up yet.
Item {
    id:                     control
    Layout.preferredWidth:  mainLayout.width

    property bool showIndicator:    true

    property real fontPointSize:    ScreenTools.largeFontPointSize
    property var  activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle

    // Index into conopModel of the CONOP currently selected, or -1 when unknown
    property int  _currentConopIndex:   -1
    property int  _fileChooserIndex:    -1
    property var  _appSettings:         QGroundControl.settingsManager.appSettings

    property string _currentConopName:  _currentConopIndex === -1 ?
                                            qsTr("Unknown") :
                                            conopModel.get(_currentConopIndex).name

    QGCPalette { id: qgcPal }

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

    /// Opens the file picker to choose the parameter file backing the given CONOP.
    function chooseParamFile(index) {
        _fileChooserIndex = index
        mainWindow.closeIndicatorDrawer()
        fileDialog.title = qsTr("Select Parameter File for %1").arg(conopModel.get(index).name)
        fileDialog.openForLoad()
    }

    /// Makes the given CONOP the active one. Choose its parameter file first if it doesn't have one.
    function selectConop(index) {
        if (conopModel.get(index).paramFile === "") {
            chooseParamFile(index)
            return
        }
        _currentConopIndex = index
        mainWindow.closeIndicatorDrawer()
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
            if (control._fileChooserIndex !== -1) {
                conopModel.setProperty(control._fileChooserIndex, "paramFile", file)
                control._currentConopIndex = control._fileChooserIndex
                control._fileChooserIndex = -1
            }
        }

        onRejected: control._fileChooserIndex = -1
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
                    Layout.fillWidth:   true
                    spacing:            0

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            Layout.fillWidth:   true
                            text:               name
                            checked:            index === control._currentConopIndex
                            onClicked:          control.selectConop(index)
                        }

                        QGCButton {
                            text:       qsTr("File…")
                            onClicked:  control.chooseParamFile(index)
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               paramFile === "" ? qsTr("No parameter file selected") : control.baseName(paramFile)
                        font.pointSize:     ScreenTools.smallFontPointSize
                        color:              paramFile === "" ? qgcPal.colorOrange : qgcPal.text
                        elide:              Text.ElideMiddle
                    }
                }
            }
        }
    }
}
