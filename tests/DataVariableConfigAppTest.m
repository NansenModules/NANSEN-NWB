classdef DataVariableConfigAppTest < matlab.unittest.TestCase

    methods (Test)
        function constructInitializesData(testCase)
            testCase.assumeCanRunModernUi()

            app = nansen.module.nwb.gui.uifigure.DataVariableConfigApp( ...
                testCase.createConfiguration(), ...
                'Visible', 'off');
            cleanupObj = onCleanup(@() delete(app)); %#ok<NASGU>

            testCase.verifyEqual(height(app.Data), 2)
            testCase.verifyFalse(app.IsDirty)
        end

        function addVariableUpdatesDataAndDirtyState(testCase)
            testCase.assumeCanRunModernUi()

            app = nansen.module.nwb.gui.uifigure.DataVariableConfigApp( ...
                testCase.createConfiguration(), ...
                'Visible', 'off');
            cleanupObj = onCleanup(@() delete(app)); %#ok<NASGU>

            app.addVariable("WheelData")

            testCase.verifyEqual(height(app.Data), 3)
            testCase.verifyEqual(app.Data.VariableName{3}, 'WheelData')
            testCase.verifyTrue(app.IsDirty)
        end

        function saveReplacesOnlyDataItems(testCase)
            testCase.assumeCanRunModernUi()

            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            configFilePath = fullfile(fixture.Folder, 'nwb-config.mat');

            nwbConfigurationData = testCase.createConfiguration();
            nwbConfigurationData.General.Subject = "Mouse-001";
            save(configFilePath, 'nwbConfigurationData')

            app = nansen.module.nwb.gui.uifigure.DataVariableConfigApp( ...
                nwbConfigurationData, ...
                'FilePath', string(configFilePath), ...
                'Visible', 'off');
            cleanupObj = onCleanup(@() delete(app)); %#ok<NASGU>

            app.addVariable("WheelData")
            app.saveNwbConfigurationData()

            savedData = load(configFilePath, 'nwbConfigurationData');

            testCase.verifyEqual(numel(savedData.nwbConfigurationData.DataItems), 3)
            testCase.verifyEqual(savedData.nwbConfigurationData.General.Subject, "Mouse-001")
            testCase.verifyFalse(app.IsDirty)
        end
    end

    methods
        function assumeCanRunModernUi(testCase)
            testCase.assumeFalse( ...
                verLessThan('matlab', '24.1'), ...
                'Modern data-variable app requires MATLAB R2024a or newer.')
            testCase.assumeEqual( ...
                exist('WidgetTable', 'class'), 8, ...
                'WidgetTable is not available on the MATLAB path.')

            requiredMethods = ["setCellOptions", "getCellComponent"];
            availableMethods = string(methods('WidgetTable'));
            testCase.assumeTrue( ...
                all(ismember(requiredMethods, availableMethods)), ...
                'WidgetTable does not provide the required cell-options API.')
        end
    end

    methods (Static)
        function nwbConfigurationData = createConfiguration()
            nwbConfigurationData = struct();
            nwbConfigurationData.Name = "Processed";
            nwbConfigurationData.Description = "Processed Data for Sharing";
            nwbConfigurationData.AllVariableNames = {'Eeg', 'LineScan', 'WheelData'};

            defaultItem = nansen.module.nwb.file.getDefaultFileConfigurationItem();
            dataItems = repmat(defaultItem, 1, 2);

            dataItems(1).VariableName = 'Eeg';
            dataItems(1).NWBVariableName = 'Eeg';
            dataItems(1).PrimaryGroupName = 'acquisition';
            dataItems(1).NwbModule = 'ecephys';
            dataItems(1).NeuroDataType = 'ElectricalSeries';

            dataItems(2).VariableName = 'LineScan';
            dataItems(2).NWBVariableName = 'LineScan';
            dataItems(2).PrimaryGroupName = 'acquisition';
            dataItems(2).NwbModule = 'ophys';
            dataItems(2).NeuroDataType = 'ImageSeries';

            nwbConfigurationData.DataItems = dataItems;
        end
    end
end
