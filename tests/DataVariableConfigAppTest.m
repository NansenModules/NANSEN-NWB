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
            configFilePath = fullfile(fixture.Folder, 'nwb-config.json');

            nwbConfigurationData = testCase.createConfiguration();
            nwbConfigurationData.GeneralMetadata.institution = "Vervaeke Lab";
            nansen.module.nwb.config.saveConfiguration( ...
                nansen.module.nwb.config.NwbFileConfiguration.fromStruct(nwbConfigurationData), ...
                string(configFilePath))

            app = nansen.module.nwb.gui.uifigure.DataVariableConfigApp( ...
                nwbConfigurationData, ...
                'FilePath', string(configFilePath), ...
                'Visible', 'off');
            cleanupObj = onCleanup(@() delete(app)); %#ok<NASGU>

            app.addVariable("WheelData")
            app.saveNwbConfigurationData()

            savedData = nansen.module.nwb.config.loadConfiguration(string(configFilePath));

            testCase.verifyEqual(numel(savedData.DataItems), 3)
            testCase.verifyEqual(string(savedData.GeneralMetadata.institution), "Vervaeke Lab")
            testCase.verifyFalse(app.IsDirty)
        end
    end

    methods
        function assumeCanRunModernUi(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(testCase.getRepoRoot()))
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
        function repoRoot = getRepoRoot()
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
        end

        function nwbConfigurationData = createConfiguration()
            nwbConfigurationData = struct();
            nwbConfigurationData = nansen.module.nwb.config.NwbFileConfiguration().toStruct();
            nwbConfigurationData.AllVariableNames = {'Eeg', 'LineScan', 'WheelData'};

            defaultItem = nansen.module.nwb.file.getDefaultFileConfigurationItem();
            dataItems = repmat(defaultItem, 1, 2);

            dataItems(1).VariableName = 'Eeg';
            dataItems(1).NWBVariableName = 'Eeg';
            dataItems(1).PrimaryGroup = 'Acquisition';
            dataItems(1).NwbModule = 'ecephys';
            dataItems(1).TargetNwbType = 'ElectricalSeries';

            dataItems(2).VariableName = 'LineScan';
            dataItems(2).NWBVariableName = 'LineScan';
            dataItems(2).PrimaryGroup = 'Acquisition';
            dataItems(2).NwbModule = 'ophys';
            dataItems(2).TargetNwbType = 'ImageSeries';

            nwbConfigurationData.DataItems = dataItems;
        end
    end
end
