classdef NWBSessionConfigBuilderTest < matlab.unittest.TestCase
%NWBSessionConfigBuilderTest - Tests for NWBSessionConfigBuilder
%
%   Tests nansen.module.nwb.session.NWBSessionConfigBuilder, which turns a
%   NANSEN session into a conversion configuration.
%
%   The session is stood in for by a struct carrying the same properties
%   and methods the builder reads. That keeps the tests independent of a
%   NANSEN project being configured on the machine running them, and
%   makes it explicit which parts of the session API the builder depends
%   on: change one of them and these tests say so.
%
%   See also: nansen.module.nwb.session.NWBSessionConfigBuilder

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test) % Metadata taken from the session

        function buildsAnIdentifierFromProjectSubjectAndSession(testCase)
            config = buildFor(sessionStub());

            testCase.verifyEqual(config.SessionMetadata.identifier, ...
                "TestProject_mouse01_20260510")
        end

        function namesTheFileByTheBidsConvention(testCase)
            config = buildFor(sessionStub());

            [~, fileName, extension] = fileparts(config.OutputPath);
            testCase.verifyEqual(fileName + extension, "sub-mouse01_ses-20260510.nwb")
        end

        function combinesTheSessionDateAndTimeWithATimeZone(testCase)
            config = buildFor(sessionStub(), TimeZone="UTC");

            startTime = config.SessionMetadata.session_start_time;
            testCase.verifyEqual(startTime, ...
                datetime(2026, 5, 10, 14, 30, 0, TimeZone="UTC"))
        end

        function takesTheSubjectIdentifierFromTheSession(testCase)
            config = buildFor(sessionStub());

            testCase.verifyEqual(config.SubjectMetadata.subject_id, "mouse01")
        end

        function carriesTheExperimentAndProtocolIntoGeneralMetadata(testCase)
            config = buildFor(sessionStub());

            testCase.verifyEqual(config.GeneralMetadata.experiment_description, ...
                "Visual cortex imaging")
            testCase.verifyEqual(config.GeneralMetadata.protocol, "Protocol A")
        end

        function substitutesADescriptionWhenTheSessionHasNone(testCase)
            % NWB requires a session description, and an empty one fails
            % validation later with less to go on.
            session = sessionStub();
            session.Description = '';

            config = buildFor(session);

            testCase.verifyNotEmpty(char(config.SessionMetadata.session_description))
        end
    end

    methods (Test) % Describing where a variable comes from

        function recordsTheFilePathOfAVariable(testCase)
            config = buildFor(sessionStub(), DataItems=dataItem("roiSignals"));

            testCase.verifyEqual(config.DataItems(1).SourceInfo.Path, ...
                "/data/session/roiSignals.mat")
        end

        function recordsTheClassTheFileAdapterProduces(testCase)
            config = buildFor(sessionStub(), DataItems=dataItem("roiSignals"));

            testCase.verifyEqual(config.DataItems(1).SourceInfo.MatlabClass, "timetable")
        end

        function readsTheSourceFormatFromANamedFileAdapter(testCase)
            % A named adapter identifies the format: a Suite2p adapter
            % means Suite2p output whatever the file happens to be called.
            config = buildFor(sessionStub(), DataItems=dataItem("roiSignals"));

            testCase.verifyEqual(config.DataItems(1).SourceInfo.Format, "Suite2p")
        end

        function leavesTheFormatEmptyForTheDefaultFileAdapter(testCase)
            % The default adapter says nothing about the source format,
            % and claiming it did would rank converters on no evidence.
            session = sessionStub(FileAdapter="Default");

            config = buildFor(session, DataItems=dataItem("roiSignals"));

            testCase.verifyEqual(config.DataItems(1).SourceInfo.Format, "")
        end

        function survivesAVariableWithNoFile(testCase)
            % Building a configuration must work before the data exists.
            session = sessionStub(FilePathFails=true);

            config = buildFor(session, DataItems=dataItem("notRecordedYet"));

            testCase.verifyEmpty(config.DataItems(1).SourceInfo.Path)
        end

        function doesNotLoadDataWhileBuildingAConfiguration(testCase)
            % A session's recordings are far larger than memory, so a
            % configurator that loaded them to pick a converter would be
            % unusable.
            session = sessionStub();
            session.loadData = @(varargin) error("test:dataWasLoaded", ...
                "Building a configuration must not load data.");

            testCase.verifyWarningFree(@() buildFor(session, DataItems=dataItem("roiSignals")))
        end
    end

    methods (Test) % Filling subject metadata from a subject record

        function mapsTheSubjectRecordIntoSubjectMetadata(testCase)
            config = buildFor(sessionStub(), SubjectRecord=subjectRecordStub());

            testCase.verifyEqual(config.SubjectMetadata.age, "P90D")
            testCase.verifyEqual(config.SubjectMetadata.sex, "M")
            testCase.verifyEqual(config.SubjectMetadata.genotype, "Scn1a+/-")

            % A full zoned timestamp, because pynwb rejects a birth date
            % without a time zone. The offset depends on the machine, so
            % only its presence is checked.
            testCase.verifyTrue(startsWith(config.SubjectMetadata.date_of_birth, ...
                "2026-02-09T00:00:00"))
            testCase.verifyMatches(config.SubjectMetadata.date_of_birth, ...
                ".*[+-]\d{4}$")
        end

        function keepsTheSessionSubjectIdOverTheRecords(testCase)
            record = subjectRecordStub();
            record.SubjectID = 'somethingElse';

            config = buildFor(sessionStub(), SubjectRecord=record);

            testCase.verifyEqual(config.SubjectMetadata.subject_id, "mouse01")
        end

        function mapsFullSexWordsToTheNwbLetters(testCase)
            record = subjectRecordStub();
            record.BiologicalSex = 'Female';

            config = buildFor(sessionStub(), SubjectRecord=record);

            testCase.verifyEqual(config.SubjectMetadata.sex, "F")
        end

        function mapsAnUnrecognizedSexToUnknownRatherThanGuessing(testCase)
            record = subjectRecordStub();
            record.BiologicalSex = 'not recorded';

            config = buildFor(sessionStub(), SubjectRecord=record);

            testCase.verifyEqual(config.SubjectMetadata.sex, "U")
        end

        function leavesAgeOutWhenTheRecordHasNone(testCase)
            % NWB Inspector reports the gap; inventing an age would hide
            % it in a shared file.
            record = subjectRecordStub();
            record.AgeDays = NaN;

            config = buildFor(sessionStub(), SubjectRecord=record);

            testCase.verifyFalse(isfield(config.SubjectMetadata, "age"))
        end

        function toleratesARecordWithNoneOfTheExpectedFields(testCase)
            config = buildFor(sessionStub(), SubjectRecord=struct("Irrelevant", 1));

            testCase.verifyEqual(config.SubjectMetadata.subject_id, "mouse01")
        end
    end

    methods (Test) % Project-wide metadata defaults

        function fillsMetadataGapsFromTheDefaults(testCase)
            defaults = struct("GeneralMetadata", struct("institution", "UiO"), ...
                "SubjectMetadata", struct("species", "Mus musculus"));

            config = buildFor(sessionStub(), MetadataDefaults=defaults);

            testCase.verifyEqual(config.GeneralMetadata.institution, "UiO")
            testCase.verifyEqual(config.SubjectMetadata.species, "Mus musculus")
        end

        function sessionValuesWinOverTheDefaults(testCase)
            defaults = struct("SessionMetadata", ...
                struct("session_description", "From the defaults"));

            config = buildFor(sessionStub(), MetadataDefaults=defaults);

            testCase.verifyEqual(string(config.SessionMetadata.session_description), ...
                "A test session")
        end

        function defaultsSupplyTheDescriptionWhenTheSessionHasNone(testCase)
            % The "no description" placeholder must not shadow a default.
            session = sessionStub();
            session.Description = '';
            defaults = struct("SessionMetadata", ...
                struct("session_description", "From the defaults"));

            config = buildFor(session, MetadataDefaults=defaults);

            testCase.verifyEqual(string(config.SessionMetadata.session_description), ...
                "From the defaults")
        end
    end

    methods (Test) % Deciding where the file goes

        function anExplicitOutputPathWins(testCase)
            config = buildFor(sessionStub(), OutputPath="/elsewhere/custom.nwb");

            testCase.verifyEqual(config.OutputPath, "/elsewhere/custom.nwb")
        end

        function anOutputPathFunctionDerivesThePathFromTheSession(testCase)
            % The hook for a project with its own layout, such as one
            % grouping output by figure.
            pathBuilder = @(session) fullfile("/data/figure-2", ...
                "sub-" + session.subjectID + ".nwb");

            config = buildFor(sessionStub(), OutputPathFcn=pathBuilder);

            testCase.verifyEqual(config.OutputPath, ...
                string(fullfile("/data/figure-2", "sub-mouse01.nwb")))
        end

        function rejectsBothAPathAndAPathFunction(testCase)
            testCase.verifyError( ...
                @() buildFor(sessionStub(), OutputPath="/a.nwb", ...
                    OutputPathFcn=@(s) "/b.nwb"), ...
                "nansen:nwb:ambiguousOutputPath")
        end

        function rejectsAPathFunctionReturningNothingUsable(testCase)
            testCase.verifyError( ...
                @() buildFor(sessionStub(), OutputPathFcn=@(s) ""), ...
                "nansen:nwb:invalidOutputPath")
        end
    end

    methods (Test) % Rejecting sessions that cannot identify a file

        function rejectsASessionWithNoSubjectIdentifier(testCase)
            session = sessionStub();
            session.subjectID = '';

            testCase.verifyError(@() buildFor(session), ...
                "nansen:nwb:missingSessionIdentifier")
        end

        function rejectsASessionWithNoSessionIdentifier(testCase)
            session = sessionStub();
            session.sessionID = '';

            testCase.verifyError(@() buildFor(session), ...
                "nansen:nwb:missingSessionIdentifier")
        end

        function rejectsASessionWithNoDate(testCase)
            session = sessionStub();
            session.Date = [];

            testCase.verifyError(@() buildFor(session), ...
                "nansen:nwb:missingSessionStartTime")
        end

        function rejectsADateThatWasNeverParsed(testCase)
            % A date left as the raw folder substring would fail further
            % down with an error that does not point at the cause.
            session = sessionStub();
            session.Date = '2026-05-10';

            testCase.verifyError(@() buildFor(session), ...
                "nansen:nwb:unparsedSessionDate")
        end
    end
end

function config = buildFor(session, options)
%buildFor - Build a configuration for a stand-in session

    arguments
        session
        options.DataItems = nansen.module.nwb.config.NWBDataItemConfig.empty(0, 1)
        options.TimeZone (1,1) string = "UTC"
        options.SubjectRecord = []
        options.MetadataDefaults = struct()
        options.OutputPath (1,1) string = ""
        options.OutputPathFcn = function_handle.empty
    end

    config = nansen.module.nwb.session.NWBSessionConfigBuilder.buildConfig( ...
        session, options.DataItems, ...
        TimeZone=options.TimeZone, ProjectName="TestProject", ...
        SubjectRecord=options.SubjectRecord, ...
        MetadataDefaults=options.MetadataDefaults, ...
        OutputPath=options.OutputPath, ...
        OutputPathFcn=options.OutputPathFcn);
end

function record = subjectRecordStub()
%subjectRecordStub - Stand-in for a row of the Subject metatable
%
%   Carries the fields subjectMetadataFromRecord looks for, with the
%   names the Roth project's subject table uses.

    record = struct();
    record.SubjectID = 'mouse01';
    record.AgeDays = 90;
    record.BiologicalSex = 'male';
    record.DateOfBirth = datetime(2026, 2, 9);
    record.Genotype = 'Scn1a+/-';
end

function item = dataItem(variableName)
%dataItem - A data item naming one variable

    item = nansen.module.nwb.config.NWBDataItemConfig(VariableName=variableName);
end

function session = sessionStub(options)
%sessionStub - Stand-in for a NANSEN session
%
%   Carries the properties and methods NWBSessionConfigBuilder reads, and
%   nothing else, so the test states the session API the builder depends
%   on.

    arguments
        options.FileAdapter (1,1) string = "Suite2p"
        options.FilePathFails (1,1) logical = false
    end

    session = struct();
    session.subjectID = 'mouse01';
    session.sessionID = '20260510';
    session.Date = datetime(2026, 5, 10);
    session.Time = '14:30:00';
    session.Description = 'A test session';
    session.Experiment = 'Visual cortex imaging';
    session.Protocol = 'Protocol A';

    session.getSessionFolder = @(varargin) '/data/session';
    session.loadData = @(varargin) timetable();

    if options.FilePathFails
        session.getDataFilePath = @(varargin) error("test:noSuchVariable", ...
            "This session has no file for that variable.");
    else
        session.getDataFilePath = @(variableName) deal( ...
            fullfile('/data/session', [variableName '.mat']), ...
            struct("DataType", "timetable", "FileAdapter", char(options.FileAdapter)));
    end
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
