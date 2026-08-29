classdef NWBFileConfigurationTest < matlab.unittest.TestCase
%NWBFileConfigurationTest - Tests for the NWB conversion configuration
%
%   Tests nansen.module.nwb.config.NWBFileConfiguration and its data
%   items, together with the JSON they are saved as.
%
%   Round-tripping carries most of the weight. JSON loses the difference
%   between a scalar and a one-element array, and jsondecode returns
%   scalar objects and cell-wrapped values in places MATLAB did not put
%   them, so a configuration that survives one item can still fail on
%   two.
%
%   See also: nansen.module.nwb.config.NWBFileConfiguration

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test) % Round-tripping through JSON

        function roundTripsAConfigurationWithOneItem(testCase)
            % A single item encodes as a JSON object rather than an array,
            % which is the shape most likely to come back wrong.
            original = configurationWith(dataItem("speed"));

            restored = saveAndLoad(testCase, original);

            testCase.verifyNumElements(restored.DataItems, 1)
            testCase.verifyEqual(restored.DataItems(1).VariableName, "speed")
        end

        function roundTripsAConfigurationWithSeveralItems(testCase)
            original = configurationWith([dataItem("speed"), dataItem("licks")]);

            restored = saveAndLoad(testCase, original);

            testCase.verifyEqual([restored.DataItems.VariableName], ["speed", "licks"])
        end

        function roundTripsAConfigurationWithNoItems(testCase)
            original = nansen.module.nwb.config.NWBFileConfiguration( ...
                OutputPath="/tmp/empty.nwb");

            restored = saveAndLoad(testCase, original);

            testCase.verifyEmpty(restored.DataItems)
        end

        function roundTripsItemsWhoseMetadataDiffers(testCase)
            % Metadata is free-form per converter, so two items in one
            % configuration need not carry the same fields.
            first = dataItem("speed");
            first.Metadata = struct("description", "running speed", "rate", 30);
            second = dataItem("licks");
            second.Metadata = struct("unit", "count");

            restored = saveAndLoad(testCase, configurationWith([first, second]));

            testCase.verifyEqual(restored.DataItems(1).Metadata.rate, 30)
            testCase.verifyEqual(string(restored.DataItems(2).Metadata.unit), "count")
        end

        function roundTripsSourceEvidence(testCase)
            item = dataItem("recording");
            item.SourceInfo.MatlabClass = "nansen.stack.ImageStack";
            item.SourceInfo.Format = "ScanImage";
            item.SourceInfo.Path = ["/data/a.tif", "/data/b.tif"];

            restored = saveAndLoad(testCase, configurationWith(item));

            sourceInfo = restored.DataItems(1).SourceInfo;
            testCase.verifyEqual(sourceInfo.Format, "ScanImage")
            testCase.verifyEqual(sourceInfo.Path, ["/data/a.tif", "/data/b.tif"])
        end

        function writesJsonAPersonCanRead(testCase)
            % Configurations go into version control, so the file has to
            % diff sensibly rather than sit on one line.
            filePath = testCase.temporaryFile();

            nansen.module.nwb.config.saveConfiguration( ...
                configurationWith(dataItem("speed")), filePath)

            jsonText = string(fileread(filePath));
            testCase.verifyGreaterThan(count(jsonText, newline), 5)
        end
    end

    methods (Test) % Rejecting configurations that cannot be read

        function rejectsAConfigurationFromANewerSchema(testCase)
            % Reading it as if it were current would drop whatever the
            % newer schema added, without saying so.
            configStruct = configurationWith(dataItem("speed")).toStruct();
            configStruct.Version = uint32(99);

            testCase.verifyError( ...
                @() nansen.module.nwb.config.NWBFileConfiguration.fromStruct(configStruct), ...
                "nansen:nwb:unsupportedConfigVersion")
        end

        function rejectsAFileThatIsNotJson(testCase)
            filePath = testCase.temporaryFile();
            writelines("this is not json", filePath)

            testCase.verifyError( ...
                @() nansen.module.nwb.config.loadConfiguration(filePath), ...
                "nansen:nwb:invalidConfigFile")
        end

        function rejectsSomethingThatIsNotAConfiguration(testCase)
            testCase.verifyError( ...
                @() nansen.module.nwb.config.NWBFileConfiguration.fromAny(42), ...
                "nansen:nwb:invalidConfiguration")
        end

        function rejectsAnUnknownWriteMode(testCase)
            testCase.verifyError( ...
                @() nansen.module.nwb.config.NWBFileConfiguration(WriteMode="maybe"), ...
                "MATLAB:validators:mustBeMember")
        end
    end

    methods (Test) % Defaults

        function fillsFieldsMissingFromAStruct(testCase)
            configStruct = struct("OutputPath", "/tmp/partial.nwb");

            config = nansen.module.nwb.config.NWBFileConfiguration.fromStruct(configStruct);

            testCase.verifyEqual(config.WriteMode, "overwrite")
            testCase.verifyEmpty(config.DataItems)
        end

        function givesADataItemUsableDefaults(testCase)
            item = nansen.module.nwb.config.NWBDataItemConfig();

            testCase.verifyEqual(item.PrimaryGroup, "Acquisition")
            testCase.verifyEqual(sort(string(fieldnames(item.SourceInfo)))', ...
                sort(["MatlabClass", "Format", "Modality", "Path"]))
        end
    end

    methods (Access = private)

        function filePath = temporaryFile(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            filePath = fullfile(fixture.Folder, "configuration.json");
        end

        function restored = saveAndLoad(testCase, config)
            filePath = testCase.temporaryFile();
            nansen.module.nwb.config.saveConfiguration(config, filePath)
            restored = nansen.module.nwb.config.loadConfiguration(filePath);
        end
    end
end

function config = configurationWith(dataItems)
%configurationWith - A configuration holding the given items

    config = nansen.module.nwb.config.NWBFileConfiguration( ...
        OutputPath="/tmp/test.nwb", ...
        SessionMetadata=struct("session_description", "test", ...
            "identifier", "test-001"), ...
        DataItems=dataItems);
end

function item = dataItem(variableName)
%dataItem - A data item naming one variable

    item = nansen.module.nwb.config.NWBDataItemConfig( ...
        VariableName=variableName, ...
        NWBVariableName=variableName, ...
        ConverterName="TimetableTimeSeries");
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
