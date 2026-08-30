classdef builtinConverterTest < matlab.unittest.TestCase
%builtinConverterTest - Tests for the converters that ship with the module
%
%   Tests the converters under nansen.module.nwb.conversion.builtin by
%   running each through the conversion runner and reading the result
%   back from the written file. Going through the runner rather than
%   calling the converters directly means the tests cover the contract
%   the converters are actually used under.
%
%   The ophys converters are covered by ConverterRegistry and runner
%   tests rather than here, because they need ROI group and signal
%   objects that only NANSEN produces.
%
%   These tests need matnwb on the MATLAB path with generated core types.
%   They are filtered when it is unavailable.
%
%   See also: nansen.module.nwb.conversion.builtin.convertTimetableToTimeSeries

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

    methods (Test) % Timetable to TimeSeries

        function convertsEachTimetableVariableToItsOwnSeries(testCase)
            data = timetable(seconds((0:4)'), (1:5)', (6:10)', ...
                VariableNames=["speed", "pupil"]);

            nwbFile = testCase.convert(data, "TimetableTimeSeries");

            testCase.verifyEqual(sort(string(nwbFile.acquisition.keys())), ...
                ["pupil", "speed"])
        end

        function namesASingleSeriesAfterTheConfiguredName(testCase)
            data = timetable(seconds((0:4)'), (1:5)', VariableNames="speed");

            nwbFile = testCase.convert(data, "TimetableTimeSeries", ...
                NWBVariableName="RunningSpeed");

            testCase.verifyTrue(nwbFile.acquisition.isKey("RunningSpeed"))
        end

        function rejectsDataThatIsNotATimetable(testCase)
            testCase.verifyError( ...
                @() testCase.convert(magic(4), "TimetableTimeSeries"), ...
                "nansen:nwb:converterFailed")
        end
    end

    methods (Test) % Timetable to TimeIntervals

        function convertsATimetableToIntervalsWithAStopTimeVariable(testCase)
            data = timetable(seconds([0; 10; 20]), seconds([5; 15; 25]), ...
                VariableNames="stopTime");

            nwbFile = testCase.convert(data, "TimetableTimeIntervals", ...
                NWBVariableName="epochs", PrimaryGroup="Intervals", ...
                ConverterArgs=struct("StopTimeVariable", "stopTime"));

            intervals = intervalsNamed(nwbFile, "epochs");
            testCase.verifyEqual(loadData(intervals.start_time)', [0 10 20])
            testCase.verifyEqual(loadData(intervals.stop_time)', [5 15 25])
        end

        function derivesStopTimesFromDurations(testCase)
            data = timetable(seconds([0; 10]), seconds([4; 6]), ...
                VariableNames="trialDuration");

            nwbFile = testCase.convert(data, "TimetableTimeIntervals", ...
                NWBVariableName="epochs", PrimaryGroup="Intervals", ...
                ConverterArgs=struct("DurationVariable", "trialDuration"));

            intervals = intervalsNamed(nwbFile, "epochs");
            testCase.verifyEqual(loadData(intervals.stop_time)', [4 16])
        end

        function runsEachIntervalToTheNextWhenNothingElseBoundsIt(testCase)
            % The last row has no successor, so nothing says when it ends
            % and it is dropped rather than given an invented stop time.
            data = timetable(seconds([0; 10; 20]), (1:3)', VariableNames="value");

            nwbFile = testCase.convert(data, "TimetableTimeIntervals", ...
                NWBVariableName="epochs", PrimaryGroup="Intervals");

            intervals = intervalsNamed(nwbFile, "epochs");
            testCase.verifyEqual(loadData(intervals.start_time)', [0 10])
            testCase.verifyEqual(loadData(intervals.stop_time)', [10 20])
        end

        function carriesTheOtherVariablesIntoColumns(testCase)
            data = timetable(seconds([0; 10]), seconds([5; 15]), ...
                ["go"; "nogo"], [1; 0], ...
                VariableNames=["stopTime", "trialType", "correct"]);

            nwbFile = testCase.convert(data, "TimetableTimeIntervals", ...
                NWBVariableName="epochs", PrimaryGroup="Intervals", ...
                ConverterArgs=struct("StopTimeVariable", "stopTime"));

            intervals = intervalsNamed(nwbFile, "epochs");
            testCase.verifyEqual(string(loadData(intervals.vectordata.get("trialType")))', ...
                ["go", "nogo"])
            testCase.verifyEqual(loadData(intervals.vectordata.get("correct"))', [1 0])
        end

        function rejectsAStopTimeVariableThatIsNotThere(testCase)
            data = timetable(seconds([0; 10]), (1:2)', VariableNames="value");

            testCase.verifyError( ...
                @() testCase.convert(data, "TimetableTimeIntervals", ...
                    PrimaryGroup="Intervals", ...
                    ConverterArgs=struct("StopTimeVariable", "noSuchVariable")), ...
                "nansen:nwb:converterFailed")
        end
    end

    methods (Test) % Projection images

        function storesEachProjectionUnderItsOwnName(testCase)
            data = struct("average", magic(8), "maximum", magic(8) * 2);

            nwbFile = testCase.convert(data, "ProjectionImages", ...
                PrimaryGroup="Processing", NWBModule="ophys");

            testCase.verifyEqual(sort(imageNames(nwbFile)), ["average", "maximum"])
        end

        function storesASingleImageUnderTheConfiguredName(testCase)
            nwbFile = testCase.convert(magic(8), "ProjectionImages", ...
                NWBVariableName="AverageProjection", ...
                PrimaryGroup="Processing", NWBModule="ophys");

            testCase.verifyEqual(imageNames(nwbFile), "AverageProjection")
        end

        function rejectsDataThatIsNotAnImage(testCase)
            testCase.verifyError( ...
                @() testCase.convert("not an image", "ProjectionImages", ...
                    PrimaryGroup="Processing", NWBModule="ophys"), ...
                "nansen:nwb:converterFailed")
        end
    end

    methods (Test) % The generic neurodata path

        function buildsTheNeurodataTypeNamedByTheDataItem(testCase)
            nwbFile = testCase.convert((1:10)', "GenericNeurodataType", ...
                NWBVariableName="Signal", ...
                TargetNWBType="TimeSeries", ...
                Metadata=struct("data_unit", "volts", ...
                    "starting_time", 0, "starting_time_rate", 30));

            testCase.verifyTrue(nwbFile.acquisition.isKey("Signal"))
            testCase.verifyEqual(string(nwbFile.acquisition.get("Signal").data_unit), ...
                "volts")
        end

        function rejectsAnItemThatNamesNoTargetType(testCase)
            testCase.verifyError( ...
                @() testCase.convert((1:10)', "GenericNeurodataType"), ...
                "nansen:nwb:converterFailed")
        end
    end

    methods (Access = private)

        function nwbFile = convert(testCase, data, converterName, itemOptions)
            arguments
                testCase
                data
                converterName (1,1) string
                itemOptions.?nansen.module.nwb.config.NWBDataItemConfig
            end

            % Every argument goes through one cell array: MATLAB does not
            % accept a cell expansion after name=value arguments.
            itemArguments = [{"VariableName", "testVariable", ...
                "ConverterName", converterName}, namedargs2cell(itemOptions)];
            item = nansen.module.nwb.config.NWBDataItemConfig(itemArguments{:});

            config = nansen.module.nwb.config.NWBFileConfiguration( ...
                OutputPath=testCase.OutputPath, ...
                SessionMetadata=struct( ...
                    "session_description", "builtin converter test", ...
                    "identifier", "builtin-test", ...
                    "session_start_time", datetime(2026, 5, 10, TimeZone="UTC")), ...
                DataItems=item);

            converter = nansen.module.nwb.conversion.NWBFileConverter(config, ...
                DataResolver=@(name) data);
            nwbFile = nwbRead(converter.convert());
        end
    end
end

function names = imageNames(nwbFile)
%imageNames - Names in the projection image collection
%
%   NWB 2.9 renamed the Images collection's member property from image to
%   baseimage, and the module does not pin a matnwb version.

    collection = nwbFile.processing.get("ophys") ...
        .nwbdatainterface.get("FovProjectionImages");

    if isprop(collection, 'baseimage')
        names = sort(string(collection.baseimage.keys()));
    else
        names = sort(string(collection.image.keys()));
    end
end

function intervals = intervalsNamed(nwbFile, name)
%intervalsNamed - Read an interval table back, wherever NWB put it
%
%   NWB gives trials, epochs and invalid_times their own properties on
%   the file rather than keeping them in the general intervals set, and
%   matnwb routes a table with one of those names accordingly on export.

    canonicalProperty = "intervals_" + name;
    if isprop(nwbFile, canonicalProperty) && ~isempty(nwbFile.(canonicalProperty))
        intervals = nwbFile.(canonicalProperty);
        return
    end

    intervals = nwbFile.intervals.get(name);
end

function values = loadData(vectorData)
%loadData - Read a column's data whether or not it is a stub

    values = vectorData.data;
    if isa(values, "types.untyped.DataStub")
        values = values.load();
    end
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
