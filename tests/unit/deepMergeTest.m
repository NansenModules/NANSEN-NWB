classdef deepMergeTest < matlab.unittest.TestCase
%deepMergeTest - Tests for deepMerge
%
%   Tests nansen.module.nwb.internal.deepMerge, which lays one struct
%   over another and is what metadata defaults are applied with.
%
%   The empty-value rule carries the weight: a configuration field
%   holding "" means "never filled in", and a merge that let it erase a
%   project default would make the defaults useless exactly where they
%   are needed.
%
%   See also: nansen.module.nwb.internal.deepMerge

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function overlayValueWinsOverBaseValue(testCase)
            merged = merge(struct("lab", "Default lab"), struct("lab", "Roth lab"));

            testCase.verifyEqual(merged.lab, "Roth lab")
        end

        function baseValueSurvivesWhenOverlayLacksTheField(testCase)
            merged = merge(struct("institution", "UiO"), struct("lab", "Roth lab"));

            testCase.verifyEqual(merged.institution, "UiO")
            testCase.verifyEqual(merged.lab, "Roth lab")
        end

        function overlayFieldAbsentFromBaseIsAdded(testCase)
            merged = merge(struct(), struct("session_id", "s01"));

            testCase.verifyEqual(merged.session_id, "s01")
        end

        function emptyOverlayValueKeepsTheBaseValue(testCase)
            % "" and [] mean "never filled in", not "erase the default".
            base = struct("institution", "UiO", "lab", "Vervaeke");

            merged = merge(base, struct("institution", "", "lab", []));

            testCase.verifyEqual(merged.institution, "UiO")
            testCase.verifyEqual(merged.lab, "Vervaeke")
        end

        function falseAndZeroAreValuesNotGaps(testCase)
            base = struct("flag", true, "count", 5);

            merged = merge(base, struct("flag", false, "count", 0));

            testCase.verifyFalse(merged.flag)
            testCase.verifyEqual(merged.count, 0)
        end

        function nestedStructsMergeFieldByField(testCase)
            base = struct("Subject", struct("species", "Mus musculus", "sex", "U"));
            overlay = struct("Subject", struct("sex", "M"));

            merged = merge(base, overlay);

            testCase.verifyEqual(merged.Subject.species, "Mus musculus")
            testCase.verifyEqual(merged.Subject.sex, "M")
        end

        function arraysAreReplacedWholeNotMergedElementwise(testCase)
            base = struct("keywords", ["a", "b", "c"]);

            merged = merge(base, struct("keywords", "d"));

            testCase.verifyEqual(merged.keywords, "d")
        end

        function structArraysAreReplacedWhole(testCase)
            % A struct array is a value, not a container to merge into.
            base = struct("devices", struct("name", {"One", "Two"}));
            overlay = struct("devices", struct("name", {"Three"}));

            merged = merge(base, overlay);

            testCase.verifyNumElements(merged.devices, 1)
            testCase.verifyEqual(merged.devices.name, "Three")
        end
    end
end

function merged = merge(baseStruct, overlayStruct)
%merge - Shorthand for the function under test

    merged = nansen.module.nwb.internal.deepMerge(baseStruct, overlayStruct);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
