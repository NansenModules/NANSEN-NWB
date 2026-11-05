classdef addUnsetPlaceholdersTest < matlab.unittest.TestCase
%addUnsetPlaceholdersTest - Tests for addUnsetPlaceholders
%
%   Tests nansen.module.nwb.internal.addUnsetPlaceholders, which prepends
%   the "<not set>" entry to the choice list of every argument that a
%   trailing-underscore companion field pairs with, before the
%   configurator's argument editor renders the list as a dropdown.
%
%   See also: nansen.module.nwb.internal.addUnsetPlaceholders

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function prependsThePlaceholderToAChoiceList(testCase)
            args = struct("ClampMode", '', "ClampMode_", {{'current', 'voltage'}});

            withPlaceholders = addPlaceholders(args);

            testCase.verifyEqual(withPlaceholders.ClampMode_, ...
                {'<not set>', 'current', 'voltage'})
            testCase.verifyEqual(withPlaceholders.ClampMode, '')
        end

        function leavesACompanionWithoutItsArgumentAlone(testCase)
            args = struct("Gain", 5, "ClampMode_", {{'current', 'voltage'}});

            withPlaceholders = addPlaceholders(args);

            testCase.verifyEqual(withPlaceholders, args)
        end

        function leavesAChoiceListOfANonTextArgumentAlone(testCase)
            % Choices for a non-text argument have no blank to stand for.
            args = struct("UseFilter", true, "UseFilter_", {{'yes', 'no'}});

            withPlaceholders = addPlaceholders(args);

            testCase.verifyEqual(withPlaceholders, args)
        end

        function leavesArgumentsWithoutCompanionsAlone(testCase)
            args = struct("Gain", 5, "Units", 'mV');

            withPlaceholders = addPlaceholders(args);

            testCase.verifyEqual(withPlaceholders, args)
        end
    end
end

function args = addPlaceholders(args)
%addPlaceholders - Shorthand for the function under test

    args = nansen.module.nwb.internal.addUnsetPlaceholders(args);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
