classdef getProcessedClassTest < matlab.unittest.TestCase
% getProcessedClassTest - Tests for getProcessedClass
%
%   Tests nansen.module.nwb.internal.schemautil.getProcessedClass, which
%   flattens a neurodata type's schema hierarchy into one struct of
%   attributes, datasets, subgroups and links.
%
%   The cases here guard against a class of failure that only appears for
%   particular types: entries in the hierarchy carry differently shaped
%   arrays, so concatenating them along the wrong dimension throws. Most
%   types happen to hold a single subgroup or attribute each and pass
%   either way, which is why the named types below are tested explicitly.
%
%   These tests need matnwb on the MATLAB path with generated core types,
%   and the NANSEN utility packages. They are filtered otherwise.
%
%   See also: nansen.module.nwb.internal.schemautil.getProcessedClass

    properties (TestParameter)

        % Types whose schema hierarchy holds unevenly shaped arrays. Each
        % one threw before the concatenation was fixed.
        unevenHierarchyType = struct( ...
            'nestedSubgroups', "IntracellularRecordingsTable", ...
            'externalImage', "ExternalImage", ...
            'durationVectorData', "DurationVectorData", ...
            'timestampVectorData', "TimestampVectorData")

        % A representative spread that already worked, to catch a fix that
        % trades one set of types for another.
        ordinaryType = struct( ...
            'timeSeries', "TimeSeries", ...
            'electrodesTable', "ElectrodesTable", ...
            'device', "Device", ...
            'nwbFile', "NWBFile")
    end

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeSchemaToolingIsAvailable(testCase)
            testCase.assumeNotEmpty(which("misc.getMatnwbDir"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty(which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
            testCase.assumeNotEmpty(which("utility.string.getSimpleClassName"), ...
                "The NANSEN utility packages are not on the MATLAB path.")
        end
    end

    methods (Test)

        function unevenHierarchyResolves(testCase, unevenHierarchyType)
            processedClass = processClassNamed(unevenHierarchyType);

            testCase.verifyClass(processedClass, "struct")
            testCase.verifyEqual( ...
                sort(string(fieldnames(processedClass)))', ...
                ["attributes", "datasets", "links", "subgroups", "type"])
        end

        function ordinaryTypeResolves(testCase, ordinaryType)
            processedClass = processClassNamed(ordinaryType);

            testCase.verifyClass(processedClass, "struct")
            testCase.verifyNotEmpty(processedClass.type)
        end

        function propertyInfoIsReturnedAlongsideTheClass(testCase)
        % getTypeMetadataStruct reads name and readonly off the second
        % output, so its shape is part of the contract.

            [~, propertyInfo] = processClassNamed("TimeSeries");

            testCase.verifyClass(propertyInfo, "struct")
            testCase.verifyTrue(all(isfield(propertyInfo, {'name', 'readonly'})))
        end

        function shortAndQualifiedNamesAgree(testCase)
            fromShort = processClassNamed("TimeSeries");
            fromQualified = processClassNamed("types.core.TimeSeries");

            testCase.verifyEqual(fromQualified.type, fromShort.type)
        end
    end
end

function varargout = processClassNamed(typeName)
    [varargout{1:nargout}] = ...
        nansen.module.nwb.internal.schemautil.getProcessedClass(typeName);
end

function folderPath = repositoryRoot()
    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
