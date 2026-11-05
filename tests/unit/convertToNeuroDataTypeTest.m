classdef convertToNeuroDataTypeTest < matlab.unittest.TestCase
%convertToNeuroDataTypeTest - Tests for the generic neurodata type builder
%
%   Tests nansen.module.nwb.file.convertToNeuroDataType, which turns a
%   data variable and its metadata into one neurodata type by name. The
%   cases cover what the generic conversion path relies on: timetables
%   get their time from their row times, a time series built from plain
%   data must be told when its samples were taken, and a type without
%   time, such as an image, needs no such thing.
%
%   These tests need matnwb on the MATLAB path with generated core types.
%
%   See also: nansen.module.nwb.file.convertToNeuroDataType

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeMatnwbIsAvailable(testCase)
            testCase.assumeNotEmpty(which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
        end
    end

    methods (Test)

        function buildsATimeSeriesFromATimetable(testCase)
            data = timetable(seconds((0:4)'), (1:5)', VariableNames="value");

            series = convert(struct("data_unit", "volts"), data, "TimeSeries");

            testCase.verifyClass(series, "types.core.TimeSeries")
            testCase.verifyEqual(series.starting_time_rate, 1)
        end

        function requiresATimeReferenceForATimeSeriesBuiltFromPlainData(testCase)
            testCase.verifyError( ...
                @() convert(struct("data_unit", "volts"), (1:10)', "TimeSeries"), ...
                "nansen:nwb:missingTimeReference")
        end

        function buildsATimeSeriesFromPlainDataWithAStartingTime(testCase)
            metadata = struct("data_unit", "volts", ...
                "starting_time", 0, "starting_time_rate", 30);

            series = convert(metadata, (1:10)', "TimeSeries");

            testCase.verifyEqual(series.starting_time_rate, 30)
        end

        function buildsATypeWithoutTimeFromPlainData(testCase)
            % An image has no timestamps to supply, so none may be demanded.
            image = convert(struct("description", "mean projection"), ...
                magic(8), "GrayscaleImage");

            testCase.verifyClass(image, "types.core.GrayscaleImage")
            testCase.verifyEqual(image.data, magic(8))
        end
    end
end

function neuroData = convert(metadata, data, typeName)
    neuroData = nansen.module.nwb.file.convertToNeuroDataType(metadata, data, typeName);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
