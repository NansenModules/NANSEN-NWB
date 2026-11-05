classdef NWBConfiguratorAppTest < matlab.unittest.TestCase
%NWBConfiguratorAppTest - Tests for the NWB configurator app
%
%   Tests nansen.module.nwb.gui.NWBConfiguratorApp through its MATLAB
%   surface: the rows it lists, the state its panel is drawn from, the
%   edits it accepts and what it saves. The list is drawn by entity-table,
%   and every test runs with both of its backends, so nothing here drives
%   the page or the table directly.
%
%   Every app is created hidden, with a private registry of fake
%   converters and a stub for the Python check, so the tests open no
%   window, need no Python and do not depend on the converters that ship.
%
%   These tests need entity-table and matnwb on the MATLAB path.
%
%   See also: nansen.module.nwb.gui.NWBConfiguratorApp

    properties (TestParameter)
        ListBackend = {'html', 'uitable'}
    end

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeDependenciesAreAvailable(testCase)
            testCase.assumeNotEmpty(which("entitytable.EntityTableView"), ...
                "entity-table is not on the MATLAB path.")
            testCase.assumeNotEmpty(which("types.core.TimeSeries"), ...
                "matnwb core types have not been generated.")
        end
    end

    methods (Test) % The list

        function listsOneRowPerItem(testCase, ListBackend)
            app = testCase.createApp(configurationWith([speedItem(), pupilItem()]), ListBackend);

            rows = app.listTable();

            % speed names no converter, so the list shows the choice as
            % left to the runner and what that resolves to.
            testCase.verifyEqual(rows.Variable', ["speed", "pupil"])
            testCase.verifyEqual(rows.Converter(1), "Auto (let the runner decide)")
            testCase.verifyEqual(rows.Produces(1), "TimeSeries")
            testCase.verifyEqual(rows.Status(1), "ok")
            testCase.verifyEqual(rows.Status(2), "ambiguous")
        end

        function selectsTheFirstItemOnOpening(testCase, ListBackend)
            app = testCase.createApp(configurationWith([speedItem(), pupilItem()]), ListBackend);

            testCase.verifyEqual(app.SelectedVariable, "speed")
            testCase.verifyEqual(app.panelState().Variable, "speed")
        end

        function addingAVariableAppendsAnItemAndSelectsIt(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            app.addVariable("frames")

            testCase.verifyEqual(app.listTable().Variable', ["speed", "frames"])
            testCase.verifyEqual(app.SelectedVariable, "frames")
            testCase.verifyEqual(app.Config.DataItems(2).NWBVariableName, "frames")
        end

        function refusesAVariableAlreadyConfigured(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            testCase.verifyError(@() app.addVariable("speed"), ...
                "nansen:nwb:variableAlreadyConfigured")
        end

        function removingAVariableDropsItsItem(testCase, ListBackend)
            app = testCase.createApp(configurationWith([speedItem(), pupilItem()]), ListBackend);

            app.removeVariable("speed")

            testCase.verifyEqual(app.listTable().Variable', "pupil")
            testCase.verifyEqual(app.SelectedVariable, "")
        end
    end

    methods (Test) % The panel

        function suggestsConvertersMatchingTheSourceFirst(testCase, ListBackend)
            % speed records a format and a class; the format match ranks
            % above the class match, and both come before the rest.
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            choices = app.converterChoices();

            testCase.verifyEqual([choices(1:3).Name], ["", "FormatMatch", "ClassMatch"])
            testCase.verifyEqual([choices(2:3).IsSuggested], [true, true])
            testCase.verifyTrue(any([choices.Name] == "GenericNeurodataType"))
        end

        function choosingAConverterTakesItsDefaultPlacement(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            app.setConverter("ProcessingOne")

            state = app.panelState();
            testCase.verifyEqual(state.PrimaryGroup, "Processing")
            testCase.verifyEqual(state.NWBModule, "ophys")
            testCase.verifyTrue(state.PlacementOwnedByConverter)
            testCase.verifyEqual(app.listTable().Placement, "Processing/ophys")
        end

        function choosingTheGenericConverterShowsModuleAndType(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            app.setConverter("GenericNeurodataType")
            testCase.verifyTrue(app.panelState().IsGeneric)
            testCase.verifyEqual(app.panelState().Status, "set target type")

            app.setTargetType("ophys", "TwoPhotonSeries")

            state = app.panelState();
            testCase.verifyEqual(state.Status, "ok")
            testCase.verifyEqual(state.TargetNWBType, "TwoPhotonSeries")
            testCase.verifyEqual(app.listTable().Produces, "TwoPhotonSeries")
        end

        function reportsAConverterThatNeedsPython(testCase, ListBackend)
            item = speedItem();
            item.ConverterName = "PythonOne";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();

            testCase.verifyEqual(state.Status, "needs Python")
            testCase.verifyTrue(state.NeedsPython)
            testCase.verifySubstring(state.Message, "No Python here")
        end

        function opensAnItemNamingAnUnregisteredConverter(testCase, ListBackend)
            % A configuration can name a custom converter whose folder
            % this session has not registered.
            item = speedItem();
            item.ConverterName = "NotRegistered";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();
            choices = app.converterChoices();

            testCase.verifyEqual(app.listTable().Converter, "NotRegistered (not registered)")
            testCase.verifyEqual(state.Status, "unknown converter")
            testCase.verifyEqual(state.ConverterLabel, "NotRegistered (not registered)")
            testCase.verifyEqual(choices(2).Name, "NotRegistered")
        end

        function showsADefaultConverterAsTheRunnersChoice(testCase, ListBackend)
            % The pilot configurator wrote "Default" for no converter, and
            % the registry resolves such an item from its source.
            item = speedItem();
            item.ConverterName = "Default";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();

            testCase.verifyEqual(app.listTable().Converter, "Auto (let the runner decide)")
            testCase.verifyEqual(state.ConverterName, "")
            testCase.verifyEqual(state.Status, "ok")
        end

        function editsThePlacementMetadataAndArgumentsOfTheItem(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            app.setPlacement("Processing", "behavior")
            app.setMetadata(struct("description", "running speed"))
            app.setConverterArgs(struct("Gain", 2))

            item = app.Config.DataItems(1);
            testCase.verifyEqual([item.PrimaryGroup, item.NWBModule], ["Processing", "behavior"])
            testCase.verifyEqual(item.Metadata, struct("description", "running speed"))
            testCase.verifyEqual(item.ConverterArgs, struct("Gain", 2))
            testCase.verifyEqual(app.listTable().Placement, "Processing/behavior")
        end

        function opensAnItemWhoseGroupIsNotAnNwbGroup(testCase, ListBackend)
            % A pilot configuration can hold a lower-case group name.
            item = speedItem();
            item.PrimaryGroup = "acquisition";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();

            testCase.verifyEqual(state.PrimaryGroup, "acquisition")
            testCase.verifyEqual(state.Status, "unknown group")
        end

        function showsWhereAConverterThatOwnsPlacementPutsTheOutput(testCase, ListBackend)
            % frames resolves to ProcessingOne on its own, and that
            % converter writes to Processing/ophys whatever the item says.
            item = framesItem();
            item.PrimaryGroup = "Acquisition";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();

            testCase.verifyEqual(app.listTable().Placement, "Processing/ophys")
            testCase.verifyEqual(state.PrimaryGroup, "Processing")
            testCase.verifyTrue(state.PlacementOwnedByConverter)
            testCase.verifySubstring(state.Message, "in Processing/ophys")
        end

        function reportsAnAmbiguousItem(testCase, ListBackend)
            % pupil records only its class, which two converters accept.
            app = testCase.createApp(configurationWith(pupilItem()), ListBackend);

            state = app.panelState();

            testCase.verifyEqual(state.Status, "ambiguous")
            testCase.verifySubstring(state.Message, "ClassMatch")
        end

        function guidesTowardAHintedArgumentLeftUnset(testCase, ListBackend)
            % HintedOne hints its ClampMode argument, which its defaults
            % seed blank and the item does not set.
            item = speedItem();
            item.ConverterName = "HintedOne";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();

            testCase.verifyEqual(state.Status, "set converter args")
            testCase.verifySubstring(state.Message, "ClampMode")
        end

        function clearsTheHintOnceTheArgumentIsSet(testCase, ListBackend)
            item = speedItem();
            item.ConverterName = "HintedOne";
            app = testCase.createApp(configurationWith(item), ListBackend);

            app.setConverterArgs(struct("ClampMode", "current_clamp"))

            testCase.verifyEqual(app.panelState().Status, "ok")
        end

        function flagsANeuroconvBackedConverter(testCase, ListBackend)
            % The panel greys the metadata editor for a NeuroConv item,
            % whose metadata comes from its source files.
            item = speedItem();
            item.ConverterName = "PythonOne";
            app = testCase.createApp(configurationWith(item), ListBackend);

            testCase.verifyTrue(app.panelState().IsNeuroconv)
        end

        function flagsAnItemResolvedToANeuroconvConverter(testCase, ListBackend)
            % An item left to the runner counts as NeuroConv-backed when
            % its source resolves to a NeuroConv converter.
            app = testCase.createApp(configurationWith(tracesItem()), ListBackend);

            testCase.verifyTrue(app.panelState().IsNeuroconv)
        end

        function reportsEditableArgumentsFromConverterDefaults(testCase, ListBackend)
            % HintedOne declares a default argument the item leaves unset:
            % the editor has a field to open on, the item none of its own.
            item = speedItem();
            item.ConverterName = "HintedOne";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();

            testCase.verifyTrue(state.HasEditableArgs)
            testCase.verifyFalse(state.HasConverterArgs)
        end

        function reportsNoEditableArgumentsForABareConverter(testCase, ListBackend)
            % ClassMatch declares no default arguments and the item sets
            % none, so the argument editor has nothing to open on.
            item = speedItem();
            item.ConverterName = "ClassMatch";
            app = testCase.createApp(configurationWith(item), ListBackend);

            state = app.panelState();

            testCase.verifyFalse(state.HasEditableArgs)
            testCase.verifyFalse(state.IsNeuroconv)
        end

        function countsItemArgumentsAsEditable(testCase, ListBackend)
            item = speedItem();
            item.ConverterName = "ClassMatch";
            app = testCase.createApp(configurationWith(item), ListBackend);

            app.setConverterArgs(struct("Gain", 2))

            state = app.panelState();
            testCase.verifyTrue(state.HasEditableArgs)
            testCase.verifyTrue(state.HasConverterArgs)
        end
    end

    methods (Test) % Edits made in the list

        function aListEditSetsTheConverterByLabel(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            app.applyListEdit("speed", "Converter", "Class match (built-in)")

            testCase.verifyEqual(app.Config.DataItems(1).ConverterName, "ClassMatch")
        end

        function aListEditRenamesTheOutput(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            app.applyListEdit("speed", "NWBName", "RunningSpeed")

            testCase.verifyEqual(app.Config.DataItems(1).NWBVariableName, "RunningSpeed")
            testCase.verifyEqual(app.listTable().NWBName, "RunningSpeed")
        end
    end

    methods (Test) % Saving

        function savesJsonThatLoadsBack(testCase, ListBackend)
            filePath = fullfile(testCase.temporaryFolder(), "configuration.json");
            app = testCase.createApp(configurationWith(speedItem()), ListBackend, FilePath=filePath);
            app.setConverter("ClassMatch")

            app.saveConfiguration()

            restored = nansen.module.nwb.config.loadConfiguration(filePath);
            testCase.verifyEqual(restored.DataItems(1).ConverterName, "ClassMatch")
            testCase.verifyEqual(restored.DataItems(1).SourceInfo.Format, "fakefmt")
        end

        function savesAPilotMatConfigurationAsJsonBesideIt(testCase, ListBackend)
            % The app only ever writes JSON; a .mat path says where the
            % pilot file was, and the JSON goes next to it.
            folder = testCase.temporaryFolder();
            app = testCase.createApp(configurationWith(speedItem()), ListBackend, ...
                FilePath=fullfile(folder, "nwb_conversion_configuration.mat"));

            app.saveConfiguration()

            expectedPath = string(fullfile(folder, "nwb_conversion_configuration.json"));
            testCase.verifyEqual(app.FilePath, expectedPath)
            testCase.verifyTrue(isfile(expectedPath))
        end

        function tracksWhetherThereIsSomethingToSave(testCase, ListBackend)
            filePath = fullfile(testCase.temporaryFolder(), "configuration.json");
            app = testCase.createApp(configurationWith(speedItem()), ListBackend, FilePath=filePath);
            testCase.verifyFalse(app.IsDirty)

            app.addVariable("frames")
            testCase.verifyTrue(app.IsDirty)

            app.saveConfiguration()
            testCase.verifyFalse(app.IsDirty)
        end

        function countsAPilotConfigurationAsUnsaved(testCase, ListBackend)
            % Until it is saved, the runner keeps converting the .mat
            % file on every export, and closing must offer to save it.
            folder = testCase.temporaryFolder();
            app = testCase.createApp(configurationWith(speedItem()), ListBackend, ...
                FilePath=fullfile(folder, "nwb_conversion_configuration.mat"));

            testCase.verifyTrue(app.IsDirty)

            app.saveConfiguration()
            testCase.verifyFalse(app.IsDirty)
        end

        function refusesToSaveAPilotConfigurationOverItsJson(testCase, ListBackend)
            % The JSON beside a pilot .mat may hold later edits.
            folder = testCase.temporaryFolder();
            jsonPath = fullfile(folder, "nwb_conversion_configuration.json");
            writelines("{""existing"": true}", jsonPath)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend, ...
                FilePath=fullfile(folder, "nwb_conversion_configuration.mat"));

            testCase.verifyError(@() app.saveConfiguration(), ...
                "nansen:nwb:configurationExists")
            testCase.verifyEqual(strtrim(string(fileread(jsonPath))), "{""existing"": true}")
        end

        function rejectsSavingWithoutAFilePath(testCase, ListBackend)
            app = testCase.createApp(configurationWith(speedItem()), ListBackend);

            testCase.verifyError(@() app.saveConfiguration(), "nansen:nwb:missingFilePath")
        end
    end

    methods (Access = private)

        function app = createApp(testCase, config, listBackend, options)
            arguments
                testCase
                config
                listBackend
                options.FilePath (1,1) string = ""
            end

            app = nansen.module.nwb.gui.NWBConfiguratorApp(config, ...
                FilePath=options.FilePath, ...
                Registry=testRegistry(), ...
                VariableNames=["speed", "pupil", "frames"], ...
                ListBackend=listBackend, ...
                Visible="off", ...
                PythonCheckFcn=@() deal(false, struct("Message", "No Python here.")));
            testCase.addTeardown(@() delete(app))
        end

        function folder = temporaryFolder(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            folder = fixture.Folder;
        end
    end
end

function config = configurationWith(items)
%configurationWith - A configuration holding the given items

    config = nansen.module.nwb.config.NWBFileConfiguration(DataItems=items);
end

function item = speedItem()
%speedItem - An item whose source names a format and a class

    sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
    sourceInfo.Format = "fakefmt";
    sourceInfo.MatlabClass = "timetable";
    item = nansen.module.nwb.config.NWBDataItemConfig( ...
        VariableName="speed", NWBVariableName="speed", SourceInfo=sourceInfo);
end

function item = framesItem()
%framesItem - An item whose source names only a class ProcessingOne accepts

    sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
    sourceInfo.MatlabClass = "nothing.Matches";
    item = nansen.module.nwb.config.NWBDataItemConfig( ...
        VariableName="frames", NWBVariableName="frames", SourceInfo=sourceInfo);
end

function item = pupilItem()
%pupilItem - An item whose source names only a class two converters accept

    sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
    sourceInfo.MatlabClass = "timetable";
    item = nansen.module.nwb.config.NWBDataItemConfig( ...
        VariableName="pupil", NWBVariableName="pupil", SourceInfo=sourceInfo);
end

function item = tracesItem()
%tracesItem - An item whose source names the format only PythonOne accepts

    sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
    sourceInfo.Format = "pyfmt";
    item = nansen.module.nwb.config.NWBDataItemConfig( ...
        VariableName="traces", NWBVariableName="traces", SourceInfo=sourceInfo);
end

function registry = testRegistry()
%testRegistry - Fake converters covering the cases the app distinguishes

    import nansen.module.nwb.conversion.NWBConverterDescriptor

    registry = nansen.module.nwb.conversion.ConverterRegistry(IncludeBuiltin=false);
    mutate = @(context) context.NwbFile;

    registry.add(NWBConverterDescriptor(Name="FormatMatch", DisplayName="Format match", ...
        Description="Matches the recorded format.", AcceptedFormats="fakefmt", ...
        ProducesNWBType="TimeSeries", Function=mutate))
    registry.add(NWBConverterDescriptor(Name="ClassMatch", DisplayName="Class match", ...
        Description="Matches the MATLAB class.", AcceptedClasses="timetable", ...
        ProducesNWBType="TimeSeries", Function=mutate))
    registry.add(NWBConverterDescriptor(Name="OtherClassMatch", DisplayName="Other class match", ...
        AcceptedClasses="timetable", ProducesNWBType="TimeIntervals", ...
        PrimaryGroup="Intervals", Function=mutate))
    registry.add(NWBConverterDescriptor(Name="ProcessingOne", DisplayName="Processing converter", ...
        AcceptedClasses="nothing.Matches", ProducesNWBType="Images", PrimaryGroup="Processing", ...
        NWBModuleTags="ophys", PlacementPolicy="converter", Function=mutate))
    registry.add(NWBConverterDescriptor(Name="GenericNeurodataType", DisplayName="Generic", ...
        AcceptedClasses="*", ProducesNWBType="*", NWBModuleTags="*", Function=mutate))
    % Accepts a class no item records, so it is only reached by name and
    % does not change which converters the other items match.
    registry.add(NWBConverterDescriptor(Name="HintedOne", DisplayName="Hinted converter", ...
        AcceptedClasses="hinted.Class", ProducesNWBType="TimeSeries", ...
        DefaultConverterArgs=struct("ClampMode", ""), ...
        ConverterArgHints=struct("ClampMode", ...
            "Set ClampMode to the mode the session was recorded in."), ...
        Function=mutate))
    registry.add(NWBConverterDescriptor(Name="PythonOne", DisplayName="Python converter", ...
        Source="neuroconv", AcceptedFormats="pyfmt", ProducesNWBType="TimeSeries", ...
        ExecutionMode="external", PlacementPolicy="converter", RequiresPython=true, ...
        NeedsData=false, Function=@(context) struct("DidWriteFile", true)))
end

function folderPath = repositoryRoot()
%repositoryRoot - Path of the repository holding this test

    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
