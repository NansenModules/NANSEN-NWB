classdef neuroconvBridgeTest < matlab.unittest.TestCase
%neuroconvBridgeTest - Tests for the NeuroConv bridge
%
%   Tests the pieces that hand a conversion to NeuroConv: the MATLAB to
%   Python value conversion, the source argument resolution, and the
%   capability check.
%
%   The value conversion carries most of the risk. NeuroConv validates
%   metadata against a JSON schema, so a struct that crosses the boundary
%   as the wrong Python type fails inside Python with an error about the
%   schema rather than about the MATLAB value that caused it.
%
%   Tests needing Python are filtered when it is unavailable, so the
%   suite runs on a machine without it.
%
%   See also: nansen.module.nwb.neuroconv.runConversion

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test) % Resolving the source argument, no Python needed

        function namesTheArgumentTheInterfaceExpects(testCase)
            sourceArg = resolveFor("/data/rec.tif", ...
                struct("SourceArgumentName", "file_path", "SourcePathMode", "file"));

            testCase.verifyEqual(string(sourceArg.file_path), "/data/rec.tif")
        end

        function takesTheContainingFolderWhenTheInterfaceWantsOne(testCase)
            % A Suite2p interface is pointed at the folder holding the
            % file the session recorded, not at the file itself.
            sourceArg = resolveFor("/data/suite2p/plane0/F.npy", ...
                struct("SourceArgumentName", "folder_path", ...
                    "SourcePathMode", "parentFolder"));

            testCase.verifyEqual(string(sourceArg.folder_path), "/data/suite2p/plane0")
        end

        function passesEveryPathWhenTheInterfaceTakesAList(testCase)
            sourceArg = resolveFor(["/data/a.tif", "/data/b.tif"], ...
                struct("SourceArgumentName", "file_paths", ...
                    "SourcePathMode", "fileList"));

            testCase.verifyEqual(string(sourceArg.file_paths), ["/data/a.tif", "/data/b.tif"])
        end

        function passesEveryFileBesideTheRecordedOneWhenAsked(testCase)
            % NANSEN records one path per variable, but an ABF session is
            % a folder of files NeuroConv takes together. The extension
            % match ignores case, and unrelated files stay out.
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            for name = ["b_0002.abf", "a_0001.ABF", "notes.txt"]
                fclose(fopen(fullfile(fixture.Folder, name), "w"));
            end

            sourceArg = resolveFor(fullfile(fixture.Folder, "b_0002.abf"), ...
                struct("SourceArgumentName", "file_paths", ...
                    "SourcePathMode", "siblingFiles"));

            [~, names, extensions] = fileparts(string(sourceArg.file_paths));
            testCase.verifyEqual(names + extensions, ["a_0001.ABF", "b_0002.abf"])
        end

        function reportsAFolderWithNoSiblingFiles(testCase)
            testCase.verifyError( ...
                @() resolveFor(fullfile(tempdir, "no-such-folder", "rec.abf"), ...
                    struct("SourceArgumentName", "file_paths", ...
                        "SourcePathMode", "siblingFiles")), ...
                "nansen:nwb:missingSourcePath")
        end

        function acceptsAnExplicitSourceArgument(testCase)
            % An interface whose constructor does not fit the pattern can
            % be given its arguments verbatim.
            explicit = struct("SourceArg", ...
                struct("file_path", "/data/rec.tif", "sampling_frequency", 30));

            sourceArg = resolveFor("/ignored.tif", explicit);

            testCase.verifyEqual(sourceArg.sampling_frequency, 30)
        end

        function reportsAVariableWithNoRecordedPath(testCase)
            item = nansen.module.nwb.config.NWBDataItemConfig(VariableName="rec");

            testCase.verifyError( ...
                @() nansen.module.nwb.neuroconv.resolveSourceArg(item, ...
                    struct("SourceArgumentName", "file_path")), ...
                "nansen:nwb:missingSourcePath")
        end

        function reportsAnInterfaceWithNoNamedSourceArgument(testCase)
            testCase.verifyError(@() resolveFor("/data/rec.tif", struct()), ...
                "nansen:nwb:missingConverterArg")
        end

        function takesTheSuite2pFolderForAFileInAPlaneFolder(testCase)
            % Suite2pSegmentationInterface takes the suite2p folder that
            % holds the plane folders, and picks the first plane unless
            % told otherwise.
            registry = nansen.module.nwb.conversion.ConverterRegistry();
            defaults = registry.get("NeuroConvSuite2pSegmentationInterface") ...
                .DefaultConverterArgs;

            sourceArg = resolveFor("/data/suite2p/plane0/F.npy", defaults);

            testCase.verifyEqual(string(sourceArg.folder_path), "/data/suite2p")
        end

        function addsTheOtherConstructorArguments(testCase)
            converterArgs = struct("SourceArgumentName", "file_paths", ...
                "SourcePathMode", "fileList", ...
                "InterfaceArgs", struct("sampling_frequency", 30.5));

            sourceArg = resolveFor("/data/rec.tif", converterArgs);

            testCase.verifyEqual(string(sourceArg.file_paths), "/data/rec.tif")
            testCase.verifyEqual(sourceArg.sampling_frequency, 30.5)
        end

        function reportsAConstructorArgumentTheInterfaceNeeds(testCase)
            % TiffImagingInterface cannot time the frames without a
            % sampling frequency, which no file path supplies.
            registry = nansen.module.nwb.conversion.ConverterRegistry();
            defaults = registry.get("NeuroConvTiffImagingInterface").DefaultConverterArgs;

            testCase.verifyError(@() resolveFor("/data/rec.tif", defaults), ...
                "nansen:nwb:missingConverterArg")
        end

        function givesTheAbfInterfaceOnlyTheSessionsOwnFile(testCase)
            % Sessions that share a folder must not take each other's
            % recordings.
            registry = nansen.module.nwb.conversion.ConverterRegistry();
            defaults = registry.get("NeuroConvAbfInterface").DefaultConverterArgs;

            sourceArg = resolveFor("/data/170518_1a.ABF", defaults);

            testCase.verifyEqual(string(sourceArg.file_paths), "/data/170518_1a.ABF")
        end

        function namesAnIcephysSessionForEachFile(testCase)
            sourceArg = struct("file_paths", {{'/data/170518_1a.ABF', '/data/170518_1b.ABF'}});

            metadata = addExperimentType(struct(), sourceArg, "current_clamp");

            sessions = metadata.Icephys.Sessions;
            testCase.verifyClass(sessions, "cell")
            testCase.verifyEqual(cellfun(@(s) string(s.name), sessions), ...
                ["170518_1a.ABF", "170518_1b.ABF"])
            testCase.verifyEqual(string(sessions{1}.icephys_experiment_type), "current_clamp")
        end

        function keepsASingleSessionAList(testCase)
            % NeuroConv merges a list of sessions by name; one session
            % sent as a dict would replace the list.
            sourceArg = struct("file_paths", {{'/data/170518_1a.ABF'}});

            metadata = addExperimentType(struct(), sourceArg, "izero");

            testCase.verifyClass(metadata.Icephys.Sessions, "cell")
            testCase.verifyNumElements(metadata.Icephys.Sessions, 1)
        end

        function rejectsAnUnknownIcephysExperimentType(testCase)
            % NeuroConv's metadata schema does not check the value, so a
            % typo would only fail deep inside the conversion.
            sourceArg = struct("file_paths", {{'/data/170518_1a.ABF'}});

            testCase.verifyError( ...
                @() addExperimentType(struct(), sourceArg, "currentclamp"), ...
                "nansen:nwb:invalidConverterArg")
        end

        function rejectsAnExperimentTypeWithoutFilePaths(testCase)
            % An explicit SourceArg need not name its files file_paths.
            testCase.verifyError( ...
                @() addExperimentType(struct(), struct("file_path", "/data/a.abf"), "current_clamp"), ...
                "nansen:nwb:invalidConverterArg")
        end

        function rejectsSiblingFilesForAPathWithoutExtension(testCase)
            testCase.verifyError( ...
                @() resolveFor("/data/recording", ...
                    struct("SourceArgumentName", "file_paths", ...
                        "SourcePathMode", "siblingFiles")), ...
                "nansen:nwb:invalidConverterArg")
        end

        function acceptsADescriptorWithSiblingFiles(testCase)
            descriptor = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
                Name="SiblingAbf", Source="neuroconv", AcceptedFormats="abf", ...
                ProducesNWBType="PatchClampSeries", ExecutionMode="external", ...
                PlacementPolicy="converter", RequiresPython=true, NeedsData=false, ...
                DefaultConverterArgs=struct("InterfaceClassName", "AbfInterface", ...
                    "SourceArgumentName", "file_paths", "SourcePathMode", "siblingFiles"), ...
                Function=@nansen.module.nwb.conversion.builtin.convertWithNeuroconv);

            testCase.verifyEqual(string(descriptor.DefaultConverterArgs.SourcePathMode), ...
                "siblingFiles")
        end

        function readsTheStartTimeOfAnNwbFile(testCase)
            testCase.assumeNotEmpty(which("NwbFile"), "matnwb is not on the MATLAB path.")
            filePath = string(fullfile(testCase.temporaryFolder(), "start.nwb"));
            startTime = datetime(2017, 5, 18, 9, 0, 0, TimeZone="Europe/Oslo");
            nwbExport(NwbFile('identifier', 'x', 'session_description', 'x', ...
                'session_start_time', startTime), char(filePath));

            readTime = nansen.module.nwb.neuroconv.internal.readFileSessionStartTime(filePath);

            testCase.verifyEqual(readTime, startTime)
        end

        function warnsWhenAFileHasNoStartTime(testCase)
            % Data appended to such a file keep their interface's times,
            % which can be wrong, so this is not silent.
            filePath = string(fullfile(testCase.temporaryFolder(), "notNwb.nwb"));
            writelines("not an NWB file", filePath)

            readTime = testCase.verifyWarning( ...
                @() nansen.module.nwb.neuroconv.internal.readFileSessionStartTime(filePath), ...
                "nansen:nwb:unalignedRecording");

            testCase.verifyEmpty(readTime)
        end

        function reportsAnUnknownSourcePathMode(testCase)
            testCase.verifyError( ...
                @() resolveFor("/data/rec.tif", ...
                    struct("SourceArgumentName", "file_path", ...
                        "SourcePathMode", "somewhere")), ...
                "nansen:nwb:invalidConverterArg")
        end
    end

    methods (Test, TestTags = {'RequiresPython'}) % Crossing into Python

        function convertsANestedStructToADict(testCase)
            testCase.assumePythonIsAvailable()

            metadata = struct("NWBFile", struct("session_id", "ses-01"));

            pythonValue = nansen.module.nwb.neuroconv.toPythonValue(metadata);

            testCase.verifyClass(pythonValue, "py.dict")
            testCase.verifyEqual( ...
                string(pythonValue{"NWBFile"}{"session_id"}), "ses-01")
        end

        function convertsAStringArrayToAListOfStrings(testCase)
            % An experimenter list is the common case, and NeuroConv's
            % schema requires an array of strings there.
            testCase.assumePythonIsAvailable()

            pythonValue = nansen.module.nwb.neuroconv.toPythonValue( ...
                ["Ada Lovelace", "Alan Turing"]);

            testCase.verifyClass(pythonValue, "py.list")
            testCase.verifyEqual(double(py.len(pythonValue)), 2)
        end

        function convertsAStructArrayToAListOfDicts(testCase)
            testCase.assumePythonIsAvailable()

            devices = struct("name", {"Microscope", "Camera"});

            pythonValue = nansen.module.nwb.neuroconv.toPythonValue(devices);

            testCase.verifyClass(pythonValue, "py.list")
            testCase.verifyEqual(double(py.len(pythonValue)), 2)
        end

        function convertsAZonedDatetime(testCase)
            testCase.assumePythonIsAvailable()

            sessionStart = datetime(2026, 5, 10, 14, 30, 0, TimeZone="UTC");

            pythonValue = nansen.module.nwb.neuroconv.toPythonValue(sessionStart);

            testCase.verifyEqual(double(pythonValue.year), 2026)
            testCase.verifyEqual(double(pythonValue.hour), 14)
            testCase.verifyNotEqual(char(class(pythonValue.tzinfo)), 'py.NoneType')
        end

        function rejectsADatetimeWithoutATimeZone(testCase)
            % NWB timestamps are absolute. A naive datetime would be read
            % as local to whoever opens the file.
            testCase.assumePythonIsAvailable()

            testCase.verifyError( ...
                @() nansen.module.nwb.neuroconv.toPythonValue(datetime(2026, 5, 10)), ...
                "nansen:nwb:missingTimeZone")
        end

        function readsAnAwarePythonDatetimeWithItsOffset(testCase)
            % A recording's header gives the start time with the offset
            % the software wrote; the wall-clock time and the offset both
            % have to survive the trip into MATLAB.
            testCase.assumePythonIsAvailable()

            zone = py.datetime.timezone(py.datetime.timedelta(pyargs("hours", int32(2))));
            pythonValue = py.datetime.datetime(int32(2017), int32(5), int32(18), ...
                int32(10), int32(42), int32(7), int32(250000), pyargs("tzinfo", zone));

            value = nansen.module.nwb.neuroconv.fromPythonDatetime(pythonValue);

            testCase.verifyEqual(string(value.TimeZone), "+02:00")
            testCase.verifyEqual([value.Hour, value.Minute], [10, 42])
            testCase.verifyEqual(value.Second, 7.25, AbsTol=1e-9)
            testCase.verifyEqual(value, datetime(2017, 5, 18, 8, 42, 7.25, TimeZone="UTC"))
        end

        function readsANaivePythonDatetimeWithoutAZone(testCase)
            testCase.assumePythonIsAvailable()

            pythonValue = py.datetime.datetime(int32(2017), int32(5), int32(18), ...
                int32(10), int32(42), int32(7));

            value = nansen.module.nwb.neuroconv.fromPythonDatetime(pythonValue);

            testCase.verifyEqual(string(value.TimeZone), "")
            testCase.verifyEqual(value, datetime(2017, 5, 18, 10, 42, 7))
        end

        function convertsALogicalToAPythonBool(testCase)
            testCase.assumePythonIsAvailable()

            pythonValue = nansen.module.nwb.neuroconv.toPythonValue(true);

            testCase.verifyClass(pythonValue, "py.bool")
        end
    end

    methods (Test, TestTags = {'RequiresPython'}) % Aligning appended data

        function shiftsDataThatStartedAfterTheFile(testCase)
            % The ABF start has no offset, so it is wall-clock time in the
            % file's zone.
            interface = testCase.stubInterface("2017-05-18T10:42:07");

            offset = align(interface, datetime(2017, 5, 18, 9, 0, 0, TimeZone="Europe/Oslo"));

            testCase.verifyEqual(offset, 6127)
            testCase.verifyEqual(alignedOffsets(interface), 6127)
        end

        function convertsAZonedStartToTheFileZone(testCase)
            interface = testCase.stubInterface("2017-05-18T08:42:07+00:00");

            offset = align(interface, datetime(2017, 5, 18, 9, 0, 0, TimeZone="Europe/Oslo"));

            testCase.verifyEqual(offset, 6127)
        end

        function comparesWallClockTimesWhenTheFileHasNoZone(testCase)
            interface = testCase.stubInterface("2017-05-18T10:42:07+00:00");

            offset = align(interface, datetime(2017, 5, 18, 9, 0, 0));

            testCase.verifyEqual(offset, 6127)
        end

        function takesAnUndatedStartOnTheFileDate(testCase)
            % An ABF 1 header has a time of day but no date, which
            % NeuroConv reports on 1900-01-01.
            interface = testCase.stubInterface("1900-01-01T11:38:54");

            offset = align(interface, datetime(2017, 5, 18, 9, 0, 0, TimeZone="Europe/Oslo"));

            testCase.verifyEqual(offset, 9534)
        end

        function rejectsARecordingThatStartedBeforeTheFile(testCase)
            interface = testCase.stubInterface("2017-05-18T08:00:00");

            testCase.verifyError( ...
                @() align(interface, datetime(2017, 5, 18, 9, 0, 0, TimeZone="Europe/Oslo")), ...
                "nansen:nwb:recordingBeforeSessionStart")
            testCase.verifyEmpty(alignedOffsets(interface))
        end

        function warnsWhenTheStartCannotBeRead(testCase)
            interface = testCase.stubInterface("the morning of the 18th");

            testCase.verifyWarning( ...
                @() align(interface, datetime(2017, 5, 18, 9, 0, 0, TimeZone="UTC")), ...
                "nansen:nwb:unalignedRecording")
            testCase.verifyEmpty(alignedOffsets(interface))
        end

        function warnsWhenTheInterfaceCannotShift(testCase)
            interface = testCase.stubInterface("2017-05-18T10:42:07", CanAlign=false);

            offset = testCase.verifyWarning( ...
                @() align(interface, datetime(2017, 5, 18, 9, 0, 0, TimeZone="Europe/Oslo")), ...
                "nansen:nwb:unalignedRecording");

            testCase.verifyEqual(offset, 0)
        end
    end

    methods (Test, TestTags = {'RequiresPython'}) % Reaching NeuroConv itself

        function reportsWhetherNeuroconvCanBeRun(testCase)
            testCase.assumePythonIsAvailable()

            [tf, report] = nansen.module.nwb.neuroconv.hasNeuroconv("Refresh");

            testCase.verifyClass(tf, "logical")
            testCase.verifyNotEmpty(report.Message, ...
                "The report has to say what to do when NeuroConv is unavailable.")
        end

        function surfacesAPythonErrorAsACause(testCase)
            % A Python traceback is the useful part of a NeuroConv
            % failure, so it must survive rather than be flattened into a
            % message.
            testCase.assumePythonIsAvailable()
            testCase.assumeTrue(nansen.module.nwb.neuroconv.hasNeuroconv(), ...
                "NeuroConv is not installed.")

            try
                nansen.module.nwb.neuroconv.runConversion( ...
                    "NoSuchInterfaceAtAll", struct("file_path", "/tmp/x"), ...
                    fullfile(tempdir, "unused.nwb"));
                testCase.verifyFail("The conversion should have failed.")
            catch exception
                testCase.verifyEqual(string(exception.identifier), "nansen:nwb:neuroconvFailed")
                testCase.verifyNotEmpty(exception.cause)
            end
        end

        function reportsWhatNwbInspectorFindsInAFile(testCase)
            % A file can be written successfully and still be unusable to
            % a repository. A subject with no age is the common case, and
            % NWB Inspector rates it critical.
            testCase.assumePythonIsAvailable()
            testCase.assumeNwbInspectorIsAvailable()

            filePath = testCase.fileWithNoSubjectAge();

            findings = nansen.module.nwb.neuroconv.inspectFile(filePath, ...
                MinimumImportance="BEST_PRACTICE_VIOLATION");

            testCase.verifyThat(findings.Check, ...
                matlab.unittest.constraints.IsSupersetOf("check_subject_age"))
            testCase.verifyEqual(findings.Importance(1), "CRITICAL", ...
                "The worst finding has to come first.")
        end

        function warnsAboutBestPracticeFindingsAfterConverting(testCase)
            testCase.assumePythonIsAvailable()
            testCase.assumeNwbInspectorIsAvailable()

            testCase.verifyWarning(@() testCase.convertWithValidation(), ...
                "nansen:nwb:bestPracticeFindings")
        end

        function refusesToOverwriteAndAppendAtOnce(testCase)
            testCase.assumePythonIsAvailable()

            testCase.verifyError( ...
                @() nansen.module.nwb.neuroconv.runConversion("AnyInterface", ...
                    struct("file_path", "/tmp/x"), "/tmp/out.nwb", struct(), ...
                    Overwrite=true, AppendOnDiskNwbFile=true), ...
                "nansen:nwb:invalidWriteMode")
        end
    end

    methods (Access = private)

        function interface = stubInterface(testCase, startText, options)
            %stubInterface - A Python object answering what alignToStartTime asks
            %
            %   Its get_metadata reports startText as the recording's start,
            %   and set_aligned_starting_time records the offsets it is given.

            arguments
                testCase
                startText (1,1) string
                options.CanAlign (1,1) logical = true
            end

            testCase.assumePythonIsAvailable()

            folder = testCase.temporaryFolder();
            writelines([ ...
                "class StubInterface:"
                "    def __init__(self, start):"
                "        self.start = start"
                "        self.aligned = []"
                "    def get_metadata(self):"
                "        return {'NWBFile': {'session_start_time': self.start}}"
                "    def set_aligned_starting_time(self, offset):"
                "        self.aligned.append(offset)"
                ""
                "class StubInterfaceWithoutAlignment:"
                "    def __init__(self, start):"
                "        self.start = start"
                "        self.aligned = []"
                "    def get_metadata(self):"
                "        return {'NWBFile': {'session_start_time': self.start}}"], ...
                fullfile(folder, "nansen_nwb_stub_interface.py"))

            pythonPath = py.sys.path;
            pythonPath.insert(int32(0), folder);
            testCase.addTeardown(@() pythonPath.remove(folder))
            stubModule = py.importlib.import_module("nansen_nwb_stub_interface");
            stubModule = py.importlib.reload(stubModule);

            if options.CanAlign
                interface = stubModule.StubInterface(char(startText));
            else
                interface = stubModule.StubInterfaceWithoutAlignment(char(startText));
            end
        end

        function folder = temporaryFolder(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            folder = string(fixture.Folder);
        end

        function assumePythonIsAvailable(testCase)
            %assumePythonIsAvailable - Skip when MATLAB has no Python

            environment = pyenv();
            testCase.assumeNotEmpty(char(environment.Executable), ...
                "MATLAB has no Python interpreter configured.")
        end

        function assumeNwbInspectorIsAvailable(testCase)
            %assumeNwbInspectorIsAvailable - Skip without NWB Inspector

            try
                py.importlib.import_module("nwbinspector");
            catch
                testCase.assumeFail("NWB Inspector is not installed.")
            end
        end

        function filePath = fileWithNoSubjectAge(testCase)
            %fileWithNoSubjectAge - Write a file NWB Inspector will fault

            filePath = testCase.convertWithValidation(Validate=false);
        end

        function filePath = convertWithValidation(testCase, options)
            %convertWithValidation - Convert a file whose subject has no age

            arguments
                testCase
                options.Validate (1,1) logical = true
            end

            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);

            config = nansen.module.nwb.config.NWBFileConfiguration( ...
                OutputPath=fullfile(fixture.Folder, "inspected.nwb"), ...
                SessionMetadata=struct( ...
                    "session_description", "inspection test", ...
                    "identifier", "inspect-001", ...
                    "session_start_time", datetime(2026, 5, 10, TimeZone="UTC")), ...
                SubjectMetadata=struct("subject_id", "mouse01", ...
                    "species", "Mus musculus", "sex", "M"), ...
                DataItems=nansen.module.nwb.config.NWBDataItemConfig( ...
                    VariableName="speed", NWBVariableName="Speed", ...
                    ConverterName="TimetableTimeSeries"));

            converter = nansen.module.nwb.conversion.NWBFileConverter(config, ...
                DataResolver=@(name) timetable(seconds((0:9)'), (1:10)', ...
                    VariableNames="speed"), ...
                Validate=options.Validate);

            filePath = converter.convert();
        end
    end
end

function offset = align(interface, fileStartTime)
%align - Shorthand for alignToStartTime

    offset = nansen.module.nwb.neuroconv.internal.alignToStartTime(interface, fileStartTime);
end

function offsets = alignedOffsets(interface)
%alignedOffsets - The offsets a stub interface was asked to shift by

    offsets = cellfun(@double, cell(interface.aligned));
end

function metadata = addExperimentType(metadata, sourceArg, experimentType)
%addExperimentType - Shorthand for addIcephysExperimentType

    metadata = nansen.module.nwb.neuroconv.internal.addIcephysExperimentType( ...
        metadata, sourceArg, experimentType);
end

function sourceArg = resolveFor(paths, converterArgs)
%resolveFor - Resolve the source argument for a data item with these paths

    sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
    sourceInfo.Path = paths;

    item = nansen.module.nwb.config.NWBDataItemConfig( ...
        VariableName="recording", SourceInfo=sourceInfo);

    sourceArg = nansen.module.nwb.neuroconv.resolveSourceArg(item, converterArgs);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
