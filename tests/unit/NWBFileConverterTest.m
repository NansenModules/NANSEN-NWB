classdef NWBFileConverterTest < matlab.unittest.TestCase
%NWBFileConverterTest - Tests for NWBFileConverter
%
%   Tests nansen.module.nwb.conversion.NWBFileConverter, the runner that
%   turns a conversion configuration into an NWB file.
%
%   The tests concentrate on the three things the runner is responsible
%   for and no converter can check on its own: that the file reaches disk
%   as rarely as correctness allows, that changes held in memory are
%   written before a converter that works on the file on disk runs, and
%   that items run in an order where what they need already exists.
%
%   An external converter is simulated with a local function rather than
%   NeuroConv, so the contract is tested without needing Python.
%
%   These tests need matnwb on the MATLAB path with generated core types.
%   They are filtered when it is unavailable.
%
%   See also: nansen.module.nwb.conversion.NWBFileConverter

    properties (Access = private)
        OutputPath (1,1) string
    end

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeMatnwbIsAvailable(testCase)
            testCase.assumeNotEmpty(which("NwbFile"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty(which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
        end
    end

    methods (TestMethodSetup)

        function useTemporaryOutputFile(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.OutputPath = fullfile(fixture.Folder, "test.nwb");
        end
    end

    methods (Test) % Writing the file

        function convertsOneItemIntoAcquisition(testCase)
            config = testCase.configurationWith(dataItem("speed", "TimetableTimeSeries"));

            filePath = testCase.runConversion(config);

            nwbFile = nwbRead(filePath);
            testCase.verifyTrue(nwbFile.acquisition.isKey("speed"))
        end

        function writesFileLevelMetadataOnce(testCase)
            config = testCase.configurationWith(dataItem("speed", "TimetableTimeSeries"));
            config.SubjectMetadata = struct("subject_id", "mouse-01", ...
                "species", "Mus musculus");
            config.GeneralMetadata = struct("institution", "Test Institute");

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyEqual(string(nwbFile.general_subject.subject_id), "mouse-01")
            testCase.verifyEqual(string(nwbFile.general_institution), "Test Institute")
        end

        function exportsOnceHoweverManyItemsThereAre(testCase)
            % Every export appends a file_create_date entry and rewrites
            % the file, so exporting per item both mis-stamps the file and
            % makes conversion quadratic in the data already written.
            config = testCase.configurationWith([ ...
                dataItem("speed", "TimetableTimeSeries"), ...
                dataItem("licks", "TimetableTimeSeries"), ...
                dataItem("pupil", "TimetableTimeSeries")]);

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyNumElements(createDates(nwbFile), 1)
        end

        function acceptsAConverterThatMutatesWithoutReturning(testCase)
            % An NwbFile is a handle, so returning nothing is a valid way
            % to write a mutating converter.
            config = testCase.configurationWith( ...
                dataItem("speed", "TestMutatingConverterWithNoOutput"));

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyTrue(nwbFile.acquisition.isKey("speed"))
        end

        function leavesNoFileWhenAnItemFailsBeforeAnyWrite(testCase)
            config = testCase.configurationWith( ...
                dataItem("speed", "GenericNeurodataType"));

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:converterFailed")

            testCase.verifyFalse(isfile(testCase.OutputPath))
            testCase.verifyEmpty(dir(fullfile(fileparts(testCase.OutputPath), "*.part.nwb")), ...
                "No work file may be left beside the output path.")
        end

        function keepsThePreviousFileWhenAnItemFails(testCase)
            % Overwriting must not destroy the previous file until the new
            % one is complete: a failed run is not a reason to lose data.
            testCase.runConversion(testCase.configurationWith( ...
                dataItem("speed", "TimetableTimeSeries")));

            config = testCase.configurationWith([ ...
                dataItem("licks", "TimetableTimeSeries"), ...
                dataItem("broken", "TestFailingConverter")]);
            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:converterFailed")

            nwbFile = nwbRead(testCase.OutputPath);
            testCase.verifyTrue(nwbFile.acquisition.isKey("speed"))
            testCase.verifyFalse(nwbFile.acquisition.isKey("licks"))
        end

        function keepsThePreviousFileWhenTheConfigurationIsRejected(testCase)
            % A misspelled converter name or a missing start time is found
            % before the previous file is touched.
            testCase.runConversion(testCase.configurationWith( ...
                dataItem("speed", "TimetableTimeSeries")));

            config = testCase.configurationWith(dataItem("speed", "NoSuchConverter"));
            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:unknownConverter")

            config = testCase.configurationWith(dataItem("speed", "TimetableTimeSeries"));
            config.SessionMetadata.session_start_time = datetime(2026, 5, 10);
            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:missingTimeZone")

            testCase.verifyTrue(nwbRead(testCase.OutputPath).acquisition.isKey("speed"))
        end

        function rejectsAConverterThatReturnsItsNeurodataDirectly(testCase)
            % Returning a neurodata object instead of the file or a result
            % struct is the natural mistake; it must not pass as "mutated
            % in place" with the data dropped.
            config = testCase.configurationWith( ...
                dataItem("speed", "TestReturnsNeurodataDirectly"));

            try
                testCase.runConversion(config);
                testCase.verifyFail("The conversion should have failed.")
            catch exception
                testCase.verifyEqual(string(exception.identifier), "nansen:nwb:converterFailed")
                testCase.assertNotEmpty(exception.cause)
                testCase.verifyEqual(string(exception.cause{1}.identifier), ...
                    "nansen:nwb:invalidConverterResult")
            end
        end
    end

    methods (Test) % Resolving metadata links

        function resolvesMetadataBeforeAnInMemoryConverterRuns(testCase)
            % The resolver turns names of linked instances into objects in
            % the file. The converter sees the resolved metadata.
            config = testCase.configurationWith(dataItemWithMetadata( ...
                "speed", "TestRecordsMetadata", struct("device", "Microscope")));
            recorder = MetadataRecorder();

            testCase.runConversion(config, MetadataRecorder=recorder);

            testCase.verifyEqual(recorder.TypeNames, "TimeSeries")
            testCase.verifyClass(recorder.Files{1}, "NwbFile")
            testCase.verifyEqual(recorder.MetadataSeenByConverter.device, "resolved:Microscope")
        end

        function doesNotResolveMetadataForAnExternalConverter(testCase)
            % An external converter takes the configured metadata as is;
            % NeuroConv resolves its own.
            config = testCase.configurationWith(dataItemWithMetadata( ...
                "marker", "TestExternalWriter", struct("device", "Microscope")));
            recorder = MetadataRecorder();

            testCase.runConversion(config, MetadataRecorder=recorder);

            testCase.verifyEmpty(recorder.TypeNames)
        end

        function startsAFreshInstanceMapAfterAnExternalConverter(testCase)
            % The objects built before the external converter belong to
            % the NwbFile that is re-read afterwards, so they must not be
            % handed to later items.
            config = testCase.configurationWith([ ...
                dataItemWithMetadata("speed", "TestRecordsMetadata", struct("device", "A")), ...
                dataItem("marker", "TestExternalWriter"), ...
                dataItemWithMetadata("pupil", "TestRecordsMetadata", struct("device", "B"))]);
            recorder = MetadataRecorder();

            testCase.runConversion(config, MetadataRecorder=recorder);

            testCase.verifyEqual(recorder.MapSizes, [0, 0], ...
                "The second resolution must start from an empty map.")
        end

        function passesMetadataThroughWithoutAResolver(testCase)
            config = testCase.configurationWith(dataItemWithMetadata( ...
                "speed", "TestRecordsMetadata", struct("device", "Microscope")));
            recorder = MetadataRecorder();

            testCase.runConversion(config, MetadataRecorder=recorder, UseResolver=false);

            testCase.verifyEqual(recorder.MetadataSeenByConverter.device, "Microscope")
        end
    end

    methods (Test) % Converters that write the file themselves

        function writesPendingChangesBeforeAnExternalConverterRuns(testCase)
            % The external converter reads the file from disk and writes
            % it back. An item converted before it exists only in memory
            % until the runner flushes, so a missing flush loses it.
            config = testCase.configurationWith([ ...
                dataItem("speed", "TimetableTimeSeries"), ...
                dataItem("marker", "TestExternalWriter")]);

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyTrue(nwbFile.acquisition.isKey("speed"), ...
                "The item converted before the external writer was lost.")
            testCase.verifyTrue(nwbFile.acquisition.isKey("ExternalMarker"))
        end

        function createsTheFileBeforeAnExternalConverterRunsFirst(testCase)
            % An external converter appends to the file the runner owns,
            % so the file has to exist even when nothing preceded it.
            config = testCase.configurationWith( ...
                dataItem("marker", "TestExternalWriter"));

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyTrue(nwbFile.acquisition.isKey("ExternalMarker"))
            testCase.verifyEqual(string(nwbFile.identifier), "test-session")
        end

        function keepsConvertingAfterAnExternalConverter(testCase)
            % The file on disk moved on, so the runner has to read it
            % again rather than mutate the copy it held before.
            config = testCase.configurationWith([ ...
                dataItem("marker", "TestExternalWriter"), ...
                dataItem("speed", "TimetableTimeSeries")]);

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyTrue(nwbFile.acquisition.isKey("ExternalMarker"))
            testCase.verifyTrue(nwbFile.acquisition.isKey("speed"))
        end

        function rejectsAnExternalConverterThatDidNotWrite(testCase)
            config = testCase.configurationWith( ...
                dataItem("marker", "TestSilentExternalWriter"));

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:converterFailed")
        end
    end

    methods (Test) % Ordering items by what they require

        function picksTheHigherRankedOfTwoMatches(testCase)
            % A format match beats a class match; only a tie is ambiguous.
            sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
            sourceInfo.Format = "testformat";
            sourceInfo.MatlabClass = "timetable";
            item = nansen.module.nwb.config.NWBDataItemConfig( ...
                VariableName="speed", NWBVariableName="speed", SourceInfo=sourceInfo);

            nwbFile = nwbRead(testCase.runConversion(testCase.configurationWith(item)));

            testCase.verifyTrue(nwbFile.acquisition.isKey("ByFormat"), ...
                "The converter matching the recorded format must win.")
        end

        function runsAProducerBeforeTheItemRequiringIt(testCase)
            % The consumer is listed first, so only the ordering step can
            % make this succeed.
            config = testCase.configurationWith([ ...
                dataItem("consumer", "TestRequiresMarker"), ...
                dataItem("speed", "TestProducesMarker")]);

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyTrue(nwbFile.acquisition.isKey("consumer"))
        end

        function countsAConverterProducingAnyTypeAsItsTarget(testCase)
            % A converter producing "*" builds the type its item names, so
            % it satisfies a requirement for that type.
            producer = dataItem("speed", "TestProducesAnyType");
            producer.TargetNWBType = "TestMarker";
            config = testCase.configurationWith([ ...
                dataItem("consumer", "TestRequiresMarker"), producer]);

            nwbFile = nwbRead(testCase.runConversion(config));

            testCase.verifyTrue(nwbFile.acquisition.isKey("consumer"))
        end

        function reportsARequirementNothingProduces(testCase)
            config = testCase.configurationWith( ...
                dataItem("consumer", "TestRequiresMarker"));

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:unmetRequirement")
        end
    end

    methods (Test) % Rejecting configurations that cannot work

        function rejectsAConfigurationWithNoOutputPath(testCase)
            config = testCase.configurationWith(dataItem("speed", "TimetableTimeSeries"));
            config.OutputPath = "";

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:missingOutputPath")
        end

        function rejectsAConfigurationWithNoDataItems(testCase)
            config = testCase.configurationWith( ...
                nansen.module.nwb.config.NWBDataItemConfig.empty(0, 1));

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:missingDataItems")
        end

        function rejectsMissingSessionMetadata(testCase)
            config = testCase.configurationWith(dataItem("speed", "TimetableTimeSeries"));
            config.SessionMetadata = rmfield(config.SessionMetadata, "identifier");

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:missingSessionMetadata")
        end

        function rejectsASessionStartTimeWithoutATimeZone(testCase)
            % A time without a zone means something different to every
            % later reader of the file.
            config = testCase.configurationWith(dataItem("speed", "TimetableTimeSeries"));
            config.SessionMetadata.session_start_time = datetime(2026, 5, 10);

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:missingTimeZone")
        end

        function rejectsAnUnknownConverterName(testCase)
            config = testCase.configurationWith(dataItem("speed", "NoSuchConverter"));

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:unknownConverter")
        end

        function reportsWhichVariableHasNoResolvableConverter(testCase)
            item = nansen.module.nwb.config.NWBDataItemConfig(VariableName="mystery");

            config = testCase.configurationWith(item);

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:unresolvedConverter")
        end
    end

    methods (Test) % Reporting failures

        function stopsAtTheFirstFailingItemByDefault(testCase)
            config = testCase.configurationWith([ ...
                dataItem("speed", "TimetableTimeSeries"), ...
                dataItem("broken", "TestFailingConverter")]);

            testCase.verifyError(@() testCase.runConversion(config), ...
                "nansen:nwb:converterFailed")
        end

        function convertsTheRestWhenAskedToContinue(testCase)
            config = testCase.configurationWith([ ...
                dataItem("broken", "TestFailingConverter"), ...
                dataItem("speed", "TimetableTimeSeries")]);

            testCase.verifyError( ...
                @() testCase.runConversion(config, OnItemError="continue"), ...
                "nansen:nwb:itemsFailed")

            nwbFile = nwbRead(testCase.OutputPath);
            testCase.verifyTrue(nwbFile.acquisition.isKey("speed"), ...
                "The items that did convert should still be in the file.")
        end
    end

    methods (Access = private)

        function config = configurationWith(testCase, dataItems)
            config = nansen.module.nwb.config.NWBFileConfiguration( ...
                OutputPath=testCase.OutputPath, ...
                SessionMetadata=struct( ...
                    "session_description", "converter test", ...
                    "identifier", "test-session", ...
                    "session_start_time", datetime(2026, 5, 10, TimeZone="UTC")), ...
                DataItems=dataItems);
        end

        function filePath = runConversion(testCase, config, options)
            arguments
                testCase
                config
                options.OnItemError (1,1) string = "stop"
                options.MetadataRecorder = []
                options.UseResolver (1,1) logical = true
            end

            % The recorder stands in for the metadata resolver and is also
            % handed to the test converters, so a test can see both what
            % the runner asked to resolve and what the converter received.
            recorder = options.MetadataRecorder;
            resolver = [];
            if ~isempty(recorder) && options.UseResolver
                resolver = @recorder.resolve;
            end

            converter = nansen.module.nwb.conversion.NWBFileConverter(config, ...
                DataResolver=@(name) testVariable(name), ...
                MetadataResolver=resolver, ...
                Registry=testCase.registryWithTestConverters(recorder), ...
                OnItemError=options.OnItemError);

            filePath = converter.convert();
        end

        function registry = registryWithTestConverters(~, recorder)
            import nansen.module.nwb.conversion.NWBConverterDescriptor

            if nargin < 2
                recorder = [];
            end

            % A private registry, so registering test converters cannot
            % disturb the shared one other tests use.
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            registry.add(NWBConverterDescriptor( ...
                Name="TestByFormat", ...
                DisplayName="Test: matches the format", ...
                AcceptedFormats="testformat", ...
                ProducesNWBType="TimeSeries", ...
                Function=@(context) addTimeSeriesToAcquisition( ...
                    setfield(context, "Placement", struct("Name", "ByFormat")))))

            registry.add(NWBConverterDescriptor( ...
                Name="TestByClass", ...
                DisplayName="Test: matches the class", ...
                AcceptedClasses="timetable", ...
                ProducesNWBType="TimeSeries", ...
                Function=@(context) addTimeSeriesToAcquisition( ...
                    setfield(context, "Placement", struct("Name", "ByClass")))))

            registry.add(NWBConverterDescriptor( ...
                Name="TestReturnsNeurodataDirectly", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", ...
                Function=@(context) types.core.TimeSeries('data', (1:4)', ...
                    'data_unit', 'n/a', 'starting_time', 0, 'starting_time_rate', 1)))

            registry.add(NWBConverterDescriptor( ...
                Name="TestRecordsMetadata", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", ...
                Function=@(context) recordMetadataAndAdd(context, recorder)))

            registry.add(NWBConverterDescriptor( ...
                Name="TestExternalWriter", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", ...
                ExecutionMode="external", ...
                PlacementPolicy="converter", ...
                Function=@writeMarkerToFile))

            registry.add(NWBConverterDescriptor( ...
                Name="TestSilentExternalWriter", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", ...
                ExecutionMode="external", ...
                PlacementPolicy="converter", ...
                Function=@(context) struct()))

            registry.add(NWBConverterDescriptor( ...
                Name="TestProducesMarker", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TestMarker", ...
                Function=@addTimeSeriesToAcquisition))

            registry.add(NWBConverterDescriptor( ...
                Name="TestProducesAnyType", ...
                AcceptedClasses="*", ...
                ProducesNWBType="*", ...
                Function=@addTimeSeriesToAcquisition))

            registry.add(NWBConverterDescriptor( ...
                Name="TestRequiresMarker", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", ...
                RequiresNWBTypes="TestMarker", ...
                Function=@addTimeSeriesToAcquisition))

            registry.add(NWBConverterDescriptor( ...
                Name="TestFailingConverter", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", ...
                Function=@failDeliberately))

            registry.add(NWBConverterDescriptor( ...
                Name="TestMutatingConverterWithNoOutput", ...
                AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", ...
                Function=@mutateWithoutReturning))
        end
    end
end

function item = dataItem(variableName, converterName)
%dataItem - Build a data item naming its converter

    item = nansen.module.nwb.config.NWBDataItemConfig( ...
        VariableName=variableName, ...
        NWBVariableName=variableName, ...
        ConverterName=converterName);
end

function item = dataItemWithMetadata(variableName, converterName, metadata)
%dataItemWithMetadata - Build a data item carrying metadata

    item = dataItem(variableName, converterName);
    item.Metadata = metadata;
end

function nwbFile = recordMetadataAndAdd(context, recorder)
%recordMetadataAndAdd - Converter that reports the metadata it was given

    if ~isempty(recorder)
        recorder.MetadataSeenByConverter = context.Metadata;
    end
    nwbFile = addTimeSeriesToAcquisition(context);
end

function data = testVariable(~)
%testVariable - Stand-in data for every variable the tests convert

    data = timetable(seconds((0:9)'), (1:10)', VariableNames="value");
end

function failDeliberately(~)
%failDeliberately - Converter that always fails, for the failure tests

    error("test:converterBroke", "Deliberate failure.")
end

function mutateWithoutReturning(context)
%mutateWithoutReturning - Converter that mutates the file and returns nothing
%
%   An NwbFile is a handle, so this is a legitimate way to write a
%   converter and the runner has to accept it.

    context.NwbFile.acquisition.set(char(context.Placement.Name), ...
        types.core.TimeSeries('data', (1:4)', 'data_unit', 'n/a', ...
            'starting_time', 0, 'starting_time_rate', 1));
end

function nwbFile = addTimeSeriesToAcquisition(context)
%addTimeSeriesToAcquisition - Minimal mutating converter for the tests

    timeSeries = types.core.TimeSeries( ...
        'data', (1:10)', 'data_unit', 'n/a', 'starting_time', 0, ...
        'starting_time_rate', 1);

    nwbFile = context.NwbFile;
    nwbFile.acquisition.set(char(context.Placement.Name), timeSeries);
end

function result = writeMarkerToFile(context)
%writeMarkerToFile - External converter standing in for NeuroConv
%
%   Reads the file from disk, adds to it and writes it back, which is how
%   an out-of-process writer such as NeuroConv behaves.

    nwbFile = nwbRead(context.FilePath);
    nwbFile.acquisition.set('ExternalMarker', types.core.TimeSeries( ...
        'data', (1:3)', 'data_unit', 'n/a', 'starting_time', 0, ...
        'starting_time_rate', 1));
    nwbExport(nwbFile, context.FilePath)

    result = struct("DidWriteFile", true);
end

function dates = createDates(nwbFile)
%createDates - Read file_create_date whether or not it is a stub

    dates = nwbFile.file_create_date;
    if isa(dates, "types.untyped.DataStub")
        dates = dates.load();
    end
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
