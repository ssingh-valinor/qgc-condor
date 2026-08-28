import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Manual confirmation that the RTL return altitude suits the site. The value tracks the parameter, so
// editing RTL_RETURN_ALT updates the prompt, but a check the operator has already passed stays passed.
PreFlightCheckButton {
    name:       qsTr("RTL Altitude")
    manualText: _returnAltFact ?
                    qsTr("Return climbs to %1. Clear of obstacles at your site?").arg(_returnAltFact.valueString + " " + _returnAltFact.units) :
                    qsTr("Confirm the return altitude is clear of obstacles at your site.")

    FactPanelController { id: controller }

    property Fact _returnAltFact: controller.parameterExists(-1, "RTL_RETURN_ALT") ?
                                      controller.getParameterFact(-1, "RTL_RETURN_ALT") :
                                      null
}
