classdef mergeConverterArgsTest < matlab.unittest.TestCase
%mergeConverterArgsTest - Tests for mergeConverterArgs
%
%   Tests nansen.module.nwb.internal.mergeConverterArgs, the rule by
%   which a data item's converter arguments are laid over the converter's
%   defaults. The runner, the session builder and the start-time lookup
%   all use it, so that what one predicts the others pass.
%
%   See also: nansen.module.nwb.internal.mergeConverterArgs

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function keepsDefaultsTheItemDoesNotSet(testCase)
            merged = merge(struct("Gain", 1, "Units", "mV"), struct("Gain", 5));

            testCase.verifyEqual(merged, struct("Gain", 5, "Units", "mV"))
        end

        function replacesAStructDefaultWhole(testCase)
            % An item that gives ElectrodeMetadata gives all of it, so a
            % default field it leaves out is not carried over.
            defaults = struct("ElectrodeMetadata", struct("name", "e0", "cell_id", "c1"));

            merged = merge(defaults, struct("ElectrodeMetadata", struct("name", "pipette")));

            testCase.verifyEqual(merged.ElectrodeMetadata, struct("name", "pipette"))
        end
    end
end

function merged = merge(defaultArgs, itemArgs)
%merge - Shorthand for the function under test

    merged = nansen.module.nwb.internal.mergeConverterArgs(defaultArgs, itemArgs);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
