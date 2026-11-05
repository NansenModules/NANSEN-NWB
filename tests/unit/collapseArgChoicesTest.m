classdef collapseArgChoicesTest < matlab.unittest.TestCase
%collapseArgChoicesTest - Tests for collapseArgChoices
%
%   Tests nansen.module.nwb.internal.collapseArgChoices, which turns the
%   Alternatives/Selection dropdown structs of the configurator's argument
%   editor back into the plain text arguments a converter reads.
%
%   See also: nansen.module.nwb.internal.collapseArgChoices

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function returnsTheSelectedText(testCase)
            editorArgs = struct("ClampMode", struct( ...
                "Alternatives", {{'<not set>', 'current', 'voltage'}}, ...
                "Selection", 'voltage'));

            args = collapse(editorArgs);

            testCase.verifyEqual(args, struct("ClampMode", 'voltage'))
        end

        function turnsThePlaceholderIntoBlankText(testCase)
            editorArgs = struct("ClampMode", struct( ...
                "Alternatives", {{'<not set>', 'current'}}, ...
                "Selection", '<not set>'));

            args = collapse(editorArgs);

            testCase.verifyEqual(args, struct("ClampMode", ''))
        end

        function leavesOtherStructArgumentsAlone(testCase)
            % Nested interface arguments are structs too and must survive.
            editorArgs = struct("InterfaceArgs", struct("sampling_frequency", 30.5));

            args = collapse(editorArgs);

            testCase.verifyEqual(args, editorArgs)
        end
    end
end

function args = collapse(editorArgs)
%collapse - Shorthand for the function under test

    args = nansen.module.nwb.internal.collapseArgChoices(editorArgs);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
