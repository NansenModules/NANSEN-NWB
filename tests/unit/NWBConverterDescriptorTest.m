classdef NWBConverterDescriptorTest < matlab.unittest.TestCase
%NWBConverterDescriptorTest - Tests for NWBConverterDescriptor
%
%   Tests nansen.module.nwb.conversion.NWBConverterDescriptor, which
%   describes what a converter accepts, produces and requires.
%
%   Validation is what these tests are mostly about. A descriptor
%   declaring a combination the runner cannot honor should fail where it
%   is written, not partway through a conversion, so the tests check that
%   each inconsistent combination is refused.
%
%   See also: nansen.module.nwb.conversion.NWBConverterDescriptor

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test) % Defaults

        function displayNameDefaultsToTheConverterName(testCase)
            descriptor = validDescriptor();

            testCase.verifyEqual(descriptor.DisplayName, descriptor.Name)
        end

        function keepsAnExplicitDisplayName(testCase)
            descriptor = validDescriptor(DisplayName="Timetable to TimeSeries");

            testCase.verifyEqual(descriptor.DisplayName, "Timetable to TimeSeries")
        end

        function defaultsToMutatingTheFileInMemory(testCase)
            descriptor = validDescriptor();

            testCase.verifyEqual(descriptor.ExecutionMode, "mutate")
            testCase.verifyEqual(descriptor.PlacementPolicy, "config")
        end
    end

    methods (Test) % Rejecting inconsistent descriptors

        function rejectsABlankName(testCase)
            testCase.verifyError(@() validDescriptor(Name="  "), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsADescriptorThatAcceptsNothing(testCase)
            % A converter matching neither a class nor a format can never
            % be offered for any variable.
            testCase.verifyError( ...
                @() nansen.module.nwb.conversion.NWBConverterDescriptor( ...
                    Name="AcceptsNothing", ...
                    ProducesNWBType="TimeSeries", ...
                    Function=@(context) context), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsABlankEntryInAcceptedClasses(testCase)
            testCase.verifyError( ...
                @() validDescriptor(AcceptedClasses=["timetable", ""]), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsAnUnknownPrimaryGroup(testCase)
            testCase.verifyError(@() validDescriptor(PrimaryGroup="Nowhere"), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsAnExternalConverterThatLeavesPlacementToTheConfig(testCase)
            % An external converter has already written the file by the
            % time the runner could place anything.
            testCase.verifyError( ...
                @() validDescriptor(ExecutionMode="external", PlacementPolicy="config"), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsAFunctionTakingTheWrongNumberOfArguments(testCase)
            testCase.verifyError( ...
                @() validDescriptor(Function=@(first, second) first), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsAMetadataSchemaThatIsNeitherStructNorFunction(testCase)
            testCase.verifyError(@() validDescriptor(MetadataSchema="not a schema"), ...
                "nansen:nwb:invalidConverterDescriptor")
        end
    end

    methods (Test) % The NeuroConv contract

        function rejectsANeuroconvConverterThatDoesNotRequirePython(testCase)
            testCase.verifyError( ...
                @() neuroconvDescriptor(RequiresPython=false), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsANeuroconvConverterThatWantsLoadedData(testCase)
            % NeuroConv reads the source file itself.
            testCase.verifyError(@() neuroconvDescriptor(NeedsData=true), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsIncompleteNeuroconvConverterArguments(testCase)
            testCase.verifyError( ...
                @() neuroconvDescriptor(DefaultConverterArgs=struct( ...
                    "InterfaceClassName", "ScanImageImagingInterface")), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function rejectsAnUnknownSourcePathMode(testCase)
            testCase.verifyError( ...
                @() neuroconvDescriptor(DefaultConverterArgs=struct( ...
                    "InterfaceClassName", "ScanImageImagingInterface", ...
                    "SourceArgumentName", "file_path", ...
                    "SourcePathMode", "somewhere")), ...
                "nansen:nwb:invalidConverterDescriptor")
        end

        function acceptsAWellFormedNeuroconvConverter(testCase)
            descriptor = neuroconvDescriptor();

            testCase.verifyEqual(descriptor.Source, "neuroconv")
            testCase.verifyTrue(descriptor.RequiresPython)
        end
    end

    methods (Test) % Serialization

        function convertsToAStructAndBack(testCase)
            original = validDescriptor(NWBModuleTags=["ophys", "behavior"], ...
                RequiresNWBTypes="PlaneSegmentation");

            restored = nansen.module.nwb.conversion.NWBConverterDescriptor...
                .fromAny(original.toStruct());

            testCase.verifyEqual(restored.Name, original.Name)
            testCase.verifyEqual(restored.NWBModuleTags, original.NWBModuleTags)
            testCase.verifyEqual(restored.RequiresNWBTypes, original.RequiresNWBTypes)
        end

        function rejectsSomethingThatIsNotADescriptor(testCase)
            testCase.verifyError( ...
                @() nansen.module.nwb.conversion.NWBConverterDescriptor.fromAny(42), ...
                "nansen:nwb:invalidConverterDescriptor")
        end
    end
end

function descriptor = validDescriptor(options)
%validDescriptor - A valid descriptor, with any field overridden

    arguments
        options.Name (1,1) string = "TestConverter"
        options.DisplayName (1,1) string = ""
        options.AcceptedClasses (1,:) string = "timetable"
        options.PrimaryGroup (1,1) string = "Acquisition"
        options.ExecutionMode (1,1) string = "mutate"
        options.PlacementPolicy (1,1) string = "config"
        options.NWBModuleTags (1,:) string = strings(1, 0)
        options.RequiresNWBTypes (1,:) string = strings(1, 0)
        options.MetadataSchema = struct()
        options.Function (1,1) function_handle = @(context) context
    end

    descriptor = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
        Name=options.Name, ...
        DisplayName=options.DisplayName, ...
        AcceptedClasses=options.AcceptedClasses, ...
        ProducesNWBType="TimeSeries", ...
        RequiresNWBTypes=options.RequiresNWBTypes, ...
        PrimaryGroup=options.PrimaryGroup, ...
        NWBModuleTags=options.NWBModuleTags, ...
        ExecutionMode=options.ExecutionMode, ...
        PlacementPolicy=options.PlacementPolicy, ...
        MetadataSchema=options.MetadataSchema, ...
        Function=options.Function);
end

function descriptor = neuroconvDescriptor(options)
%neuroconvDescriptor - A valid NeuroConv descriptor, with overrides

    arguments
        options.RequiresPython (1,1) logical = true
        options.NeedsData (1,1) logical = false
        options.DefaultConverterArgs (1,1) struct = struct( ...
            "InterfaceClassName", "ScanImageImagingInterface", ...
            "SourceArgumentName", "file_path", ...
            "SourcePathMode", "file")
    end

    descriptor = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
        Name="TestNeuroconvConverter", ...
        Source="neuroconv", ...
        AcceptedFormats="scanimage", ...
        ProducesNWBType="TwoPhotonSeries", ...
        ExecutionMode="external", ...
        PlacementPolicy="converter", ...
        RequiresPython=options.RequiresPython, ...
        NeedsData=options.NeedsData, ...
        DefaultConverterArgs=options.DefaultConverterArgs, ...
        Function=@(context) context);
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
