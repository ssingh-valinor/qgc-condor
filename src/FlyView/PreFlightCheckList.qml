import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

ColumnLayout {
    spacing: 0.8 * ScreenTools.defaultFontPixelWidth

    property real _verticalMargin: ScreenTools.defaultFontPixelHeight / 2

    Loader {
        id:     modelContainer
        source: "qrc:/qml/QGroundControl/FlyView/DefaultChecklist.qml"
    }

    property bool allChecksPassed:  false
    property var  vehicleCopy:      globals.activeVehicle

    // Some airframes offer alternative checklists which the operator picks between, such as a VTOL first
    // flight versus flying again after a previous flight. Each entry is a { name, source } pair. A list with
    // a single entry means the airframe has nothing to select and the selector stays hidden.
    property var    _checklistVariants: []
    property int    _variantIndex:      0
    property string _variantsKey:       ""    ///< Identifies the current variant list so airframe changes can be detected

    onVehicleCopyChanged: {
        if (checkListRepeater.model) {
            checkListRepeater.model.reset()
        }
    }

    onAllChecksPassedChanged: {
        if (globals.activeVehicle) {
            globals.activeVehicle.checkListState = allChecksPassed ? Vehicle.CheckListPassed : Vehicle.CheckListFailed
        }
    }

    function _handleGroupPassedChanged(index, passed) {
        // Checklists which enforce ordering walk the operator through one group at a time, collapsing each
        // as it passes. Checklists which don't leave every group open for the operator to expand at will.
        if (passed && checkListRepeater.model && checkListRepeater.model.enforceOrder) {
            // Collapse current group
            var group = checkListRepeater.itemAt(index)
            group._checked = false
            // Expand next group
            if (index + 1 < checkListRepeater.count) {
                group = checkListRepeater.itemAt(index + 1)
                group.enabled = true
                group._checked = true
            }
        }

        // Walk the list and check if any group is failing
        var allPassed = true
        for (var i=0; i < checkListRepeater.count; i++) {
            if (!checkListRepeater.itemAt(i).passed) {
                allPassed = false
                break
            }
        }
        allChecksPassed = allPassed;
    }

    function _variant(name, fileName) {
        return { name: name, source: "qrc:/qml/QGroundControl/FlyView/" + fileName }
    }

    //-- Pick the checklist variants that match the current airframe type (if any)
    function _updateModel() {
        var vehicle = globals.activeVehicle
        if (!vehicle) {
            vehicle = QGroundControl.multiVehicleManager.offlineEditingVehicle
        }

        var variants
        if (vehicle.multiRotor) {
            variants = [ _variant(qsTr("Multirotor"), "MultiRotorChecklist.qml") ]
        } else if (vehicle.vtol) {
            variants = [ _variant(qsTr("First Flight"),       "VTOLFirstFlightChecklist.qml"),
                         _variant(qsTr("Subsequent Flights"), "VTOLSubsequentFlightsChecklist.qml") ]
        } else if (vehicle.rover) {
            variants = [ _variant(qsTr("Rover"), "RoverChecklist.qml") ]
        } else if (vehicle.sub) {
            variants = [ _variant(qsTr("Sub"), "SubChecklist.qml") ]
        } else if (vehicle.fixedWing) {
            variants = [ _variant(qsTr("Fixed Wing"), "FixedWingChecklist.qml") ]
        } else {
            variants = [ _variant(qsTr("Generic"), "DefaultChecklist.qml") ]
        }

        // Only reset the selection when the airframe changed. Reopening the popup must not throw away a
        // checklist the operator already worked through.
        var variantsKey = variants.map(function(variant) { return variant.source }).join(",")
        if (variantsKey !== _variantsKey) {
            _variantsKey        = variantsKey
            _checklistVariants  = variants
            _selectVariant(0)
        }
    }

    function _selectVariant(index) {
        if (index < 0 || index >= _checklistVariants.length) {
            return
        }
        _variantIndex = index

        // Switching to a different checklist invalidates whatever the operator had already confirmed
        var source = _checklistVariants[index].source
        if (modelContainer.source.toString() !== source) {
            allChecksPassed         = false
            modelContainer.source   = source
        }
    }

    Component.onCompleted: {
        _updateModel()
    }

    onVisibleChanged: {
        if(globals.activeVehicle) {
            if(visible) {
                _updateModel()
            }
        }
    }

    // We delay the updates when a group passes so the user can see all items green for a moment prior to hiding
    Timer {
        id:         delayedGroupPassed
        interval:   750

        property int index

        onTriggered: _handleGroupPassedChanged(index, true /* passed */)
    }

    function groupPassedChanged(index, passed) {
        if (passed) {
            delayedGroupPassed.index = index
            delayedGroupPassed.restart()
        } else {
            _handleGroupPassedChanged(index, passed)
        }
    }

    // Checklist selector, only shown for airframes which offer more than one checklist
    RowLayout {
        Layout.fillWidth:   true
        spacing:            ScreenTools.defaultFontPixelWidth * 2
        visible:            _checklistVariants.length > 1

        Repeater {
            model: _checklistVariants

            QGCRadioButton {
                text:       modelData.name
                checked:    index === _variantIndex
                onClicked:  _selectVariant(index)
            }
        }
    }

    // Header/title of checklist
    RowLayout {
        Layout.fillWidth:   true
        height:             1.75 * ScreenTools.defaultFontPixelHeight
        spacing:            0

        QGCLabel {
            Layout.fillWidth:   true
            text:               allChecksPassed ? qsTr("(Passed)") : qsTr("In Progress")
            font.pointSize:     ScreenTools.mediumFontPointSize
        }
        QGCButton {
            width:              1.2 * ScreenTools.defaultFontPixelHeight
            height:             1.2 * ScreenTools.defaultFontPixelHeight
            Layout.alignment:   Qt.AlignVCenter
            onClicked:          checkListRepeater.model.reset()

            QGCColoredImage {
                source:         "/qmlimages/MapSyncBlack.svg"
                color:          qgcPal.buttonText
                anchors.fill:   parent
            }
        }
    }

    // All check list items
    Repeater {
        id:     checkListRepeater
        model:  modelContainer.item.model
    }
}
