classdef listNeurodataTypesTest < matlab.unittest.TestCase
%listNeurodataTypesTest - Tests for listNeurodataTypes
%
%   Tests nansen.module.nwb.lookup.listNeurodataTypes, which lists the
%   neurodata types a data variable can be converted to.
%
%   The list replaced a hand-maintained enumeration, so the tests check
%   the properties that motivated the change: that the types come from
%   the loaded schema, that they include types defined as datasets and
%   not only as groups, and that deprecated types stay out.
%
%   These tests need matnwb on the MATLAB path with its schema cache.
%   They are filtered when it is unavailable.
%
%   See also: nansen.module.nwb.lookup.listNeurodataTypes

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeSchemaIsAvailable(testCase)
            testCase.assumeNotEmpty(which("misc.getMatnwbDir"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty( ...
                which("nansen.module.nwb.internal.schemautil.getNWBModules"), ...
                "The schema lookup helpers are not available.")
        end
    end

    methods (Test) % What the list contains

        function listsTheCommonNeurodataTypes(testCase)
            typeNames = nansen.module.nwb.lookup.listNeurodataTypes();

            testCase.verifyThat(typeNames', ...
                matlab.unittest.constraints.IsSupersetOf( ...
                    ["TimeSeries", "ElectricalSeries", "TwoPhotonSeries", ...
                     "PlaneSegmentation", "RoiResponseSeries"]))
        end

        function includesTypesTheSchemaDefinesAsDatasets(testCase)
            % A module defines types under both groups and datasets.
            % Reading only the groups left every dataset type out, so
            % GrayscaleImage was missing from the list while being a
            % perfectly usable type.
            typeNames = nansen.module.nwb.lookup.listNeurodataTypes();

            testCase.verifyThat(typeNames', ...
                matlab.unittest.constraints.IsSupersetOf( ...
                    ["GrayscaleImage", "RGBImage"]))
        end

        function leavesOutDeprecatedTypes(testCase)
            % AnnotationSeries is deprecated in favour of EventsTable, and
            % offering it would steer users towards the older form.
            typeNames = nansen.module.nwb.lookup.listNeurodataTypes();

            testCase.verifyFalse(any(typeNames == "AnnotationSeries"))
        end

        function returnsTypesSortedByName(testCase)
            typeNames = nansen.module.nwb.lookup.listNeurodataTypes();

            testCase.verifyEqual(typeNames, sort(typeNames))
        end

        function returnsOneDescriptionPerType(testCase)
            [typeNames, descriptions] = nansen.module.nwb.lookup.listNeurodataTypes();

            testCase.verifySize(descriptions, size(typeNames))
        end

        function listsEachTypeOnce(testCase)
            % A type referenced from a second module would otherwise
            % appear twice in the dropdown.
            typeNames = nansen.module.nwb.lookup.listNeurodataTypes();

            testCase.verifyEqual(numel(unique(typeNames)), numel(typeNames))
        end
    end

    methods (Test) % Narrowing the list

        function narrowsTheListToOneModule(testCase)
            typeNames = nansen.module.nwb.lookup.listNeurodataTypes(Module="ophys");

            testCase.verifyThat(typeNames', ...
                matlab.unittest.constraints.IsSupersetOf( ...
                    ["TwoPhotonSeries", "PlaneSegmentation"]))
            testCase.verifyFalse(any(typeNames == "ElectricalSeries"))
        end

        function narrowsTheListToTypesAConverterProduces(testCase)
            producible = nansen.module.nwb.lookup.listNeurodataTypes(Producible=true);
            everything = nansen.module.nwb.lookup.listNeurodataTypes();

            testCase.verifyLessThan(numel(producible), numel(everything))
            testCase.verifyThat(producible', ...
                matlab.unittest.constraints.IsSupersetOf("PlaneSegmentation"))
        end

        function doesNotCountConvertersThatChooseTheirTypeLater(testCase)
            % The generic converter produces whatever it is asked for, so
            % counting it would mark every type producible and tell the
            % caller nothing.
            producible = nansen.module.nwb.lookup.listNeurodataTypes(Producible=true);

            testCase.verifyFalse(any(producible == "ImagingRetinotopy"))
        end
    end
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
