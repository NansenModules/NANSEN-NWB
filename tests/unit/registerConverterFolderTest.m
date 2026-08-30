classdef registerConverterFolderTest < matlab.unittest.TestCase
%registerConverterFolderTest - Tests for custom converter registration
%
%   Tests nansen.module.nwb.registerConverterFolder and the folder
%   scanning behind it, which is how a lab plugs its own converters into
%   the configurator without changing this module.
%
%   The tests write a converter to a temporary folder and register it, so
%   they exercise the same path a lab would: a plain function that
%   returns its own descriptor when asked for one.
%
%   See also: nansen.module.nwb.registerConverterFolder

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end
    end

    methods (Test)

        function registersAConverterFromAFolder(testCase)
            folderPath = testCase.folderWithConverter("myLabConverter");
            registry = nansen.module.nwb.conversion.ConverterRegistry( ...
                IncludeBuiltin=false);

            registry.registerFolder(folderPath)

            testCase.verifyEqual(registry.get("myLabConverter").Name, "myLabConverter")
        end

        function marksAConverterFromAFolderAsCustom(testCase)
            % Where a converter came from is what the configurator groups
            % the dropdown by, and a folder converter is not a built-in
            % whatever its descriptor says.
            folderPath = testCase.folderWithConverter("myLabConverter");
            registry = nansen.module.nwb.conversion.ConverterRegistry( ...
                IncludeBuiltin=false);

            registry.registerFolder(folderPath)

            testCase.verifyEqual(registry.get("myLabConverter").Source, "custom")
        end

        function ignoresAFileThatIsNotAConverter(testCase)
            % Helper functions live beside converters in a lab's folder.
            folderPath = testCase.folderWithConverter("myLabConverter");
            writelines(["function y = notAConverter(x)", "    y = x;", "end"], ...
                fullfile(folderPath, "notAConverter.m"))
            registry = nansen.module.nwb.conversion.ConverterRegistry( ...
                IncludeBuiltin=false);

            registry.registerFolder(folderPath)

            testCase.verifyEqual(registry.names(), "myLabConverter")
        end

        function makesACustomConverterAvailableForMatchingData(testCase)
            folderPath = testCase.folderWithConverter("myLabConverter");
            registry = nansen.module.nwb.conversion.ConverterRegistry( ...
                IncludeBuiltin=false);
            registry.registerFolder(folderPath)

            sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
            sourceInfo.MatlabClass = "mylab.Recording";
            descriptors = registry.findForSourceInfo(sourceInfo);

            testCase.verifyEqual([descriptors.Name], "myLabConverter")
        end

        function keepsRegisteredFoldersAcrossARefresh(testCase)
            % A refresh picks up edited converters; losing the lab's
            % folder while doing so would be a surprise.
            %
            % This test touches the shared registry, so it starts from a
            % fresh one, and registers its cleanup refresh before creating
            % the folder: teardowns run in reverse, so the folder is gone
            % by the time the refresh runs and cannot be re-registered
            % into the instance later tests see.
            import nansen.module.nwb.conversion.ConverterRegistry
            ConverterRegistry.instance(Refresh=true);
            testCase.addTeardown(@() ConverterRegistry.instance(Refresh=true));

            folderPath = testCase.folderWithConverter("myLabConverter");

            nansen.module.nwb.registerConverterFolder(folderPath)
            nansen.module.nwb.refreshConverters()

            registry = nansen.module.nwb.conversion.ConverterRegistry.instance();
            testCase.verifyEqual(registry.get("myLabConverter").Name, "myLabConverter")
        end
    end

    methods (Access = private)

        function folderPath = folderWithConverter(testCase, converterName)
            %folderWithConverter - Write one custom converter to a new folder

            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            folderPath = string(fixture.Folder);

            writelines([ ...
                "function result = " + converterName + "(context)"
                "%" + converterName + " - Test converter for a lab folder"
                ""
                "    if nargin == 1 && (isstring(context) || ischar(context)) && ..."
                "            string(context) == ""descriptor"""
                "        result = nansen.module.nwb.conversion.NWBConverterDescriptor( ..."
                "            Name=""" + converterName + """, ..."
                "            AcceptedClasses=""mylab.Recording"", ..."
                "            ProducesNWBType=""TimeSeries"", ..."
                "            Function=@" + converterName + ");"
                "        return"
                "    end"
                ""
                "    result = context.NwbFile;"
                "end"], fullfile(folderPath, converterName + ".m"))
        end
    end
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
