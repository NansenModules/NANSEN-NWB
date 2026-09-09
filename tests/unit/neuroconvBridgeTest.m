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

        function convertsALogicalToAPythonBool(testCase)
            testCase.assumePythonIsAvailable()

            pythonValue = nansen.module.nwb.neuroconv.toPythonValue(true);

            testCase.verifyClass(pythonValue, "py.bool")
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
