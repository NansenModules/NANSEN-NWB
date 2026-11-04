classdef getTypeMetadataStructTest < matlab.unittest.TestCase
%getTypeMetadataStructTest - Tests for getTypeMetadataStruct
%
%   Tests nansen.module.nwb.internal.getTypeMetadataStruct, which builds
%   the metadata template shown for a neurodata type.
%
%   The template must leave out the properties dataPropertyNames lists as
%   carrying data: converters fill those from the session's data, so a
%   template that offered them would ask for values nobody can enter.
%   A property is left out when the type or any class it extends lists
%   it, whichever class declares it.
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

        function leavesOutTheDataOfAnImage(testCase)
            % matnwb declares data on hdmf_common.Data, which Image extends.
            for typeName = ["types.core.GrayscaleImage", "types.core.RGBImage"]
                template = templateFor(typeName);

                testCase.verifyFalse(isfield(template, "data"), typeName)
                testCase.verifyTrue(isfield(template, "description"), typeName)
            end
        end

        function keepsTheDataOfTypesThatOnlyShareItsDeclaringClass(testCase)
            % VectorData also extends hdmf_common.Data, and no class in its
            % hierarchy lists data as carrying data.
            template = templateFor("types.hdmf_common.VectorData");

            testCase.verifyTrue(isfield(template, "data"))
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
