classdef ValidateNwbConfigurationTest < matlab.unittest.TestCase
% ValidateNwbConfigurationTest - Unit tests for validateNwbConfiguration
%
%   Tests nansen.module.nwb.file.validateNwbConfiguration, which reports
%   unfilled configuration columns and missing required NWB metadata
%   properties.
%
%   Tests covering the column checks run without matnwb. Tests covering
%   the metadata checks need matnwb on the path and are filtered out when
%   it is unavailable.
%
%   See also: nansen.module.nwb.file.validateNwbConfiguration

    methods (Test) % Column checks - no matnwb required

        function emptyConfigurationReturnsNoWarnings(testCase)
            warnings = testCase.validate(struct([]));

            testCase.verifyEmpty(warnings)
            testCase.verifyClass(warnings, "cell")
        end

        function placeholderPrimaryGroupIsReported(testCase)
        % Unfilled table cells hold a placeholder in angle brackets.

            item = testCase.createItem("PrimaryGroupName", "<Select group>");

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, "Primary group is not set")
        end

        function emptyPrimaryGroupIsReported(testCase)
            item = testCase.createItem("PrimaryGroupName", '');

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, "Primary group is not set")
        end

        function placeholderNwbModuleIsReported(testCase)
            item = testCase.createItem("NwbModule", "<Select module>");

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, "NWB module is not set")
        end

        function unsetNeuroDataTypeIsReported(testCase)
            item = testCase.createItem("NeuroDataType", "<Select type>");

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, "Neurodata type is not set")
        end

        function unsetNeuroDataTypeSuppressesMetadataChecks(testCase)
        % Without a type there is no schema to check metadata against, so
        % the item must yield exactly one warning even though its
        % metadata is empty.

            item = testCase.createItem( ...
                "NeuroDataType", "<Select type>", ...
                "DefaultMetadata", '');

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, "Neurodata type is not set")
        end

        function multipleUnsetColumnsAreEachReported(testCase)
            item = testCase.createItem( ...
                "PrimaryGroupName", "<Select group>", ...
                "NwbModule", "<Select module>", ...
                "NeuroDataType", "<Select type>");

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 3)
        end

        function warningIdentifiesTheVariable(testCase)
        % Warnings are shown in a dialog listing every problem at once, so
        % each line has to name the variable it refers to.

            item = testCase.createItem( ...
                "VariableName", "WheelData", ...
                "PrimaryGroupName", "<Select group>");

            warnings = testCase.validate(item);

            testCase.verifySubstring(warnings{1}, "WheelData")
        end

        function eachItemInArrayIsChecked(testCase)
            items = [ ...
                testCase.createItem("VariableName", "Eeg", ...
                    "PrimaryGroupName", "<Select group>"), ...
                testCase.createItem("VariableName", "WheelData", ...
                    "NwbModule", "<Select module>")];

            warnings = testCase.validate(items);

            testCase.verifyNumElements(warnings, 2)
            testCase.verifySubstring(warnings{1}, "Eeg")
            testCase.verifySubstring(warnings{2}, "WheelData")
        end

        function unresolvableNeuroDataTypeIsIgnored(testCase)
        % Current behaviour: a type name that cannot be resolved is
        % swallowed and produces no warning. Documented here so a change
        % in that behaviour is a deliberate one.

            item = testCase.createItem("NeuroDataType", "NotARealNeurodataType");

            warnings = testCase.validate(item);

            testCase.verifyEmpty(warnings)
        end
    end

    methods (Test) % Metadata checks - matnwb required

        function completeConfigurationReturnsNoWarnings(testCase)
            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem("DefaultMetadata", ...
                struct("data", [1 2 3], "data_unit", "volts"));

            warnings = testCase.validate(item);

            testCase.verifyEmpty(warnings)
        end

        function emptyMetadataReportsEveryRequiredProperty(testCase)
        % Saved configurations carry '' rather than a struct until
        % metadata has been entered.

            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem("DefaultMetadata", '');

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 2)
            testCase.verifySubstring(strjoin(warnings, newline), """data""")
            testCase.verifySubstring(strjoin(warnings, newline), """data_unit""")
        end

        function absentRequiredPropertyIsReported(testCase)
            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem("DefaultMetadata", ...
                struct("data", [1 2 3]));

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, """data_unit""")
        end

        function blankRequiredPropertyIsReported(testCase)
        % A whitespace-only value counts as unset.

            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem("DefaultMetadata", ...
                struct("data", [1 2 3], "data_unit", "   "));

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, """data_unit""")
        end

        function emptyNumericRequiredPropertyIsReported(testCase)
            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem("DefaultMetadata", ...
                struct("data", [], "data_unit", "volts"));

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 1)
            testCase.verifySubstring(warnings{1}, """data""")
        end

        function warningNamesTheNeuroDataType(testCase)
            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem( ...
                "NeuroDataType", "SpatialSeries", ...
                "DefaultMetadata", '');

            warnings = testCase.validate(item);

            testCase.verifySubstring(warnings{1}, "SpatialSeries")
        end

        function typeWithoutRequiredPropertiesReturnsNoWarnings(testCase)
        % Device has no required properties, so empty metadata is fine.

            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem( ...
                "NeuroDataType", "Device", ...
                "DefaultMetadata", '');

            warnings = testCase.validate(item);

            testCase.verifyEmpty(warnings)
        end

        function columnAndMetadataWarningsAreCombined(testCase)
            testCase.assumeMatNwbIsAvailable()

            item = testCase.createItem( ...
                "PrimaryGroupName", "<Select group>", ...
                "DefaultMetadata", struct("data", [1 2 3]));

            warnings = testCase.validate(item);

            testCase.verifyNumElements(warnings, 2)
            testCase.verifySubstring(warnings{1}, "Primary group is not set")
            testCase.verifySubstring(warnings{2}, """data_unit""")
        end
    end

    methods (Access = private)

        function warnings = validate(~, dataItems)
            warnings = nansen.module.nwb.file.validateNwbConfiguration(dataItems);
        end

        function assumeMatNwbIsAvailable(testCase)
            testCase.assumeNotEmpty( ...
                which("schemes.internal.getRequiredPropsForClass"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty( ...
                which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
        end

        function item = createItem(~, varargin)
        % createItem - Build a valid configuration item, overriding fields
        %   named in the Name=Value arguments.

            item = struct( ...
                "VariableName", "Eeg", ...
                "PrimaryGroupName", "Acquisition", ...
                "NwbModule", "ecephys", ...
                "NeuroDataType", "TimeSeries", ...
                "DefaultMetadata", struct("data", [1 2 3], "data_unit", "volts"));

            for i = 1:2:numel(varargin)
                item.(varargin{i}) = varargin{i+1};
            end
        end
    end
end
