classdef resolveMetadataTest < matlab.unittest.TestCase
%resolveMetadataTest - Tests for the linked-instance resolution of metadata
%
%   Tests nansen.module.nwb.internal.resolveMetadata, which the session
%   layer hands to the conversion runner as its MetadataResolver.
%
%   Resolving a named instance needs a project's metadata catalog, which
%   these tests do not have, so they cover what the function must do
%   without one: pass metadata through when it names no linked instance.
%
%   These tests need matnwb and the NANSEN utility packages on the path.
%
%   See also: nansen.module.nwb.internal.resolveMetadata

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeDependenciesAreAvailable(testCase)
            testCase.assumeNotEmpty(which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
            testCase.assumeNotEmpty(which("utility.struct.removeConfigFields"), ...
                "The NANSEN utility packages are not on the MATLAB path.")
        end
    end

    methods (Test)

        function passesMetadataWithoutTheTypesLinksThrough(testCase)
            % A patch-clamp series links to an electrode, which the sweeps
            % converter creates itself; metadata without that field must
            % come back as it went in rather than fail on the field.
            metadata = struct("description", "membrane potential");

            [resolved, instanceMap] = nansen.module.nwb.internal.resolveMetadata( ...
                metadata, "PatchClampSeries", NwbFile(), dictionary);

            testCase.verifyEqual(string(resolved.description), "membrane potential")
            testCase.verifyFalse(isConfigured(instanceMap))
        end

        function leavesMetadataOfATypeWithoutLinksAlone(testCase)
            metadata = struct("data_unit", "volts", "description", "speed");

            resolved = nansen.module.nwb.internal.resolveMetadata( ...
                metadata, "TimeSeries", NwbFile(), dictionary);

            testCase.verifyEqual(string(resolved.data_unit), "volts")
        end
    end
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
