classdef getTypeMetadataStructTest < matlab.unittest.TestCase
%getTypeMetadataStructTest - Tests for getTypeMetadataStruct
%
%   Tests nansen.module.nwb.internal.getTypeMetadataStruct, which builds
%   the metadata template the configurator and createNewNWBInstance show
%   for a neurodata type.
%
%   The template must leave out the properties dataPropertyNames lists as
%   carrying data: converters fill those from the session's data, so a
%   template that offered them would ask for values nobody can enter.
%   A property is looked up under the class that declares it, so the
%   exclusions of a superclass apply to every type that extends it.
%
%   See also: nansen.module.nwb.internal.getTypeMetadataStruct,
%   nansen.module.nwb.internal.dataPropertyNames

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeDependenciesAreAvailable(testCase)
            testCase.assumeNotEmpty(which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
            testCase.assumeNotEmpty(which("utility.string.getSimpleClassName"), ...
                "The NANSEN utility packages are not on the MATLAB path.")
        end
    end

    methods (Test)

        function leavesOutTheDataOfATimeSeries(testCase)
            template = templateFor("types.core.TimeSeries");

            testCase.verifyFalse(any(isfield(template, ["data", "timestamps", "control"])))
            testCase.verifyTrue(isfield(template, "data_unit"))
        end

        function leavesOutDataDeclaredByASuperclass(testCase)
            % RoiResponseSeries declares rois; data and timestamps are
            % declared by TimeSeries, which it extends.
            template = templateFor("types.core.RoiResponseSeries");

            testCase.verifyFalse(any(isfield(template, ["rois", "data", "timestamps"])))
            testCase.verifyTrue(isfield(template, "data_unit"))
        end

        function leavesOutTheOrderOfImagesInACollection(testCase)
            template = templateFor("types.core.Images");

            testCase.verifyFalse(isfield(template, "order_of_images"))
        end
    end
end

function template = templateFor(typeName)
%templateFor - Shorthand for the function under test

    template = nansen.module.nwb.internal.getTypeMetadataStruct(typeName);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
