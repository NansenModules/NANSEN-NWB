classdef ConverterRegistryTest < matlab.unittest.TestCase
%ConverterRegistryTest - Tests for ConverterRegistry
%
%   Tests nansen.module.nwb.conversion.ConverterRegistry, which holds the
%   converters and answers which of them suit a given data variable.
%
%   The matching tests carry most of the weight. A registry that returns
%   every converter for every variable is useless to the configurator,
%   and one that returns too few hides the converter the user needs, so
%   the tests pin down the ranking rather than only that a match occurs.
%
%   Each test builds its own registry, so registering a converter cannot
%   leak into another test.
%
%   See also: nansen.module.nwb.conversion.ConverterRegistry

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test) % The converters that ship with the module

        function registersTheBuiltinConverters(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            converterNames = registry.names();

            testCase.verifyThat(converterNames, ...
                matlab.unittest.constraints.IsSupersetOf( ...
                    ["TimetableTimeSeries", "GenericNeurodataType", ...
                     "RoiGroupPlaneSegmentation", "RoiSignals"]))
        end

        function registersOneEntryPerNeuroconvInterface(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            descriptors = registry.list();
            neuroconvNames = [descriptors([descriptors.Source] == "neuroconv").Name];

            testCase.verifyThat(neuroconvNames, ...
                matlab.unittest.constraints.IsSupersetOf( ...
                    ["NeuroConvScanImageImagingInterface", ...
                     "NeuroConvSuite2pSegmentationInterface"]))
        end

        function listsNeuroconvConvertersWhetherOrNotPythonIsAvailable(testCase)
            % The configurator shows them greyed out with an explanation,
            % which it cannot do if the registry hides them.
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            descriptors = registry.list();

            testCase.verifyTrue(any([descriptors.RequiresPython]))
        end
    end

    methods (Test) % Ranking converters against source evidence

        function ranksAFormatMatchAboveAClassMatch(testCase)
            registry = testCase.registryWithRankingConverters();
            sourceInfo = sourceEvidence(MatlabClass="timetable", Format="scanimage");

            [descriptors, ranks] = registry.findForSourceInfo(sourceInfo);

            testCase.verifyEqual(descriptors(1).Name, "FormatConverter")
            testCase.verifyGreaterThan(ranks(1), ranks(2))
        end

        function ranksAClassMatchAboveAWildcardMatch(testCase)
            registry = testCase.registryWithRankingConverters();
            sourceInfo = sourceEvidence(MatlabClass="timetable");

            [descriptors, ranks] = registry.findForSourceInfo(sourceInfo);

            testCase.verifyEqual(descriptors(1).Name, "ClassConverter")
            testCase.verifyGreaterThan(ranks(1), ranks(end))
        end

        function ranksARecordedFormatAboveAGuessFromTheFileExtension(testCase)
            % A recorded format is evidence; an extension is a guess.
            registry = testCase.registryWithRankingConverters();
            sourceInfo = sourceEvidence(Format="scanimage", Path="/data/rec.tif");

            [descriptors, ranks] = registry.findForSourceInfo(sourceInfo);

            testCase.verifyEqual(descriptors(1).Name, "FormatConverter")
            testCase.verifyEqual(descriptors(2).Name, "ExtensionConverter")
            testCase.verifyGreaterThan(ranks(1), ranks(2))
        end

        function matchesAFileExtensionWhenNoFormatWasRecorded(testCase)
            registry = testCase.registryWithRankingConverters();
            sourceInfo = sourceEvidence(Path="/data/rec.tif");

            descriptors = registry.findForSourceInfo(sourceInfo);

            testCase.verifyEqual(descriptors(1).Name, "ExtensionConverter")
        end

        function doesNotMatchAConverterForAnUnrelatedVariable(testCase)
            % The point of separating class and format evidence: a
            % converter that reads ScanImage files must not be offered
            % for an ROI group.
            registry = testCase.registryWithRankingConverters();
            sourceInfo = sourceEvidence(MatlabClass="nansen.roi.RoiGroup");

            descriptors = registry.findForSourceInfo(sourceInfo);

            % Only the converter that accepts anything is left: the ones
            % naming a format or another class are ruled out.
            testCase.verifyEqual([descriptors.Name], "WildcardConverter")
        end

        function returnsEveryConverterWhenThereIsNoEvidence(testCase)
            % Nothing to discriminate on cannot rule anything out.
            registry = testCase.registryWithRankingConverters();

            descriptors = registry.findForSourceInfo(sourceEvidence());

            testCase.verifyNumElements(descriptors, numel(registry.list()))
        end
    end

    methods (Test) % Looking converters up

        function findsConvertersByTheTypeTheyProduce(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            descriptors = registry.findByNWBType("PlaneSegmentation");

            testCase.verifyThat([descriptors.Name], ...
                matlab.unittest.constraints.IsSupersetOf("RoiGroupPlaneSegmentation"))
        end

        function includesConvertersWhoseProducedTypeIsChosenLater(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            descriptors = registry.findByNWBType("SpatialSeries");

            testCase.verifyThat([descriptors.Name], ...
                matlab.unittest.constraints.IsSupersetOf("GenericNeurodataType"))
        end

        function findsConvertersTaggedForAProcessingModule(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            descriptors = registry.findByNWBModule("ophys");
            matchedNames = [descriptors.Name];

            testCase.verifyThat(matchedNames, ...
                matlab.unittest.constraints.IsSupersetOf("RoiSignals"))
            testCase.verifyFalse(any(matchedNames == "TimetableTimeSeries"))
        end

        function reportsTheAvailableConvertersWhenOneIsNotFound(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            testCase.verifyError(@() registry.get("NoSuchConverter"), ...
                "nansen:nwb:unknownConverter")
        end

        function reportsAMissingConverterNameSeparately(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            testCase.verifyError(@() registry.get(""), ...
                "nansen:nwb:unknownConverter")
        end
    end

    methods (Test) % Registering converters

        function rejectsASecondConverterWithTheSameName(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            testCase.verifyError( ...
                @() registry.add(testConverter("TimetableTimeSeries")), ...
                "nansen:nwb:duplicateConverter")
        end

        function rejectsASecondConverterWithTheSameDisplayName(testCase)
            % Two identical dropdown entries are indistinguishable.
            registry = nansen.module.nwb.conversion.ConverterRegistry();
            descriptor = testConverter("DistinctName");
            descriptor.DisplayName = "Timetable to TimeSeries";

            testCase.verifyError(@() registry.add(descriptor), ...
                "nansen:nwb:duplicateConverter")
        end

        function acceptsAConverterGivenAsAStruct(testCase)
            registry = nansen.module.nwb.conversion.ConverterRegistry();

            registry.add(struct( ...
                "Name", "StructConverter", ...
                "AcceptedClasses", "timetable", ...
                "ProducesNWBType", "TimeSeries", ...
                "Function", "nansen.module.nwb.conversion.builtin.convertTimetableToTimeSeries"))

            testCase.verifyEqual(registry.get("StructConverter").Name, "StructConverter")
        end
    end

    methods (Access = private)

        function registry = registryWithRankingConverters(~)
            import nansen.module.nwb.conversion.NWBConverterDescriptor

            % Only these three, so the ranking under test is not competing
            % with built-in converters that legitimately match as well.
            registry = nansen.module.nwb.conversion.ConverterRegistry( ...
                IncludeBuiltin=false);

            registry.add(NWBConverterDescriptor( ...
                Name="FormatConverter", ...
                AcceptedFormats="scanimage", ...
                ProducesNWBType="TwoPhotonSeries", ...
                Function=@(context) context.NwbFile))

            registry.add(NWBConverterDescriptor( ...
                Name="ClassConverter", ...
                AcceptedClasses="timetable", ...
                ProducesNWBType="TimeSeries", ...
                Function=@(context) context.NwbFile))

            registry.add(NWBConverterDescriptor( ...
                Name="ExtensionConverter", ...
                AcceptedFormats="tif", ...
                ProducesNWBType="ImageSeries", ...
                Function=@(context) context.NwbFile))

            registry.add(NWBConverterDescriptor( ...
                Name="WildcardConverter", ...
                AcceptedClasses="*", ...
                ProducesNWBType="*", ...
                Function=@(context) context.NwbFile))
        end
    end
end

function descriptor = testConverter(converterName)
%testConverter - A minimal valid descriptor under a given name

    descriptor = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
        Name=converterName, ...
        AcceptedClasses="*", ...
        ProducesNWBType="TimeSeries", ...
        Function=@(context) context.NwbFile);
end

function sourceInfo = sourceEvidence(options)
%sourceEvidence - Build a source evidence struct for the matching tests

    arguments
        options.MatlabClass (1,1) string = ""
        options.Format (1,1) string = ""
        options.Modality (1,1) string = ""
        options.Path (1,:) string = strings(1, 0)
    end

    sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
    sourceInfo.MatlabClass = options.MatlabClass;
    sourceInfo.Format = options.Format;
    sourceInfo.Modality = options.Modality;
    sourceInfo.Path = options.Path;
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
