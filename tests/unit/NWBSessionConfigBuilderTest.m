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

    properties (TestParameter)
        % Ways a session table spells an age, and the ISO 8601 duration
        % NWB wants for each.
        ageText = struct( ...
            'months', struct('Text', "6 month", 'Expected', "P6M"), ...
            'days', struct('Text', "90 days", 'Expected', "P90D"), ...
            'weeks', struct('Text', "12 weeks", 'Expected', "P12W"), ...
            'years', struct('Text', "2 years", 'Expected', "P2Y"), ...
            'isoAlready', struct('Text', "P90D", 'Expected', "P90D"), ...
            'isoCombined', struct('Text', "P1Y6M", 'Expected', "P1Y6M"), ...
            'isoRange', struct('Text', "P6W/P8W", 'Expected', "P6W/P8W"), ...
            'range', struct('Text', "6-8 weeks", 'Expected', "P6W/P8W"), ...
            'rangeWithSpaces', struct('Text', "6 - 8 weeks", 'Expected', "P6W/P8W"))

        % Text that is not an age, keyed by what is wrong with it.
        unreadableAge = struct( ...
            'word', "adult", ...
            'unknownUnit', "6 fortnights", ...
            'wordStartingWithP', "Paris", ...
            'designatorOnly', "P", ...
            'unknownDesignator', "P6X", ...
            'threePartRange', "P1D/P2D/P3D")
    end

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

        function writesNumericIdentifiersAsDigitsInTheFileName(testCase)
            % NANSEN does not type subjectID or sessionID.
            session = sessionStub();
            session.subjectID = 5;
            session.sessionID = 12;

            config = buildFor(session);

            [~, fileName, extension] = fileparts(config.OutputPath);
            testCase.verifyEqual(fileName + extension, "sub-5_ses-12.nwb")
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

        function describesAVariableFromAGivenVariableModel(testCase)
            % The configurator suggests converters before any session is
            % chosen, from the project's variable model alone.
            model = variableModelStub(struct( ...
                "DataType", "RoiSignalArray", "FileAdapter", "RoiSignalArray"));

            sourceInfo = describeVariable("RoiSignals_MeanF", model);

            testCase.verifyEqual(sourceInfo.MatlabClass, "RoiSignalArray")
            testCase.verifyEqual(sourceInfo.Format, "RoiSignalArray")
            testCase.verifyEmpty(sourceInfo.Path)
        end

        function leavesTheFormatEmptyForTheDefaultAdapterInAModel(testCase)
            model = variableModelStub(struct("DataType", "struct", "FileAdapter", "Default"));

            sourceInfo = describeVariable("trials", model);

            testCase.verifyEqual(sourceInfo.MatlabClass, "struct")
            testCase.verifyEqual(sourceInfo.Format, "")
        end

        function describesNothingForAVariableTheModelLacks(testCase)
            model = variableModelStub(struct("DataType", "struct"), IsExistingEntry=false);

            sourceInfo = describeVariable("notInTheModel", model);

            testCase.verifyEqual(sourceInfo, ...
                nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo())
        end

        function keepsAConfiguredSourceTheSessionDoesNotKnow(testCase)
            % A hand-written configuration can point at a file the
            % variable model has no entry for.
            item = dataItem("rawMovie");
            item.SourceInfo.Path = "/raw/rec.tif";
            item.SourceInfo.Format = "tiff";

            config = buildFor(sessionStub(FilePathFails=true), DataItems=item);

            testCase.verifyEqual(config.DataItems(1).SourceInfo.Path, "/raw/rec.tif")
            testCase.verifyEqual(config.DataItems(1).SourceInfo.Format, "tiff")
        end

        function prefersWhatTheSessionReportsOverTheConfiguredSource(testCase)
            item = dataItem("roiSignals");
            item.SourceInfo.Path = "/elsewhere/old.mat";

            config = buildFor(sessionStub(), DataItems=item);

            testCase.verifyEqual(config.DataItems(1).SourceInfo.Path, ...
                "/data/session/roiSignals.mat")
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

    methods (Test) % Converter arguments taken from the session

        function fillsAConverterArgumentFromASessionColumn(testCase)
        % A column of the session table, such as the cell a patch-clamp
        % session recorded, is a per-session value no fixed configuration
        % can hold.

            item = dataItem("abf");
            item.ConverterArgs = struct("ElectrodeMetadata", ...
                struct("cell_id", "${session.cell_id}", "name", "electrode-0"));
            session = sessionStub(Columns=struct("cell_id", '170518_1'));

            config = buildFor(session, DataItems=item);

            electrode = config.DataItems(1).ConverterArgs.ElectrodeMetadata;
            testCase.verifyEqual(electrode.cell_id, "170518_1")
            testCase.verifyEqual(electrode.name, "electrode-0")
        end

        function fillsPlaceholdersInsideAText(testCase)
            item = dataItem("abf");
            item.ConverterArgs = struct("StimulusDescription", ...
                "steps into cell ${session.cell_id} of ${session.subjectID}");
            session = sessionStub(Columns=struct("cell_id", '170518_1'));

            config = buildFor(session, DataItems=item);

            testCase.verifyEqual( ...
                config.DataItems(1).ConverterArgs.StimulusDescription, ...
                "steps into cell 170518_1 of mouse01")
        end

        function leavesArgumentsWithoutPlaceholdersAlone(testCase)
            item = dataItem("abf");
            item.ConverterArgs = struct("ChannelIndex", [1 2], "Note", 'plain text');

            config = buildFor(sessionStub(), DataItems=item);

            testCase.verifyEqual(config.DataItems(1).ConverterArgs, ...
                struct("ChannelIndex", [1 2], "Note", 'plain text'))
        end

        function fillsPlaceholdersInEachElementOfAStructArray(testCase)
            % jsondecode reads a list of objects with the same fields as a
            % struct array.
            item = dataItem("abf");
            item.ConverterArgs = struct("Electrodes", struct( ...
                "name", {"e1", "e2"}, "cell", {"${session.cell_id}", "fixed"}));
            session = sessionStub(Columns=struct("cell_id", '170518_1'));

            config = buildFor(session, DataItems=item);

            electrodes = config.DataItems(1).ConverterArgs.Electrodes;
            testCase.verifySize(electrodes, [1, 2])
            testCase.verifyEqual([electrodes.cell], ["170518_1", "fixed"])
            testCase.verifyEqual([electrodes.name], ["e1", "e2"])
        end

        function fillsPlaceholdersInAListOfPaths(testCase)
            % jsondecode reads a JSON list of strings as a cell array.
            item = dataItem("abf");
            item.ConverterArgs = struct("InterfaceArgs", struct( ...
                "file_paths", {{"${session.abf_path}"}}), ...
                "Tags", ["cell ${session.cell_id}", "fixed"]);
            session = sessionStub(Columns=struct( ...
                "abf_path", '/data/170518_1a.ABF', "cell_id", '170518_1'));

            config = buildFor(session, DataItems=item);

            converterArgs = config.DataItems(1).ConverterArgs;
            testCase.verifyEqual(converterArgs.InterfaceArgs.file_paths, {"/data/170518_1a.ABF"})
            testCase.verifyEqual(converterArgs.Tags, ["cell 170518_1", "fixed"])
        end

        function fillsPlaceholdersInTheConverterDefaults(testCase)
            % A lab converter can declare a per-session default; the
            % runner merges defaults after the session is gone.
            import nansen.module.nwb.conversion.ConverterRegistry
            ConverterRegistry.instance(Refresh=true);
            testCase.addTeardown(@() ConverterRegistry.instance(Refresh=true));
            ConverterRegistry.instance().add(nansen.module.nwb.conversion.NWBConverterDescriptor( ...
                Name="SessionArgsConverter", AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", Function=@(context) context.NwbFile, ...
                DefaultConverterArgs=struct("ElectrodeMetadata", ...
                    struct("cell_id", "${session.cell_id}"), "Gain", 1)));

            item = dataItem("abf");
            item.ConverterName = "SessionArgsConverter";
            item.ConverterArgs = struct("Gain", 5);
            session = sessionStub(Columns=struct("cell_id", '170518_1'));

            config = buildFor(session, DataItems=item);

            converterArgs = config.DataItems(1).ConverterArgs;
            testCase.verifyEqual(converterArgs.ElectrodeMetadata.cell_id, "170518_1")
            testCase.verifyEqual(converterArgs.Gain, 5)
        end

        function letsAnItemReplaceADefaultHoldingAPlaceholder(testCase)
            % The item's ElectrodeMetadata replaces the default whole, so
            % the placeholder in the default does not need a column.
            import nansen.module.nwb.conversion.ConverterRegistry
            ConverterRegistry.instance(Refresh=true);
            testCase.addTeardown(@() ConverterRegistry.instance(Refresh=true));
            ConverterRegistry.instance().add(nansen.module.nwb.conversion.NWBConverterDescriptor( ...
                Name="SessionArgsConverter", AcceptedClasses="*", ...
                ProducesNWBType="TimeSeries", Function=@(context) context.NwbFile, ...
                DefaultConverterArgs=struct("ElectrodeMetadata", ...
                    struct("cell_id", "${session.cell_id}"))));

            item = dataItem("abf");
            item.ConverterName = "SessionArgsConverter";
            item.ConverterArgs = struct("ElectrodeMetadata", struct("name", "pipette"));

            config = buildFor(sessionStub(), DataItems=item);

            testCase.verifyEqual(config.DataItems(1).ConverterArgs.ElectrodeMetadata, ...
                struct("name", "pipette"))
        end

        function fillsAPlaceholderFromASessionObject(testCase)
            item = dataItem("abf");
            item.ConverterArgs = struct("cell_id", "${session.cell_id}");

            config = buildFor(SessionObjectStub(), DataItems=item);

            testCase.verifyEqual(config.DataItems(1).ConverterArgs.cell_id, "170518_1")
        end

        function rejectsAPlaceholderWhosePropertyIsMissing(testCase)
            item = dataItem("abf");
            item.ConverterArgs = struct("cell_id", "${session.cell_without_value}");

            testCase.verifyError(@() buildFor(SessionObjectStub(), DataItems=item), ...
                "nansen:nwb:unknownSessionPlaceholder")
        end

        function rejectsAPlaceholderWhosePropertyHoldsSeveralValues(testCase)
            % A vector has no single text to put in the placeholder's place.
            item = dataItem("abf");
            item.ConverterArgs = struct("Sweeps", "${session.sweep_numbers}");

            testCase.verifyError(@() buildFor(SessionObjectStub(), DataItems=item), ...
                "nansen:nwb:invalidSessionPlaceholder")
        end

        function rejectsAPlaceholderTheSessionCannotFill(testCase)
        % An argument left empty would reach the file unnoticed, so a
        % missing session property stops the build.

            item = dataItem("abf");
            item.ConverterArgs = struct("cell_id", "${session.no_such_column}");

            testCase.verifyError(@() buildFor(sessionStub(), DataItems=item), ...
                "nansen:nwb:unknownSessionPlaceholder")
        end

        function rejectsAPlaceholderWithAnEmptyValue(testCase)
            item = dataItem("abf");
            item.ConverterArgs = struct("cell_id", "${session.cell_id}");
            session = sessionStub(Columns=struct("cell_id", ''));

            testCase.verifyError(@() buildFor(session, DataItems=item), ...
                "nansen:nwb:unknownSessionPlaceholder")
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

        function rejectsATimeThatCouldNotBeParsed(testCase)
            % DataLocationModel.getTime returns NaT when the time could not
            % be parsed; isempty does not catch it.
            session = sessionStub();
            session.Time = NaT;

            testCase.verifyError(@() buildFor(session), ...
                "nansen:nwb:unparsedSessionTime")
        end

        function rejectsATimeThatIsNotATimeOfDay(testCase)
            session = sessionStub();
            session.Time = 'morning';

            testCase.verifyError(@() buildFor(session), ...
                "nansen:nwb:unparsedSessionTime")
        end

        function takesTheTimeOfDayFromADatetime(testCase)
            session = sessionStub();
            session.Time = datetime(2000, 1, 1, 9, 15, 0);

            config = buildFor(session);

            testCase.verifyEqual(timeofday(config.SessionMetadata.session_start_time), ...
                hours(9) + minutes(15))
        end

        function usesAnExplicitSessionStartTime(testCase)
            % A session folder names a date but often no time; the
            % recording's header does, and the caller passes it in.
            session = sessionStub();
            session.Time = '';
            startTime = datetime(2017, 5, 18, 10, 42, 7, TimeZone="+02:00");

            config = buildFor(session, SessionStartTime=startTime);

            testCase.verifyEqual(config.SessionMetadata.session_start_time, startTime)
        end

        function anExplicitSessionStartTimeWinsOverTheSessionsOwn(testCase)
            session = sessionStub();
            startTime = datetime(2026, 5, 10, 9, 0, 0, TimeZone="UTC");

            config = buildFor(session, SessionStartTime=startTime);

            testCase.verifyEqual(config.SessionMetadata.session_start_time, startTime)
        end

        function rejectsAnExplicitSessionStartTimeWithoutAZone(testCase)
            testCase.verifyError( ...
                @() buildFor(sessionStub(), SessionStartTime=datetime(2026, 5, 10, 9, 0, 0)), ...
                "nansen:nwb:missingTimeZone")
        end

        function writesTheSessionsAgeAsAnIsoDuration(testCase, ageText)
            config = buildFor(sessionStub(), SubjectAge=ageText.Text);

            testCase.verifyEqual(string(config.SubjectMetadata.age), ageText.Expected)
        end

        function theSessionsAgeWinsOverTheRecords(testCase)
            % The session carries the subject's state at that session,
            % which is more specific than the record.
            config = buildFor(sessionStub(), SubjectAge="6 month", ...
                SubjectRecord=struct("AgeDays", 30));

            testCase.verifyEqual(string(config.SubjectMetadata.age), "P6M")
        end

        function rejectsAnAgeItCannotRead(testCase, unreadableAge)
            % Text starting with P is not taken as a duration unchecked,
            % or it would fail only in NWB Inspector.
            testCase.verifyError(@() buildFor(sessionStub(), SubjectAge=unreadableAge), ...
                "nansen:nwb:invalidSubjectAge")
        end

        function rejectsASessionStartTimeThatIsNaT(testCase)
            testCase.verifyError( ...
                @() buildFor(sessionStub(), SessionStartTime=NaT(TimeZone="UTC")), ...
                "nansen:nwb:invalidSessionStartTime")
        end

        function rejectsMoreThanOneSessionStartTime(testCase)
            startTimes = datetime(2026, 5, 10, 9, 0, 0, TimeZone="UTC") + hours(0:1);

            testCase.verifyError(@() buildFor(sessionStub(), SessionStartTime=startTimes), ...
                "nansen:nwb:invalidSessionStartTime")
        end

        function rejectsAMissingSubjectIdentifier(testCase)
            % A missing string is not empty and has no length to compare.
            session = sessionStub();
            session.subjectID = string(missing);

            testCase.verifyError(@() buildFor(session), ...
                "nansen:nwb:missingSessionIdentifier")
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
        options.SessionStartTime datetime = datetime.empty
        options.SubjectAge (1,1) string = ""
    end

    config = nansen.module.nwb.session.NWBSessionConfigBuilder.buildConfig( ...
        session, options.DataItems, ...
        TimeZone=options.TimeZone, ProjectName="TestProject", ...
        SubjectRecord=options.SubjectRecord, ...
        MetadataDefaults=options.MetadataDefaults, ...
        OutputPath=options.OutputPath, ...
        OutputPathFcn=options.OutputPathFcn, ...
        SessionStartTime=options.SessionStartTime, ...
        SubjectAge=options.SubjectAge);
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

function sourceInfo = describeVariable(variableName, variableModel)
%describeVariable - Shorthand for sourceInfoForVariable

    sourceInfo = nansen.module.nwb.session.NWBSessionConfigBuilder ...
        .sourceInfoForVariable(variableName, variableModel);
end

function model = variableModelStub(variableInfo, options)
%variableModelStub - Stand-in for a NANSEN variable model holding one entry

    arguments
        variableInfo (1,1) struct
        options.IsExistingEntry (1,1) logical = true
    end

    model = struct();
    model.getVariableStructure = @(~) deal(variableInfo, options.IsExistingEntry);
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
        options.Columns (1,1) struct = struct()
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

    % Further columns of the session table, which NANSEN exposes as
    % properties of the session object.
    for columnName = string(fieldnames(options.Columns))'
        session.(columnName) = options.Columns.(columnName);
    end
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
