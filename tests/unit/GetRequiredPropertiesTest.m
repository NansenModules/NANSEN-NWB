classdef GetRequiredPropertiesTest < matlab.unittest.TestCase
% GetRequiredPropertiesTest - Unit tests for getRequiredProperties
%
%   Tests nansen.module.nwb.internal.schemautil.getRequiredProperties,
%   which resolves the schema-required property names for an NWB neurodata
%   type and caches the result.
%
%   These tests require matnwb to be on the MATLAB path with generated
%   core types available. Tests are filtered out when it is not.
%
%   See also: nansen.module.nwb.internal.schemautil.getRequiredProperties

    methods (TestClassSetup)

        function assumeMatNwbIsAvailable(testCase)
            testCase.assumeNotEmpty( ...
                which("schemes.internal.getRequiredPropsForClass"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty( ...
                which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
        end
    end

    methods (Test) % Resolving type names

        function shortTypeNameResolvesRequiredProperties(testCase)
        % A bare neurodata type name is resolved via the type lookup.

            props = testCase.getProps("TimeSeries");

            testCase.verifyEqual(sort(string(props)), ["data", "data_unit"])
        end

        function fullyQualifiedTypeNameGivesSameResult(testCase)
        % The fully qualified name is accepted and resolves identically.

            shortName = testCase.getProps("TimeSeries");
            fullName = testCase.getProps("types.core.TimeSeries");

            testCase.verifyEqual(sort(string(fullName)), sort(string(shortName)))
        end

        function charAndStringInputsAreEquivalent(testCase)
        % The function accepts both char vectors and string scalars.

            fromChar = testCase.getProps('SpatialSeries');
            fromString = testCase.getProps("SpatialSeries");

            testCase.verifyEqual(sort(string(fromChar)), sort(string(fromString)))
        end
    end

    methods (Test) % Return value contract

        function returnsCellArrayOfCharacterVectors(testCase)
        % validateNwbConfiguration indexes the result with braces and
        % passes the elements to isfield, so the cell-of-char shape is
        % part of the contract rather than an incidental detail.

            props = testCase.getProps("TimeSeries");

            testCase.verifyClass(props, "cell")
            testCase.verifyTrue(all(cellfun(@(p) ischar(p), props)))
        end

        function typeWithoutRequiredPropertiesReturnsEmpty(testCase)
        % Device has no required properties. Callers branch on isempty,
        % so an empty result must be returned rather than an error.

            props = testCase.getProps("Device");

            testCase.verifyEmpty(props)
            testCase.verifyClass(props, "cell")
        end

        function derivedTypeReportsItsOwnRequiredProperties(testCase)
        % ElectricalSeries derives from TimeSeries but fixes the unit and
        % adds an electrodes reference, so the two sets differ. This
        % guards against the lookup collapsing to the base type.

            baseProps = sort(string(testCase.getProps("TimeSeries")));
            derivedProps = sort(string(testCase.getProps("ElectricalSeries")));

            testCase.verifyEqual(derivedProps, ["data", "electrodes"])
            testCase.verifyNotEqual(derivedProps, baseProps)
        end
    end

    methods (Test) % Caching and errors

        function repeatedCallsReturnEqualResults(testCase)
        % The second call is served from the persistent cache, which
        % stores the properties wrapped in a cell. This exercises the
        % unwrapping path.

            first = testCase.getProps("ImageSeries");
            second = testCase.getProps("ImageSeries");

            testCase.verifyEqual(second, first)
            testCase.verifyNotEmpty(second)
        end

        function cacheKeepsTypesSeparate(testCase)
        % Distinct types must not collide in the cache.

            timeSeriesProps = sort(string(testCase.getProps("TimeSeries")));
            spatialProps = sort(string(testCase.getProps("SpatialSeries")));

            testCase.verifyEqual(timeSeriesProps, ["data", "data_unit"])
            testCase.verifyEqual(spatialProps, "data")
        end

        function unknownTypeNameThrows(testCase)
        % An unresolvable type name must raise rather than return empty,
        % because callers cannot otherwise distinguish "no required
        % properties" from "type does not exist".

            testCase.verifyError( ...
                @() testCase.getProps("NotARealNeurodataType"), ?MException)
        end
    end

    methods (Access = private)

        function props = getProps(~, typeName)
            props = nansen.module.nwb.internal.schemautil ...
                .getRequiredProperties(typeName);
        end
    end
end
