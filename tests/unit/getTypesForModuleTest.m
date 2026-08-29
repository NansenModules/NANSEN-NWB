classdef getTypesForModuleTest < matlab.unittest.TestCase
% getTypesForModuleTest - Tests for getTypesForModule
%
%   Tests nansen.module.nwb.internal.schemautil.getTypesForModule, which
%   lists the neurodata types a given NWB module defines.
%
%   The configuration table seeds its module column with a placeholder and
%   offers it as the first dropdown entry, so the placeholder reaches this
%   function during normal use and has to be answered rather than looked
%   up.
%
%   These tests need matnwb on the MATLAB path with its cached namespaces,
%   and the NANSEN utility packages. They are filtered otherwise.
%
%   See also: nansen.module.nwb.internal.schemautil.getTypesForModule

    properties (Constant)
        ModulePlaceholder = '<Select an NWB module>'
    end

    properties (TestParameter)
        % Modules that define types, given with and without the prefix the
        % function adds when it is absent.
        moduleName = struct( ...
            'bare', "ecephys", ...
            'prefixed', "nwb.ecephys", ...
            'ophys', "ophys")
    end

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeSchemaCacheIsAvailable(testCase)
            testCase.assumeNotEmpty(which("misc.getMatnwbDir"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty(which("utility.string.getSimpleClassName"), ...
                "The NANSEN utility packages are not on the MATLAB path.")
        end
    end

    methods (Test)

        function placeholderReturnsEmptyRatherThanThrowing(testCase)
        % The dropdown offers the placeholder as its first entry, so it
        % reaches here whenever a row has no module set yet.

            [neuroDataTypes, descriptions] = ...
                typesForModule(testCase.ModulePlaceholder);

            testCase.verifyEmpty(neuroDataTypes)
            testCase.verifyEmpty(descriptions)
        end

        function placeholderIsAlsoEmptyWithOneOutput(testCase)
            neuroDataTypes = typesForModule(testCase.ModulePlaceholder);

            testCase.verifyEmpty(neuroDataTypes)
        end

        function moduleReturnsTypesAndMatchingDescriptions(testCase, moduleName)
            [neuroDataTypes, descriptions] = typesForModule(moduleName);

            testCase.verifyNotEmpty(neuroDataTypes)
            testCase.verifySize(descriptions, size(neuroDataTypes))
        end

        function prefixedAndBareNamesAgree(testCase)
            bare = typesForModule("ecephys");
            prefixed = typesForModule("nwb.ecephys");

            testCase.verifyEqual(prefixed, bare)
        end

        function repeatedCallsReturnEqualResults(testCase)
        % The second call is served from the persistent cache.

            first = typesForModule("ecephys");
            second = typesForModule("ecephys");

            testCase.verifyEqual(second, first)
        end

        function deprecatedTypesAreExcluded(testCase)
            [neuroDataTypes, descriptions] = typesForModule("ecephys");

            testCase.verifyFalse(any(startsWith(descriptions, 'DEPRECATED')))
            testCase.verifyNotEmpty(neuroDataTypes)
        end

        function unknownModuleThrows(testCase)
        % An unrecognized module is a caller error, not an empty result,
        % so it must be distinguishable from the placeholder.

            testCase.verifyError(@() typesForModule("NotAModule"), ...
                'NANSEN_NWB:Internal:InvalidModuleName')
        end
    end
end

function varargout = typesForModule(moduleName)
    [varargout{1:nargout}] = ...
        nansen.module.nwb.internal.schemautil.getTypesForModule(char(moduleName));
end

function folderPath = repositoryRoot()
    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
