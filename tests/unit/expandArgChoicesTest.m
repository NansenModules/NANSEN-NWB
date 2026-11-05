classdef expandArgChoicesTest < matlab.unittest.TestCase
%expandArgChoicesTest - Tests for expandArgChoices
%
%   Tests nansen.module.nwb.internal.expandArgChoices, which turns an
%   argument paired with a trailing-underscore companion of choices into
%   the Alternatives/Selection struct the configurator's argument editor
%   renders as a dropdown.
%
%   See also: nansen.module.nwb.internal.expandArgChoices

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function turnsAPairedBlankArgumentIntoAnUnsetDropdown(testCase)
            args = struct("ClampMode", "", "ClampMode_", {{'current', 'voltage'}});

            editorArgs = expand(args);

            testCase.verifyEqual(fieldnames(editorArgs), {'ClampMode'})
            testCase.verifyEqual(editorArgs.ClampMode.Alternatives, ...
                {'<not set>', 'current', 'voltage'})
            testCase.verifyEqual(editorArgs.ClampMode.Selection, '<not set>')
        end

        function selectsTheCurrentValue(testCase)
            args = struct("ClampMode", 'voltage', "ClampMode_", {{'current', 'voltage'}});

            editorArgs = expand(args);

            testCase.verifyEqual(editorArgs.ClampMode.Selection, 'voltage')
        end

        function appendsAValueOutsideTheChoices(testCase)
            % A value typed into the configuration by hand stays visible
            % and selected instead of being replaced by a choice.
            args = struct("ClampMode", 'custom', "ClampMode_", {{'current', 'voltage'}});

            editorArgs = expand(args);

            testCase.verifyEqual(editorArgs.ClampMode.Alternatives, ...
                {'<not set>', 'current', 'voltage', 'custom'})
            testCase.verifyEqual(editorArgs.ClampMode.Selection, 'custom')
        end

        function leavesAnArgumentWithoutACompanionAlone(testCase)
            args = struct("Gain", 5, "Units", 'mV');

            editorArgs = expand(args);

            testCase.verifyEqual(editorArgs, args)
        end

        function dropsACompanionWithoutItsArgument(testCase)
            args = struct("Gain", 5, "ClampMode_", {{'current', 'voltage'}});

            editorArgs = expand(args);

            testCase.verifyEqual(editorArgs, struct("Gain", 5))
        end

        function leavesANonTextArgumentAlone(testCase)
            % The dropdown form carries text, so choices for any other
            % class are ignored rather than destroying the value.
            args = struct("UseFilter", true, "UseFilter_", {{'yes', 'no'}});

            editorArgs = expand(args);

            testCase.verifyEqual(editorArgs, struct("UseFilter", true))
        end

        function roundTripsThroughCollapse(testCase)
            args = struct("ClampMode", 'voltage', "ClampMode_", {{'current', 'voltage'}});

            collapsed = nansen.module.nwb.internal.collapseArgChoices(expand(args));

            testCase.verifyEqual(collapsed, struct("ClampMode", 'voltage'))
        end
    end
end

function editorArgs = expand(args)
%expand - Shorthand for the function under test

    editorArgs = nansen.module.nwb.internal.expandArgChoices(args);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
