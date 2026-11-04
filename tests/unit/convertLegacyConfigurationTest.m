classdef convertLegacyConfigurationTest < matlab.unittest.TestCase
%convertLegacyConfigurationTest - Tests for convertLegacyConfiguration
%
%   Tests nansen.module.nwb.config.convertLegacyConfiguration, which turns
%   the data items of a pilot .mat configuration into an
%   NWBFileConfiguration.
%
%   A pilot item that named its own converter function must not be left
%   for the runner to resolve: the converter it picks may do something
%   else entirely. It either gets the registered equivalent or keeps the
%   function's name, which the runner reports as an unknown converter.
%
%   See also: nansen.module.nwb.config.convertLegacyConfiguration

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function mapsAPilotConverterToItsRegisteredEquivalent(testCase)
            item = legacyItem("TwoPhotonSeries_Original", ...
                "nansen.module.nwb.mixin.nwbconverter.convertGeneralTwoPhotonSeries");

            config = convert(item);

            testCase.verifyEqual(config.DataItems(1).ConverterName, "TwoPhotonImageStack")
        end

        function keepsTheNameOfAPilotConverterWithNoEquivalent(testCase)
            converterFunction = "nansen.module.nwb.mixin.nwbconverter.convertVideo";
            item = legacyItem("BehaviorVideo", converterFunction);

            config = testCase.verifyWarning(@() convert(item), ...
                "nansen:nwb:legacyConverterNotCarriedOver");

            testCase.verifyEqual(config.DataItems(1).ConverterName, converterFunction)
        end

        function leavesTheDefaultConverterToTheRunner(testCase)
            config = convert(legacyItem("speed", "Default"));

            testCase.verifyEqual(config.DataItems(1).ConverterName, "")
            testCase.verifyEqual(config.DataItems(1).TargetNWBType, "TimeSeries")
        end
    end
end

function config = convert(legacyItems)
%convert - Shorthand for the function under test

    config = nansen.module.nwb.config.convertLegacyConfiguration(legacyItems);
end

function item = legacyItem(variableName, converter)
%legacyItem - One data item as the pilot configurator saved it

    item = struct( ...
        "VariableName", variableName, ...
        "NWBVariableName", variableName, ...
        "PrimaryGroupName", "Acquisition", ...
        "NwbModule", "", ...
        "NeuroDataType", "TimeSeries", ...
        "DefaultMetadata", struct(), ...
        "Converter", converter);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
