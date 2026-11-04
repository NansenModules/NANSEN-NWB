classdef iso8601ToDatetimeTest < matlab.unittest.TestCase
%iso8601ToDatetimeTest - Tests for iso8601ToDatetime
%
%   Tests nansen.module.nwb.internal.iso8601ToDatetime, which reads the
%   session start time from JSON configurations, NeuroConv metadata and
%   recording headers.
%
%   datetimeToIso8601 always writes milliseconds, so a round trip alone
%   never exercises text without a fraction of a second. Hand-written
%   configurations and file headers usually have none.
%
%   See also: nansen.module.nwb.internal.iso8601ToDatetime

    properties (TestParameter)
        % Text that is not an ISO 8601 date and time, keyed by what is wrong.
        malformedText = struct( ...
            "dateOnly", "2026-05-10", ...
            "spaceSeparator", "2026-05-10 14:30:15", ...
            "trailingDecimalPoint", "2026-05-10T14:30:15.", ...
            "letterAfterSeconds", "2026-05-10T14:30:15x5", ...
            "notADate", "2026-13-45T14:30:15")
    end

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function wholeSecondsWithoutOffsetHasNoTimeZone(testCase)
            value = parse("2026-05-10T14:30:15");

            testCase.verifyEqual(value, datetime(2026, 5, 10, 14, 30, 15))
            testCase.verifyEqual(string(value.TimeZone), "")
        end

        function wholeSecondsWithOffsetKeepsTheOffset(testCase)
            value = parse("2026-05-10T14:30:15+02:00");

            testCase.verifyEqual(string(value.TimeZone), "+02:00")
            testCase.verifyEqual([value.Hour, value.Minute, value.Second], [14, 30, 15])
        end

        function wholeSecondsInUtc(testCase)
            value = parse("2026-05-10T14:30:15Z");

            testCase.verifyEqual(string(value.TimeZone), "UTC")
            testCase.verifyEqual(value.Hour, 14)
        end

        function fractionOfASecondIsRead(testCase)
            value = parse("2026-05-10T14:30:15.250-05:00");

            testCase.verifyEqual(value.Second, 15.25, AbsTol=1e-9)
            testCase.verifyEqual(string(value.TimeZone), "-05:00")
        end

        function writtenTextReadsBack(testCase)
            original = datetime(2026, 5, 10, 14, 30, 15.5, TimeZone="Europe/Oslo");
            text = nansen.module.nwb.internal.datetimeToIso8601(original);

            testCase.verifyEqual(parse(text), original)
        end

        function malformedTextGivesEmpty(testCase, malformedText)
            testCase.verifyEmpty(parse(malformedText))
        end
    end
end

function value = parse(text)
%parse - Shorthand for the function under test

    value = nansen.module.nwb.internal.iso8601ToDatetime(text);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
