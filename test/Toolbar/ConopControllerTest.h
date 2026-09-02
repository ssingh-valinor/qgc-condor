#pragma once

#include "BaseClasses/ParameterTest.h"

class ConopControllerTest : public ParameterTest
{
    Q_OBJECT

private slots:
    void _loadFileBuildsDiff();
    void _loadFileWithNoRebootParams();
    void _clearDiscardsDiff();
    void _sendAppliesParametersAndReportsReboot();
};
