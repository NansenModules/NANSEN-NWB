classdef getRequiredPropertiesTest < matlab.unittest.TestCase
%getRequiredPropertiesTest - Tests for getRequiredProperties
%
%   Tests nansen.module.nwb.internal.schemautil.getRequiredProperties,
%   which resolves the schema-required property names for an NWB neurodata
%   type and caches the result.
%
%   These tests need matnwb on the MATLAB path with generated core types,
%   and the NANSEN utility packages used by the type lookup. They are
%   filtered when either is unavailable.
%
%   See also: nansen.module.nwb.internal.schemautil.getRequiredProperties

    properties (TestParameter)

        % Required properties per type, as reported by the NWB core
        % schema. ElectricalSeries is included because it derives from
        % TimeSeries but fixes the unit and adds an electrodes reference,
        % so a lookup that collapsed to the base type would be caught.
        neurodataType = struct( ...
            'timeSeries', struct( ...
                'Name', "TimeSeries", ...
                'RequiredProperties', ["data", "data_unit"]), ...
            'imageSeries', struct( ...
                'Name', "ImageSeries", ...
                'RequiredProperties', ["data", "data_unit"]), ...
            'spatialSeries', struct( ...
                'Name', "SpatialSeries", ...
                'RequiredProperties', "data"), ...
            'electricalSeries', struct( ...
                'Name', "ElectricalSeries", ...
                'RequiredProperties', ["data", "electrodes"]), ...
            'processingModule', struct( ...
                'Name', "ProcessingModule", ...
                'RequiredProperties', "description"))
    end

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeSchemaLookupIsAvailable(testCase)
            testCase.assumeNotEmpty( ...
                which("schemes.internal.getRequiredPropsForClass"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty( ...
                which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
            testCase.assumeNotEmpty( ...
                which("utility.string.getSimpleClassName"), ...
                "The NANSEN utility packages are not on the MATLAB path.")
        end
    end

    methods (Test) % Resolving type names

        function typeResolvesToItsRequiredProperties(testCase, neurodataType)
            props = requiredPropertiesFor(neurodataType.Name);

            testCase.verifyEqual(sort(string(props)), ...
                sort(neurodataType.RequiredProperties))
        end

        function fullyQualifiedTypeNameGivesSameResult(testCase)
            shortName = requiredPropertiesFor("TimeSeries");
            fullName = requiredPropertiesFor("types.core.TimeSeries");

            testCase.verifyEqual(sort(string(fullName)), sort(string(shortName)))
        end

        function charAndStringInputsAreEquivalent(testCase)
            fromChar = requiredPropertiesFor('SpatialSeries');
            fromString = requiredPropertiesFor("SpatialSeries");

            testCase.verifyEqual(sort(string(fromChar)), sort(string(fromString)))
        end
    end

    methods (Test) % Return value contract

        function returnsCellArrayOfCharacterVectors(testCase)
        % checkNWBConfiguration indexes the result with braces and
        % passes the elements to isfield, so the cell-of-char shape is
        % part of the contract rather than an incidental detail.

            props = requiredPropertiesFor("TimeSeries");

            testCase.verifyClass(props, "cell")
            testCase.verifyTrue(all(cellfun(@ischar, props)))
        end

        function typeWithoutRequiredPropertiesReturnsEmpty(testCase)
        % Device has no required properties. Callers branch on isempty,
        % so an empty result must be returned rather than an error.

            props = requiredPropertiesFor("Device");

            testCase.verifyEmpty(props)
            testCase.verifyClass(props, "cell")
        end

        function derivedTypeDiffersFromItsBaseType(testCase)
            baseProps = sort(string(requiredPropertiesFor("TimeSeries")));
            derivedProps = sort(string(requiredPropertiesFor("ElectricalSeries")));

            testCase.verifyNotEqual(derivedProps, baseProps)
        end
    end

    methods (Test) % Caching and errors

        function repeatedCallsReturnEqualResults(testCase)
        % The second call is served from the persistent cache, which
        % stores the properties wrapped in a cell. This exercises the
        % unwrapping path.

            first = requiredPropertiesFor("ImageSeries");
            second = requiredPropertiesFor("ImageSeries");

            testCase.verifyEqual(second, first)
            testCase.verifyNotEmpty(second)
        end

        function cacheKeepsTypesSeparate(testCase)
        % Interleaving types guards against one cache entry serving another.

            timeSeriesProps = sort(string(requiredPropertiesFor("TimeSeries")));
            spatialProps = sort(string(requiredPropertiesFor("SpatialSeries")));

            testCase.verifyEqual(timeSeriesProps, ["data", "data_unit"])
            testCase.verifyEqual(spatialProps, "data")
        end

        function unknownTypeNameThrows(testCase)
        % An unresolvable type name must raise rather than return empty,
        % because callers cannot otherwise distinguish "no required
        % properties" from "type does not exist". The identifier is part
        % of the contract: checkNWBConfiguration needs it to tell an
        % unknown type from an unexpected failure.

            testCase.verifyError( ...
                @() requiredPropertiesFor("NotARealNeurodataType"), ...
                'nansen:nwb:unknownNeurodataType')
        end

        function unknownTypeNameIsNamedInTheError(testCase)
        % The message reaches the user through a dialog, so it has to say
        % which type was rejected.

            thrownError = catchError( ...
                @() requiredPropertiesFor("NotARealNeurodataType"));

            testCase.verifyNotEmpty(thrownError)
            testCase.verifySubstring(thrownError.message, "NotARealNeurodataType")
        end
    end
end

function props = requiredPropertiesFor(typeName)
    props = nansen.module.nwb.internal.schemautil.getRequiredProperties(typeName);
end

function thrownError = catchError(functionHandle)
% catchError - Return the exception raised by functionHandle, or an empty
%   MException if it did not raise. Kept out of the test methods so they
%   stay free of control flow.

    try
        functionHandle();
        thrownError = MException.empty;
    catch thrownError
    end
end

function folderPath = repositoryRoot()
    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
