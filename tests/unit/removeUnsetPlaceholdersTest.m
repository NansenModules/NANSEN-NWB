classdef removeUnsetPlaceholdersTest < matlab.unittest.TestCase
%removeUnsetPlaceholdersTest - Tests for removeUnsetPlaceholders
%
%   Tests nansen.module.nwb.internal.removeUnsetPlaceholders, which turns
%   a configurator placeholder chosen in the argument editor back into
%   blank text so it is never saved as if it were a value.
%
%   See also: nansen.module.nwb.internal.removeUnsetPlaceholders

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function turnsThePlaceholderIntoBlankText(testCase)
            args = struct("ClampMode", '<not set>');

            cleaned = removePlaceholders(args);

            testCase.verifyEqual(cleaned, struct("ClampMode", ''))
        end

        function treatsAnyAngleBracketTextAsAPlaceholder(testCase)
            % The configurator stands "<...>" text for no value throughout.
            args = struct("ClampMode", '<undefined>');

            cleaned = removePlaceholders(args);

            testCase.verifyEqual(cleaned, struct("ClampMode", ''))
        end

        function keepsOrdinaryValues(testCase)
            args = struct("ClampMode", 'current', "Gain", 5, ...
                "InterfaceArgs", struct("sampling_frequency", 30.5));

            cleaned = removePlaceholders(args);

            testCase.verifyEqual(cleaned, args)
        end
    end
end

function args = removePlaceholders(args)
%removePlaceholders - Shorthand for the function under test

    args = nansen.module.nwb.internal.removeUnsetPlaceholders(args);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
