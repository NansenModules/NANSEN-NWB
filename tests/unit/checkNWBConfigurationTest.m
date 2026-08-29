classdef checkNWBConfigurationTest < matlab.unittest.TestCase
%checkNWBConfigurationTest - Tests for checkNWBConfiguration
%
%   Tests nansen.module.nwb.file.checkNWBConfiguration, which reports
%   unfilled configuration columns and missing required NWB metadata
%   properties.
%
%   The column checks run against the module alone. Anything that resolves
%   a neurodata type also needs matnwb and the NANSEN utility packages, so
%   those tests are filtered when either is unavailable.
%
%   See also: nansen.module.nwb.file.checkNWBConfiguration

    properties (TestParameter)

        % Each unfilled column, as both an empty value and a placeholder.
        unsetColumn = struct( ...
            'placeholderPrimaryGroup', struct( ...
                'FieldName', "PrimaryGroupName", ...
                'Value', "<Select group>", ...
                'Message', "Primary group is not set"), ...
            'emptyPrimaryGroup', struct( ...
                'FieldName', "PrimaryGroupName", ...
                'Value', '', ...
                'Message', "Primary group is not set"), ...
            'placeholderNwbModule', struct( ...
                'FieldName', "NwbModule", ...
                'Value', "<Select module>", ...
                'Message', "NWB module is not set"), ...
            'emptyNwbModule', struct( ...
                'FieldName', "NwbModule", ...
                'Value', '', ...
                'Message', "NWB module is not set"), ...
            'placeholderNeuroDataType', struct( ...
                'FieldName', "NeuroDataType", ...
                'Value', "<Select type>", ...
                'Message', "Neurodata type is not set"), ...
            'emptyNeuroDataType', struct( ...
                'FieldName', "NeuroDataType", ...
                'Value', '', ...
                'Message', "Neurodata type is not set"))

        % Ways a required property can be present but unusable. Each case
        % is a TimeSeries, whose required properties are data and
        % data_unit.
        incompleteMetadata = struct( ...
            'absentProperty', struct( ...
                'Metadata', struct("data", [1 2 3]), ...
                'ReportedProperty', "data_unit"), ...
            'blankString', struct( ...
                'Metadata', struct("data", [1 2 3], "data_unit", "   "), ...
                'ReportedProperty', "data_unit"), ...
            'zeroLengthString', struct( ...
                'Metadata', struct("data", [1 2 3], "data_unit", ""), ...
                'ReportedProperty', "data_unit"), ...
            'emptyNumeric', struct( ...
                'Metadata', struct("data", [], "data_unit", "volts"), ...
                'ReportedProperty', "data"))
    end

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test) % Column checks - module only

        function emptyConfigurationReturnsNoWarnings(testCase)
            warnings = validateConfiguration(struct([]));

            testCase.verifyEmpty(warnings)
            testCase.verifyClass(warnings, "cell")
        end

        function unsetColumnIsReported(testCase, unsetColumn)
            item = createConfigurationItem();
            item.(unsetColumn.FieldName) = unsetColumn.Value;

            warnings = validateConfiguration(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, unsetColumn.Message)
        end

        function unsetNeuroDataTypeSuppressesMetadataChecks(testCase)
        % Without a type there is no schema to check metadata against, so
        % the item must yield exactly one warning even though its
        % metadata is empty.

            item = createConfigurationItem( ...
                NeuroDataType="<Select type>", DefaultMetadata='');

            warnings = validateConfiguration(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, "Neurodata type is not set")
        end

        function multipleUnsetColumnsAreEachReported(testCase)
            item = createConfigurationItem( ...
                PrimaryGroupName="<Select group>", ...
                NwbModule="<Select module>", ...
                NeuroDataType="<Select type>");

            warnings = validateConfiguration(item);

            testCase.verifyNumElements(warnings, 3)
        end

        function warningIdentifiesTheVariable(testCase)
        % Warnings are shown in a dialog listing every problem at once, so
        % each line has to name the variable it refers to.

            item = createConfigurationItem( ...
                VariableName="WheelData", PrimaryGroupName="<Select group>");

            warnings = validateConfiguration(item);

            testCase.verifySubstring(warnings{1}, "WheelData")
        end

        function eachItemInArrayIsChecked(testCase)
            items = [ ...
                createConfigurationItem( ...
                    VariableName="Eeg", PrimaryGroupName="<Select group>"), ...
                createConfigurationItem( ...
                    VariableName="WheelData", NwbModule="<Select module>")];

            warnings = validateConfiguration(items);

            testCase.verifyNumElements(warnings, 2)
            testCase.verifySubstring(warnings{1}, "Eeg")
            testCase.verifySubstring(warnings{2}, "WheelData")
        end

        function unresolvableNeuroDataTypeIsIgnored(testCase)
        % Current behaviour: a type name that cannot be resolved is
        % swallowed and produces no warning. Documented here so a change
        % in that behaviour is a deliberate one.

            item = createConfigurationItem(NeuroDataType="NotARealNeurodataType");

            warnings = validateConfiguration(item);

            testCase.verifyEmpty(warnings)
        end
    end

    methods (Test) % Metadata checks - matnwb required

        function completeConfigurationReturnsNoWarnings(testCase)
            testCase.assumeSchemaLookupIsAvailable()

            warnings = validateConfiguration(createConfigurationItem());

            testCase.verifyEmpty(warnings)
        end

        function incompleteRequiredPropertyIsReported(testCase, incompleteMetadata)
            testCase.assumeSchemaLookupIsAvailable()

            item = createConfigurationItem( ...
                DefaultMetadata=incompleteMetadata.Metadata);

            warnings = validateConfiguration(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, ...
                """" + incompleteMetadata.ReportedProperty + """")
        end

        function emptyMetadataReportsEveryRequiredProperty(testCase)
        % Saved configurations carry '' rather than a struct until
        % metadata has been entered.

            testCase.assumeSchemaLookupIsAvailable()

            item = createConfigurationItem(DefaultMetadata='');

            warnings = validateConfiguration(item);

            testCase.verifyNumElements(warnings, 2)
            testCase.verifySubstring(strjoin(warnings, newline), """data""")
            testCase.verifySubstring(strjoin(warnings, newline), """data_unit""")
        end

        function warningNamesTheNeuroDataType(testCase)
            testCase.assumeSchemaLookupIsAvailable()

            item = createConfigurationItem( ...
                NeuroDataType="SpatialSeries", DefaultMetadata='');

            warnings = validateConfiguration(item);

            testCase.verifySubstring(warnings{1}, "SpatialSeries")
        end

        function typeWithoutRequiredPropertiesReturnsNoWarnings(testCase)
        % Device has no required properties, so empty metadata is fine.

            testCase.assumeSchemaLookupIsAvailable()

            item = createConfigurationItem( ...
                NeuroDataType="Device", DefaultMetadata='');

            warnings = validateConfiguration(item);

            testCase.verifyEmpty(warnings)
        end

        function columnAndMetadataWarningsAreCombined(testCase)
            testCase.assumeSchemaLookupIsAvailable()

            item = createConfigurationItem( ...
                PrimaryGroupName="<Select group>", ...
                DefaultMetadata=struct("data", [1 2 3]));

            warnings = validateConfiguration(item);

            testCase.verifyNumElements(warnings, 2)
            testCase.verifySubstring(warnings{1}, "Primary group is not set")
            testCase.verifySubstring(warnings{2}, """data_unit""")
        end
    end

    methods (Access = private)

        function assumeSchemaLookupIsAvailable(testCase)
            testCase.assumeNotEmpty( ...
                which("schemes.internal.getRequiredPropsForClass"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty( ...
                which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
            testCase.assumeNotEmpty( ...
                which("utility.string.getSimpleClassName"), ...
                "The NANSEN utility packages are not on the MATLAB path.")
        end
    end
end

function warnings = validateConfiguration(dataItems)
    warnings = nansen.module.nwb.file.checkNWBConfiguration(dataItems);
end

function item = createConfigurationItem(options)
% createConfigurationItem - Build a fully populated configuration item,
%   overriding any field named as a Name=Value argument.

    arguments
        options.VariableName = "Eeg"
        options.PrimaryGroupName = "Acquisition"
        options.NwbModule = "ecephys"
        options.NeuroDataType = "TimeSeries"
        options.DefaultMetadata = struct("data", [1 2 3], "data_unit", "volts")
    end

    item = options;
end

function folderPath = repositoryRoot()
    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
