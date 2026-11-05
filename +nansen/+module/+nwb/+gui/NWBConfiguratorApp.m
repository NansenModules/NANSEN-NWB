classdef NWBConfiguratorApp < handle
%NWBConfiguratorApp - Configure how a project's data variables convert to NWB
%   APP = NWBConfiguratorApp(CONFIG) opens the configurator on CONFIG, an
%   NWBFileConfiguration or a struct in its shape. The list on the left
%   holds one row per data item; the panel on the right edits the
%   selected item: which converter runs, where its output goes in the
%   file, and the metadata and arguments the converter takes.
%
%   APP = NWBConfiguratorApp(...,Name=VALUE) also specifies:
%       FilePath       - File the configuration is saved to. A ".mat"
%                        path names a pilot configuration that was
%                        converted on opening; saving writes ".json"
%                        beside it and keeps the ".mat" untouched.
%       Registry       - Converter registry to offer. The shared one by
%                        default.
%       VariableNames  - Data variables of the project, offered when an
%                        item is added. The current project's by default.
%       ListBackend    - "html" (default) or "uitable": the entity-table
%                        backend drawing the list.
%       Visible        - "on" (default) or "off".
%       PythonCheckFcn - Function with the outputs of hasNeuroconv, called
%                        once when a NeuroConv converter is first shown.
%                        hasNeuroconv by default.
%
%   The converters come from the registry, so a converter a lab registers
%   with registerConverterFolder appears without the app being changed.
%   What the app says a conversion would do with an item is what the
%   runner does: both ask ConverterRegistry.resolveForItem.
%
%   NWBConfiguratorApp functions:
%       addVariable       - Add a data item for a variable
%       removeVariable    - Remove the data item of a variable
%       selectVariable    - Select the item the panel edits
%       setConverter      - Choose the selected item's converter
%       setNWBName        - Name the selected item's output in the file
%       setTargetType     - Set the module and type the generic converter builds
%       setPlacement      - Set the selected item's group and module
%       setMetadata       - Replace the selected item's metadata
%       setConverterArgs  - Replace the selected item's converter arguments
%       applyListEdit     - Take an edit made in the list into the item
%       saveConfiguration - Write the configuration as JSON
%       panelState        - What the panel shows for the selected item
%       converterChoices  - The converters offered for the selected item
%       listTable         - The rows the list shows
%
%   NWBConfiguratorApp properties:
%       Config           - The configuration being edited
%       FilePath         - Where saveConfiguration writes
%       SelectedVariable - The variable whose item the panel shows
%       IsDirty          - Whether Config differs from what was last saved
%
%   See also nansen.module.nwb.config.NWBFileConfiguration,
%   nansen.module.nwb.conversion.ConverterRegistry,
%   nansen.module.nwb.mixin.tool.nwb.configureNwbFile

    properties (Constant, Access = private)
        AUTO_LABEL = "Auto (let the runner decide)"
        UNREGISTERED_SUFFIX = " (not registered)"
        GENERIC_CONVERTER = "GenericNeurodataType"
        NO_MODULE_LABEL = "(none)"
        FIGURE_SIZE = [1180, 660]
        CONTROL_HEIGHT = 22                 % Height of a MATLAB button or dropdown
        LIST_COLUMN_WIDTHS = [150, 150, 240, 140, 150, 120] % Preferred widths of the list's columns
        MIN_LIST_COLUMN_WIDTH = 70          % Below this a column is not narrowed further
        LIST_SCROLLBAR_ALLOWANCE = 16       % Width kept free for the list's vertical scrollbar
        UITABLE_ROW_NUMBER_WIDTH = 42       % Width of the row numbers a uitable shows
    end

    properties (SetAccess = private)
        Config (1,1) nansen.module.nwb.config.NWBFileConfiguration % The configuration being edited
        FilePath (1,1) string = ""          % Where saveConfiguration writes
        SelectedVariable (1,1) string = ""  % The variable whose item the panel shows
    end

    properties (Dependent, SetAccess = private)
        IsDirty logical                     % Whether Config differs from what was last saved
    end

    properties (Access = private)
        Registry (1,1) nansen.module.nwb.conversion.ConverterRegistry
        VariableNames (1,:) string = strings(1, 0)
        ListBackend (1,1) string = "html"
        PythonCheckFcn
        PythonReport = []                   % Result of PythonCheckFcn once asked
        SavedState (1,1) string = ""        % Config as JSON when last saved
        LabelToName dictionary = dictionary(string.empty, string.empty)

        Figure matlab.ui.Figure = matlab.ui.Figure.empty
        VariableDropdown
        ListHost
        List
        FittedColumnWidths (1,:) double = []  % Column widths last given to the list
        ConverterDropdown
        DescriptionLabel
        PythonLabel
        ModuleRow
        ModuleDropdown
        TypeRow
        TypeDropdown
        GroupDropdown
        PlacementModuleRow
        PlacementModuleDropdown
        NameField
        MetadataLabel
        MetadataButton
        ArgsLabel
        ArgsButton
        StatusLabel
        PanelControls
    end

    methods
        function obj = NWBConfiguratorApp(config, options)
            arguments
                config
                options.FilePath (1,1) string = ""
                options.Registry = []
                options.VariableNames string = string.empty
                options.ListBackend (1,1) string ...
                    {mustBeMember(options.ListBackend, ["html", "uitable"])} = "html"
                options.Visible (1,1) matlab.lang.OnOffSwitchState = "on"
                options.PythonCheckFcn = @() nansen.module.nwb.neuroconv.hasNeuroconv()
            end

            obj.Config = nansen.module.nwb.config.NWBFileConfiguration.fromAny(config);
            obj.FilePath = options.FilePath;
            obj.ListBackend = options.ListBackend;
            obj.PythonCheckFcn = options.PythonCheckFcn;

            if isempty(options.Registry)
                obj.Registry = nansen.module.nwb.conversion.ConverterRegistry.instance();
            else
                obj.Registry = options.Registry;
            end

            if isempty(options.VariableNames)
                obj.VariableNames = defaultVariableNames();
            else
                obj.VariableNames = reshape(options.VariableNames, 1, []);
            end
            % A configured variable the project no longer defines stays
            % editable; it is reported when the conversion runs.
            configuredNames = obj.configuredVariables();
            obj.VariableNames = unique([obj.VariableNames, configuredNames], "stable");

            obj.buildLabelMap()

            % A pilot .mat configuration has not been saved in the JSON
            % form the runner reads, so it starts out with something to
            % save, and closing asks whether to.
            [~, ~, extension] = fileparts(obj.FilePath);
            if lower(string(extension)) == ".mat"
                obj.SavedState = "";
            else
                obj.SavedState = obj.currentState();
            end

            obj.createComponents(options.Visible)

            if ~isempty(configuredNames)
                obj.selectVariable(configuredNames(1))
            else
                obj.fillPanel()
            end

            if ~nargout
                clear obj
            end
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure)
            end
        end

        function tf = get.IsDirty(obj)
            tf = obj.currentState() ~= obj.SavedState;
        end

        function addVariable(obj, variableName)
            %addVariable - Add a data item for a variable
            %   addVariable(APP,variableName) appends an item for the
            %   variable, named after it in the file, with the source
            %   evidence the project's variable model records, and
            %   selects it.
            %
            %   Errors:
            %     nansen:nwb:variableAlreadyConfigured - the variable has
            %                     an item already.

            arguments
                obj
                variableName (1,1) string
            end

            variableName = strtrim(variableName);
            if strlength(variableName) == 0
                return
            end

            if any(obj.configuredVariables() == variableName)
                error("nansen:nwb:variableAlreadyConfigured", ...
                    ['''%s'' is already in the configuration. Select its row ', ...
                     'to edit it.'], variableName)
            end

            item = nansen.module.nwb.config.NWBDataItemConfig( ...
                VariableName=variableName, ...
                NWBVariableName=variableName, ...
                SourceInfo=sourceInfoFor(variableName));

            obj.Config.DataItems(end+1, 1) = item;
            obj.refreshList()
            obj.selectVariable(variableName)
        end

        function removeVariable(obj, variableName)
            %removeVariable - Remove the data item of a variable

            arguments
                obj
                variableName (1,1) string
            end

            isItem = obj.configuredVariables() == variableName;
            if ~any(isItem)
                return
            end

            obj.Config.DataItems(isItem) = [];
            if obj.SelectedVariable == variableName
                obj.SelectedVariable = "";
            end
            obj.refreshList()
            obj.fillPanel()
        end

        function selectVariable(obj, variableName)
            %selectVariable - Select the item the panel edits

            arguments
                obj
                variableName (1,1) string
            end

            if ~any(obj.configuredVariables() == variableName)
                error("nansen:nwb:unknownVariable", ...
                    "''%s'' is not in the configuration.", variableName)
            end

            obj.SelectedVariable = variableName;
            if ~isempty(obj.List)
                obj.List.setSelectedRowKeys(variableName)
            end
            obj.fillPanel()
        end

        function setConverter(obj, converterName)
            %setConverter - Choose the selected item's converter
            %   setConverter(APP,converterName) sets the registry key of
            %   the converter for the selected item. An empty name leaves
            %   the choice to the runner, which takes the single best
            %   match for the variable's source evidence.
            %
            %   Choosing a converter also takes its default placement: the
            %   group it declares, and the first module it is tagged for
            %   when that group is Processing and the item names none.

            arguments
                obj
                converterName (1,1) string
            end

            item = obj.selectedItem();
            item.ConverterName = strtrim(converterName);

            if strlength(item.ConverterName) > 0
                descriptor = obj.Registry.get(item.ConverterName);
                item.PrimaryGroup = descriptor.PrimaryGroup;
                if descriptor.PrimaryGroup == "Processing" && isUnsetText(item.NWBModule)
                    tags = descriptor.NWBModuleTags(descriptor.NWBModuleTags ~= "*");
                    if ~isempty(tags)
                        item.NWBModule = tags(1);
                    end
                end
            end

            obj.updateSelectedItem(item)
        end

        function setNWBName(obj, nwbName)
            %setNWBName - Name the selected item's output in the file

            arguments
                obj
                nwbName (1,1) string
            end

            item = obj.selectedItem();
            item.NWBVariableName = strtrim(nwbName);
            obj.updateSelectedItem(item)
        end

        function setTargetType(obj, moduleName, typeName)
            %setTargetType - Set the module and type the generic converter builds
            %   setTargetType(APP,moduleName,typeName) sets NWBModule and
            %   TargetNWBType on the selected item. These only matter for
            %   the generic converter, which builds the named type.

            arguments
                obj
                moduleName (1,1) string
                typeName (1,1) string = ""
            end

            item = obj.selectedItem();
            item.NWBModule = strtrim(moduleName);
            item.TargetNWBType = strtrim(typeName);
            obj.updateSelectedItem(item)
        end

        function setPlacement(obj, primaryGroup, moduleName)
            %setPlacement - Set the selected item's group and module

            arguments
                obj
                primaryGroup (1,1) string
                moduleName (1,1) string = ""
            end

            item = obj.selectedItem();
            item.PrimaryGroup = primaryGroup;
            item.NWBModule = strtrim(moduleName);
            obj.updateSelectedItem(item)
        end

        function setMetadata(obj, metadata)
            %setMetadata - Replace the selected item's metadata

            arguments
                obj
                metadata (1,1) struct
            end

            item = obj.selectedItem();
            item.Metadata = metadata;
            obj.updateSelectedItem(item)
        end

        function setConverterArgs(obj, converterArgs)
            %setConverterArgs - Replace the selected item's converter arguments

            arguments
                obj
                converterArgs (1,1) struct
            end

            item = obj.selectedItem();
            item.ConverterArgs = converterArgs;
            obj.updateSelectedItem(item)
        end

        function applyListEdit(obj, variableName, columnName, value)
            %applyListEdit - Take an edit made in the list into the item
            %   applyListEdit(APP,variableName,columnName,VALUE) applies
            %   what was typed or chosen in the list: a new NWB name, or a
            %   converter picked by its label. Other columns are not
            %   editable there.

            arguments
                obj
                variableName (1,1) string
                columnName (1,1) string
                value
            end

            obj.selectVariable(variableName)

            switch columnName
                case "NWBName"
                    obj.setNWBName(string(value))
                case "Converter"
                    obj.setConverter(obj.nameForLabel(string(value)))
                otherwise
                    % The other columns are read-only in the list.
            end
        end

        function saveConfiguration(obj)
            %saveConfiguration - Write the configuration as JSON
            %
            %   Errors:
            %     nansen:nwb:missingFilePath - the app was opened without a
            %                     file to save to.

            if strlength(obj.FilePath) == 0
                error("nansen:nwb:missingFilePath", ...
                    ['The configurator was opened without a file to save ', ...
                     'to. Open it with FilePath set.'])
            end

            % A pilot .mat configuration is read once and from then on
            % kept as JSON beside it.
            [folder, name, extension] = fileparts(obj.FilePath);
            if lower(string(extension)) == ".mat"
                obj.FilePath = string(fullfile(folder, name + ".json"));
            end

            nansen.module.nwb.config.saveConfiguration(obj.Config, obj.FilePath)
            obj.SavedState = obj.currentState();
        end

        function state = panelState(obj)
            %panelState - What the panel shows for the selected item
            %   STATE = panelState(APP) returns a struct with the fields
            %   the panel is drawn from: Variable, ConverterName,
            %   ConverterLabel, Description, IsGeneric, NWBModule,
            %   TargetNWBType, PrimaryGroup, PlacementOwnedByConverter,
            %   NWBName, HasMetadata, HasConverterArgs, Status, Message
            %   and NeedsPython. With nothing selected, Variable is "".

            state = struct( ...
                "Variable", "", "ConverterName", "", "ConverterLabel", obj.AUTO_LABEL, ...
                "Description", "", "IsGeneric", false, "NWBModule", "", ...
                "TargetNWBType", "", "PrimaryGroup", "", ...
                "PlacementOwnedByConverter", false, "NWBName", "", ...
                "HasMetadata", false, "HasConverterArgs", false, ...
                "Status", "", "Message", "", "NeedsPython", false);

            if strlength(obj.SelectedVariable) == 0
                return
            end

            item = obj.selectedItem();
            resolution = obj.describeResolution(item);

            state.Variable = item.VariableName;
            state.ConverterName = item.ConverterName;
            state.NWBModule = item.NWBModule;
            state.TargetNWBType = item.TargetNWBType;
            [state.PrimaryGroup, state.NWBModule] = ...
                obj.effectivePlacement(item, resolution.Descriptor);
            state.NWBName = item.NWBVariableName;
            state.HasMetadata = ~isempty(fieldnames(item.Metadata));
            state.HasConverterArgs = ~isempty(fieldnames(item.ConverterArgs));
            state.Status = resolution.Status;
            state.Message = resolution.Message;
            state.NeedsPython = resolution.Status == "needs Python";

            if strlength(item.ConverterName) > 0
                state.ConverterLabel = obj.labelForName(item.ConverterName);
                % An unregistered converter leaves the description empty;
                % the status says the converter is unknown.
                if obj.isRegistered(item.ConverterName)
                    descriptor = obj.Registry.get(item.ConverterName);
                    state.Description = descriptor.Description;
                    state.IsGeneric = descriptor.Name == obj.GENERIC_CONVERTER;
                    state.PlacementOwnedByConverter = ownsPlacement(descriptor);
                end
            elseif ~isempty(resolution.Descriptor)
                state.Description = "Resolved to " + resolution.Descriptor.DisplayName ...
                    + ": " + resolution.Descriptor.Description;
                state.IsGeneric = resolution.Descriptor.Name == obj.GENERIC_CONVERTER;
                state.PlacementOwnedByConverter = ownsPlacement(resolution.Descriptor);
            end
        end

        function choices = converterChoices(obj)
            %converterChoices - The converters offered for the selected item
            %   CHOICES = converterChoices(APP) returns a struct array with
            %   fields Label, Name and IsSuggested, in the order the
            %   dropdown lists them: the converters matching the
            %   variable's source evidence first, best match first, then
            %   every other converter. The first entry leaves the choice
            %   to the runner. A converter the item names that is not
            %   registered follows it, so the dropdown can show the
            %   item's current value.

            choices = struct("Label", obj.AUTO_LABEL, "Name", "", "IsSuggested", false);

            suggested = nansen.module.nwb.conversion.NWBConverterDescriptor.empty(0, 1);
            if strlength(obj.SelectedVariable) > 0
                item = obj.selectedItem();
                [matches, ranks] = obj.Registry.findForSourceInfo(item.SourceInfo);
                suggested = matches(ranks > 1);

                if strlength(item.ConverterName) > 0 && ~obj.isRegistered(item.ConverterName)
                    choices(end+1) = struct("Label", obj.labelForName(item.ConverterName), ...
                        "Name", item.ConverterName, "IsSuggested", false);
                end
            end

            for i = 1:numel(suggested)
                choices(end+1) = struct("Label", obj.labelFor(suggested(i)) + " (suggested)", ...
                    "Name", suggested(i).Name, "IsSuggested", true); %#ok<AGROW>
            end

            others = obj.Registry.list();
            if ~isempty(suggested)
                others = others(~ismember([others.Name], [suggested.Name]));
            end
            [~, order] = sort(lower([others.DisplayName]));
            others = others(order);
            for i = 1:numel(others)
                choices(end+1) = struct("Label", obj.labelFor(others(i)), ...
                    "Name", others(i).Name, "IsSuggested", false); %#ok<AGROW>
            end
        end

        function rows = listTable(obj)
            %listTable - The rows the list shows
            %   ROWS = listTable(APP) returns a table with one row per data
            %   item and the variables Variable, NWBName, Converter,
            %   Produces, Placement and Status.

            items = obj.Config.DataItems;
            numItems = numel(items);
            [Variable, NWBName, Converter, Produces, Placement, Status] = ...
                deal(strings(numItems, 1));

            for i = 1:numItems
                item = items(i);
                resolution = obj.describeResolution(item);

                Variable(i) = item.VariableName;
                NWBName(i) = item.NWBVariableName;
                if strlength(item.ConverterName) > 0
                    Converter(i) = obj.labelForName(item.ConverterName);
                else
                    Converter(i) = obj.AUTO_LABEL;
                end
                if ~isempty(resolution.Descriptor)
                    Produces(i) = resolution.Descriptor.ProducesNWBType;
                    if Produces(i) == "*"
                        Produces(i) = item.TargetNWBType;
                    end
                end
                [primaryGroup, moduleName] = obj.effectivePlacement(item, resolution.Descriptor);
                Placement(i) = primaryGroup;
                if primaryGroup == "Processing" && strlength(moduleName) > 0
                    Placement(i) = Placement(i) + "/" + moduleName;
                end
                Status(i) = resolution.Status;
            end

            rows = table(Variable, NWBName, Converter, Produces, Placement, Status);
        end
    end

    methods (Access = private)

        function createComponents(obj, visibleState)
            obj.Figure = uifigure( ...
                "Name", "NWB Configurator", ...
                "Position", [100, 100, obj.FIGURE_SIZE], ...
                "Visible", visibleState);
            obj.Figure.CloseRequestFcn = @(~, ~) obj.onCloseRequested();

            root = uigridlayout(obj.Figure, [3, 2]);
            root.RowHeight = {obj.CONTROL_HEIGHT, "1x", 44};
            root.ColumnWidth = {"2x", 400};
            root.Padding = [16, 12, 16, 12];
            root.ColumnSpacing = 16;

            obj.createAddControls(root)
            obj.createList(root)
            obj.createPanel(root)
            obj.createSaveControls(root)
        end

        function createAddControls(obj, root)
            grid = uigridlayout(root, [1, 4]);
            grid.Layout.Row = 1;
            grid.Layout.Column = 1;
            grid.ColumnWidth = {"1x", 70, 100, 90};
            grid.Padding = [0, 0, 0, 0];
            grid.ColumnSpacing = 8;

            obj.VariableDropdown = uidropdown(grid, ...
                "Items", cellstr(obj.unconfiguredVariables()), ...
                "Editable", "on", ...
                "Tooltip", "Choose or type a data variable to add");

            uibutton(grid, "Text", "Add", ...
                "ButtonPushedFcn", @(~, ~) obj.runUiAction(@() obj.addVariable(string(obj.VariableDropdown.Value))));
            uibutton(grid, "Text", "Add many...", ...
                "ButtonPushedFcn", @(~, ~) obj.runUiAction(@() obj.addManyVariables()));
            uibutton(grid, "Text", "Remove", ...
                "ButtonPushedFcn", @(~, ~) obj.runUiAction(@() obj.removeVariable(obj.SelectedVariable)));
        end

        function createList(obj, root)
            % A panel hosts the list because both entity-table backends
            % position their component in pixels inside the parent; in a
            % grid cell that only warns. The host resizes the HTML view.
            % Its border separates the list from the panel beside it.
            obj.ListHost = uipanel(root, "BorderType", "line", "AutoResizeChildren", "off");
            obj.ListHost.Layout.Row = 2;
            obj.ListHost.Layout.Column = 1;

            obj.List = entitytable.EntityTableView(obj.ListHost, obj.listTable(), ...
                RowKey="Variable", ...
                ColumnSpecs=obj.listColumnSpecs(), ...
                SelectionMode="single", ...
                Backend=obj.ListBackend);

            addlistener(obj.List, "SelectionChanged", @(~, evt) obj.onListSelectionChanged(evt));
            addlistener(obj.List, "CellEdited", @(~, evt) obj.onListCellEdited(evt));

            obj.ListHost.SizeChangedFcn = @(~, ~) obj.fitListToHost();
            obj.fitListToHost()
        end

        function fitListToHost(obj)
            % The uitable backend is normalized and follows its parent;
            % the HTML view holds a pixel position and is resized here.
            if isempty(obj.List)
                return
            end
            hostSize = obj.ListHost.InnerPosition(3:4);
            if obj.ListBackend == "html"
                component = obj.List.getComponent();
                component.Position = [1, 1, max(1, hostSize(1)), max(1, hostSize(2))];
            end
            obj.fitColumnsToWidth(hostSize(1))
        end

        function fitColumnsToWidth(obj, availableWidth)
            % Both backends give each column a fixed width in pixels, and
            % macOS hides a scrollbar until the list is scrolled, so a list
            % wider than its panel looks cut off. The columns share the
            % width in proportion to their preferred widths, and the list
            % scrolls sideways only once they reach their minimum.
            usableWidth = availableWidth - obj.LIST_SCROLLBAR_ALLOWANCE;
            if obj.ListBackend == "uitable"
                usableWidth = usableWidth - obj.UITABLE_ROW_NUMBER_WIDTH;
            end
            widths = floor(obj.LIST_COLUMN_WIDTHS / sum(obj.LIST_COLUMN_WIDTHS) * usableWidth);
            widths = max(widths, obj.MIN_LIST_COLUMN_WIDTH);

            % Setting the widths redraws the list, so it is skipped when
            % they have not changed.
            if isequal(widths, obj.FittedColumnWidths)
                return
            end
            obj.FittedColumnWidths = widths;
            obj.List.setColumnWidths(num2cell(widths))
        end

        function specs = listColumnSpecs(obj)
            import entitytable.ColumnSpec
            widths = obj.LIST_COLUMN_WIDTHS;
            specs = [ ...
                ColumnSpec("Variable", DisplayName="Variable", Width=widths(1)), ...
                ColumnSpec("NWBName", DisplayName="NWB name", IsEditable=true, Width=widths(2)), ...
                ColumnSpec("Converter", DisplayName="Converter", IsEditable=true, ...
                    Options=obj.converterLabels(), Width=widths(3)), ...
                ColumnSpec("Produces", DisplayName="Produces", Width=widths(4)), ...
                ColumnSpec("Placement", DisplayName="Placement", Width=widths(5)), ...
                ColumnSpec("Status", DisplayName="Status", Width=widths(6), ...
                    UserData=struct("Renderer", "badge"))];
        end

        function createPanel(obj, root)
            % The border separates the panel from the list beside it.
            container = uipanel(root, "BorderType", "line");
            container.Layout.Row = [1, 2];
            container.Layout.Column = 2;

            panel = uigridlayout(container, [14, 2]);
            panel.ColumnWidth = {110, "1x"};
            panel.RowHeight = {28, 24, 48, 36, 24, 24, 24, 24, 24, 24, 24, 8, "1x", 0};
            panel.Padding = [12, 8, 12, 8];
            panel.RowSpacing = 6;

            title = uilabel(panel, "Text", "Selected item", "FontWeight", "bold", "FontSize", 14);
            title.Layout.Row = 1;
            title.Layout.Column = [1, 2];

            obj.ConverterDropdown = obj.addRow(panel, 2, "Converter", @uidropdown);
            obj.ConverterDropdown.ValueChangedFcn = ...
                @(src, ~) obj.runUiAction(@() obj.setConverter(string(src.Value)));

            obj.DescriptionLabel = uilabel(panel, "Text", "", "WordWrap", "on", "FontSize", 11);
            obj.DescriptionLabel.Layout.Row = 3;
            obj.DescriptionLabel.Layout.Column = [1, 2];

            obj.PythonLabel = uilabel(panel, "Text", "", "WordWrap", "on", ...
                "FontSize", 11, "FontColor", [0.7, 0.3, 0], "Visible", "off");
            obj.PythonLabel.Layout.Row = 4;
            obj.PythonLabel.Layout.Column = [1, 2];

            [obj.ModuleDropdown, obj.ModuleRow] = obj.addRow(panel, 5, "NWB module", @uidropdown);
            obj.ModuleDropdown.ValueChangedFcn = ...
                @(src, ~) obj.runUiAction(@() obj.setTargetType(obj.dropdownValue(src), ""));

            [obj.TypeDropdown, obj.TypeRow] = obj.addRow(panel, 6, "Target type", @uidropdown);
            obj.TypeDropdown.ValueChangedFcn = ...
                @(src, ~) obj.runUiAction(@() obj.setTargetType(obj.selectedItem().NWBModule, obj.dropdownValue(src)));

            obj.GroupDropdown = obj.addRow(panel, 7, "Group", @uidropdown);
            obj.GroupDropdown.Items = cellstr( ...
                nansen.module.nwb.conversion.NWBConverterDescriptor.VALID_PRIMARY_GROUPS);
            obj.GroupDropdown.ValueChangedFcn = ...
                @(src, ~) obj.runUiAction(@() obj.setPlacement(string(src.Value), obj.selectedItem().NWBModule));

            [obj.PlacementModuleDropdown, obj.PlacementModuleRow] = obj.addRow(panel, 8, "Module", @uidropdown);
            obj.PlacementModuleDropdown.ValueChangedFcn = ...
                @(src, ~) obj.runUiAction(@() obj.setPlacement(obj.selectedItem().PrimaryGroup, obj.dropdownValue(src)));

            obj.NameField = obj.addRow(panel, 9, "NWB name", @uieditfield);
            obj.NameField.ValueChangedFcn = ...
                @(src, ~) obj.runUiAction(@() obj.setNWBName(string(src.Value)));

            [obj.MetadataButton, metadataRow] = obj.addRow(panel, 10, "Metadata", @uibutton);
            obj.MetadataButton.Text = "Edit...";
            obj.MetadataButton.ButtonPushedFcn = @(~, ~) obj.runUiAction(@() obj.editMetadata());
            obj.MetadataLabel = metadataRow;

            [obj.ArgsButton, argsRow] = obj.addRow(panel, 11, "Arguments", @uibutton);
            obj.ArgsButton.Text = "Edit...";
            obj.ArgsButton.ButtonPushedFcn = @(~, ~) obj.runUiAction(@() obj.editConverterArgs());
            obj.ArgsLabel = argsRow;

            obj.StatusLabel = uilabel(panel, "Text", "", "WordWrap", "on", "VerticalAlignment", "top");
            obj.StatusLabel.Layout.Row = 13;
            obj.StatusLabel.Layout.Column = [1, 2];

            obj.PanelControls = [obj.ConverterDropdown, obj.GroupDropdown, obj.NameField, ...
                obj.MetadataButton, obj.ArgsButton];
        end

        function [control, label] = addRow(~, panel, row, labelText, createFcn)
            label = uilabel(panel, "Text", labelText);
            label.Layout.Row = row;
            label.Layout.Column = 1;
            control = createFcn(panel);
            control.Layout.Row = row;
            control.Layout.Column = 2;
        end

        function createSaveControls(obj, root)
            grid = uigridlayout(root, [1, 4]);
            grid.Layout.Row = 3;
            grid.Layout.Column = [1, 2];
            grid.ColumnWidth = {"1x", 160, 160, "1x"};
            grid.Padding = [0, 6, 0, 0];

            saveButton = uibutton(grid, "Text", "Save", ...
                "ButtonPushedFcn", @(~, ~) obj.runUiAction(@() obj.saveAndNotify(false)));
            saveButton.Layout.Column = 2;
            closeButton = uibutton(grid, "Text", "Save & Close", ...
                "ButtonPushedFcn", @(~, ~) obj.runUiAction(@() obj.saveAndNotify(true)));
            closeButton.Layout.Column = 3;
        end

        function fillPanel(obj)
            state = obj.panelState();
            hasSelection = strlength(state.Variable) > 0;

            set(obj.PanelControls, "Enable", matlab.lang.OnOffSwitchState(hasSelection));

            if ~hasSelection
                obj.ConverterDropdown.Items = cellstr(obj.AUTO_LABEL);
                obj.ConverterDropdown.ItemsData = {''};
                obj.DescriptionLabel.Text = "";
                obj.PythonLabel.Visible = "off";
                obj.showRow([obj.ModuleRow, obj.ModuleDropdown, obj.TypeRow, obj.TypeDropdown, ...
                    obj.PlacementModuleRow, obj.PlacementModuleDropdown], false)
                obj.GroupDropdown.Value = obj.GroupDropdown.Items{1};
                obj.NameField.Value = '';
                obj.MetadataLabel.Text = "Metadata";
                obj.ArgsLabel.Text = "Arguments";
                obj.StatusLabel.Text = "Select an item, or add a data variable above.";
                return
            end

            choices = obj.converterChoices();
            obj.ConverterDropdown.Items = cellstr([choices.Label]);
            obj.ConverterDropdown.ItemsData = cellstr([choices.Name]);
            obj.ConverterDropdown.Value = char(state.ConverterName);

            obj.DescriptionLabel.Text = state.Description;
            obj.PythonLabel.Visible = state.NeedsPython;
            if state.NeedsPython
                obj.PythonLabel.Text = state.Message;
            end

            obj.showRow([obj.ModuleRow, obj.ModuleDropdown, obj.TypeRow, obj.TypeDropdown], state.IsGeneric)
            if state.IsGeneric
                obj.fillModuleDropdown(obj.ModuleDropdown, state.NWBModule)
                obj.fillTypeDropdown(state.NWBModule, state.TargetNWBType)
            end

            obj.fillGroupDropdown(state.PrimaryGroup)
            obj.GroupDropdown.Enable = hasSelection && ~state.PlacementOwnedByConverter;
            isProcessing = state.PrimaryGroup == "Processing";
            obj.showRow([obj.PlacementModuleRow, obj.PlacementModuleDropdown], isProcessing)
            if isProcessing
                obj.fillModuleDropdown(obj.PlacementModuleDropdown, state.NWBModule)
                obj.PlacementModuleDropdown.Enable = ~state.PlacementOwnedByConverter;
            end

            obj.NameField.Value = char(state.NWBName);
            obj.MetadataLabel.Text = "Metadata: " + statusWord(state.HasMetadata);
            obj.ArgsLabel.Text = "Arguments: " + statusWord(state.HasConverterArgs);

            obj.StatusLabel.Text = upper(extractBefore(state.Status + " ", 2)) ...
                + extractAfter(state.Status + " ", 1) + newline + state.Message;
        end

        function fillGroupDropdown(obj, currentGroup)
            % A group that is not an NWB group, such as a lower-case one
            % from a pilot configuration, is shown so the item can be
            % opened and given a valid one; the status reports it.
            groupNames = nansen.module.nwb.conversion.NWBConverterDescriptor.VALID_PRIMARY_GROUPS;
            if strlength(currentGroup) > 0 && ~any(groupNames == currentGroup)
                groupNames = [currentGroup, groupNames];
            end
            obj.GroupDropdown.Items = cellstr(groupNames);
            if strlength(currentGroup) > 0
                obj.GroupDropdown.Value = char(currentGroup);
            end
        end

        function fillModuleDropdown(obj, dropdown, currentModule)
            moduleNames = string(nansen.module.nwb.internal.schemautil.getNWBModules());
            moduleNames = reshape(erase(moduleNames, "nwb."), 1, []);
            if strlength(currentModule) > 0 && ~any(moduleNames == currentModule)
                moduleNames = [currentModule, moduleNames];
            end
            dropdown.Items = cellstr([obj.NO_MODULE_LABEL, moduleNames]);
            dropdown.ItemsData = cellstr(["", moduleNames]);
            dropdown.Value = char(currentModule);
        end

        function fillTypeDropdown(obj, moduleName, currentType)
            typeNames = strings(1, 0);
            if strlength(moduleName) > 0
                typeNames = reshape(obj.configurableTypes(moduleName), 1, []);
            end
            if strlength(currentType) > 0 && ~any(typeNames == currentType)
                typeNames = [currentType, typeNames];
            end
            obj.TypeDropdown.Items = cellstr(["(select a type)", typeNames]);
            obj.TypeDropdown.ItemsData = cellstr(["", typeNames]);
            obj.TypeDropdown.Value = char(currentType);
        end

        function typeNames = configurableTypes(~, moduleName)
            % Metadata and abstract types are not neurodata a variable
            % converts to.
            typeNames = nansen.module.nwb.lookup.listNeurodataTypes(Module=moduleName);
            typeNames = setdiff(typeNames, ...
                nansen.module.nwb.internal.lookup.getMetadataClassNames());
            typeNames = setdiff(typeNames, ...
                nansen.module.nwb.internal.lookup.getAbstractClassNames());
        end

        function showRow(~, components, isShown)
            set(components, "Visible", matlab.lang.OnOffSwitchState(isShown))
        end

        function value = dropdownValue(~, dropdown)
            value = string(dropdown.Value);
        end

        function editMetadata(obj)
            % The metadata editor is seeded from the converter's schema
            % when it declares one, else from the produced type.
            state = obj.panelState();
            item = obj.selectedItem();
            resolution = obj.describeResolution(item);

            metadata = item.Metadata;
            if isempty(fieldnames(metadata))
                metadata = obj.metadataTemplate(resolution.Descriptor, state);
            end

            [edited, wasAborted] = tools.editStruct(metadata, 'all', 'Edit metadata', ...
                'Prompt', sprintf('Metadata written with %s', state.Variable));
            if wasAborted
                return
            end
            obj.setMetadata(utility.struct.removeConfigFields(edited))
        end

        function template = metadataTemplate(~, descriptor, state)
            template = struct();
            if isempty(descriptor)
                return
            end

            if isstruct(descriptor.MetadataSchema) && ~isempty(fieldnames(descriptor.MetadataSchema))
                template = descriptor.MetadataSchema;
                return
            end

            producedType = descriptor.ProducesNWBType;
            if producedType == "*"
                producedType = state.TargetNWBType;
            end
            if strlength(producedType) == 0
                return
            end

            fullTypeName = char(nansen.module.nwb.internal.lookup.getFullTypeName(producedType));
            template = nansen.module.nwb.internal.getTypeMetadataStruct(fullTypeName);
            template = nansen.module.nwb.internal.addLinkedTypeInstances(template, fullTypeName);
        end

        function editConverterArgs(obj)
            item = obj.selectedItem();
            resolution = obj.describeResolution(item);

            defaults = struct();
            if ~isempty(resolution.Descriptor)
                defaults = resolution.Descriptor.DefaultConverterArgs;
            end
            converterArgs = nansen.module.nwb.internal.deepMerge(defaults, item.ConverterArgs);
            if isempty(fieldnames(converterArgs))
                uialert(obj.Figure, ...
                    "This converter takes no arguments.", "Converter arguments", "Icon", "info")
                return
            end

            [edited, wasAborted] = tools.editStruct(converterArgs, 'all', 'Edit converter arguments', ...
                'Prompt', sprintf('Arguments of the converter for %s', item.VariableName));
            if wasAborted
                return
            end
            obj.setConverterArgs(utility.struct.removeConfigFields(edited))
        end

        function addManyVariables(obj)
            names = obj.unconfiguredVariables();
            if isempty(names)
                uialert(obj.Figure, "Every data variable is in the configuration already.", ...
                    "Nothing to add", "Icon", "info")
                return
            end

            dialog = uifigure("Name", "Add variables", "WindowStyle", "modal", ...
                "Position", obj.centeredDialogPosition([360, 460]));
            cleanupObj = onCleanup(@() delete(dialog));

            grid = uigridlayout(dialog, [2, 1]);
            grid.RowHeight = {"1x", 38};
            listBox = uilistbox(grid, "Items", cellstr(names), "Multiselect", "on");
            buttons = uigridlayout(grid, [1, 3]);
            buttons.ColumnWidth = {"1x", 90, 90};
            buttons.Padding = [0, 0, 0, 0];
            cancel = uibutton(buttons, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) uiresume(dialog));
            cancel.Layout.Column = 2;
            selected = strings(1, 0);
            confirm = uibutton(buttons, "Text", "Add", "ButtonPushedFcn", @(~, ~) onConfirm());
            confirm.Layout.Column = 3;

            uiwait(dialog)

            for i = 1:numel(selected)
                obj.addVariable(selected(i))
            end

            function onConfirm()
                selected = string(listBox.Value);
                uiresume(dialog)
            end
        end

        function position = centeredDialogPosition(obj, dialogSize)
            figurePosition = obj.Figure.Position;
            position = [figurePosition(1) + (figurePosition(3) - dialogSize(1)) / 2, ...
                figurePosition(2) + (figurePosition(4) - dialogSize(2)) / 2, dialogSize];
        end

        function onListSelectionChanged(obj, eventData)
            rowKeys = string(eventData.RowKeys);
            rowKeys = rowKeys(strlength(rowKeys) > 0);
            if isempty(rowKeys)
                obj.SelectedVariable = "";
                obj.fillPanel()
                return
            end
            if rowKeys(1) ~= obj.SelectedVariable
                obj.SelectedVariable = rowKeys(1);
                obj.fillPanel()
            end
        end

        function onListCellEdited(obj, eventData)
            obj.runUiAction(@() obj.applyListEdit( ...
                string(eventData.RowKey), string(eventData.VariableName), eventData.NewValue))
        end

        function onCloseRequested(obj)
            if obj.IsDirty && obj.Figure.Visible == "on"
                answer = uiconfirm(obj.Figure, "Save the NWB configuration?", "Unsaved changes", ...
                    "Options", {"Save", "Discard", "Cancel"}, "DefaultOption", "Save", ...
                    "CancelOption", "Cancel");
                switch answer
                    case "Save"
                        obj.saveConfiguration()
                    case "Discard"
                        % Close without saving.
                    otherwise
                        return
                end
            end
            delete(obj)
        end

        function saveAndNotify(obj, doClose)
            obj.saveConfiguration()
            if doClose
                delete(obj)
            else
                uialert(obj.Figure, "Saved to " + obj.FilePath, "Saved", "Icon", "success")
            end
        end

        function runUiAction(obj, action)
            try
                action()
            catch exception
                if ~isempty(obj.Figure) && isvalid(obj.Figure)
                    uialert(obj.Figure, exception.message, "NWB Configurator", "Icon", "error")
                else
                    rethrow(exception)
                end
            end
        end

        function refreshList(obj)
            obj.VariableDropdown.Items = cellstr(obj.unconfiguredVariables());
            obj.List.setData(obj.listTable(), "Variable")
            if strlength(obj.SelectedVariable) > 0
                obj.List.setSelectedRowKeys(obj.SelectedVariable)
            end
        end

        function updateSelectedItem(obj, item)
            isItem = obj.configuredVariables() == obj.SelectedVariable;
            obj.Config.DataItems(isItem) = item;
            obj.refreshList()
            obj.fillPanel()
        end

        function item = selectedItem(obj)
            if strlength(obj.SelectedVariable) == 0
                error("nansen:nwb:noSelection", ...
                    "No data item is selected. Select a row in the list first.")
            end
            isItem = obj.configuredVariables() == obj.SelectedVariable;
            item = obj.Config.DataItems(isItem);
        end

        function names = configuredVariables(obj)
            items = obj.Config.DataItems;
            if isempty(items)
                names = strings(1, 0);
            else
                names = reshape([items.VariableName], 1, []);
            end
        end

        function names = unconfiguredVariables(obj)
            names = setdiff(obj.VariableNames, obj.configuredVariables(), "stable");
            names = reshape(names, 1, []);
        end

        function resolution = describeResolution(obj, item)
            %describeResolution - What the runner would do with an item

            resolution = struct("Status", "ok", "Message", "", "Descriptor", []);
            try
                descriptor = obj.Registry.resolveForItem(item);
            catch exception
                resolution.Message = exception.message;
                switch exception.identifier
                    case "nansen:nwb:unresolvedConverter"
                        resolution.Status = "unresolved";
                    case "nansen:nwb:ambiguousConverter"
                        resolution.Status = "ambiguous";
                    case "nansen:nwb:unknownConverter"
                        resolution.Status = "unknown converter";
                    otherwise
                        rethrow(exception)
                end
                return
            end

            resolution.Descriptor = descriptor;

            if descriptor.Name == obj.GENERIC_CONVERTER && isUnsetText(item.TargetNWBType)
                resolution.Status = "set target type";
                resolution.Message = "The generic converter builds the type named in Target type, which is not set.";
                return
            end

            [primaryGroup, moduleName] = obj.effectivePlacement(item, descriptor);
            validGroups = nansen.module.nwb.conversion.NWBConverterDescriptor.VALID_PRIMARY_GROUPS;
            if ~any(validGroups == primaryGroup)
                resolution.Status = "unknown group";
                resolution.Message = "'" + primaryGroup + "' is not an NWB group. Choose one of: " ...
                    + strjoin(validGroups, ", ") + ".";
                return
            end

            if descriptor.RequiresPython && ~obj.pythonAvailable()
                resolution.Status = "needs Python";
                resolution.Message = obj.PythonReport.Message;
                return
            end

            placementText = primaryGroup;
            if primaryGroup == "Processing" && strlength(moduleName) > 0
                placementText = placementText + "/" + moduleName;
            end
            resolution.Message = "Converts with " + descriptor.DisplayName + " to " ...
                + resolvedType(descriptor, item) + " in " + placementText + ".";
        end

        function [primaryGroup, moduleName] = effectivePlacement(~, item, descriptor)
            %effectivePlacement - Where the runner puts an item's output
            %   The item's group and module, unless the converter it
            %   resolves to owns placement, in which case the group is the
            %   converter's, as in NWBFileConverter.createPlacement, and
            %   the module the first one the converter is tagged for.

            primaryGroup = item.PrimaryGroup;
            moduleName = item.NWBModule;
            if isempty(descriptor) || ~ownsPlacement(descriptor)
                return
            end

            primaryGroup = descriptor.PrimaryGroup;
            moduleTags = descriptor.NWBModuleTags(descriptor.NWBModuleTags ~= "*");
            if ~isempty(moduleTags)
                moduleName = moduleTags(1);
            end
        end

        function tf = pythonAvailable(obj)
            if isempty(obj.PythonReport)
                [isAvailable, report] = obj.PythonCheckFcn();
                obj.PythonReport = struct("IsAvailable", logical(isAvailable), ...
                    "Message", string(report.Message));
            end
            tf = obj.PythonReport.IsAvailable;
        end

        function buildLabelMap(obj)
            descriptors = obj.Registry.list();
            obj.LabelToName = dictionary(string.empty, string.empty);
            for i = 1:numel(descriptors)
                obj.LabelToName(obj.labelFor(descriptors(i))) = descriptors(i).Name;
            end
        end

        function label = labelFor(~, descriptor)
            sourceWords = dictionary(["builtin", "neuroconv", "custom"], ...
                ["built-in", "NeuroConv", "custom"]);
            label = descriptor.DisplayName + " (" + sourceWords(descriptor.Source) + ")";
        end

        function label = labelForName(obj, converterName)
            %labelForName - The label of a converter, registered or not
            %   A configuration can name a converter this session has not
            %   registered, such as a custom converter whose folder is not
            %   registered yet. It is shown by its name, so that the
            %   configuration still opens and the item can be given
            %   another converter.

            if obj.isRegistered(converterName)
                label = obj.labelFor(obj.Registry.get(converterName));
            else
                label = converterName + obj.UNREGISTERED_SUFFIX;
            end
        end

        function tf = isRegistered(obj, converterName)
            tf = any(obj.Registry.names() == converterName);
        end

        function labels = converterLabels(obj)
            labels = [obj.AUTO_LABEL, sort(keys(obj.LabelToName))'];
        end

        function name = nameForLabel(obj, label)
            label = strtrim(string(label));
            label = erase(label, " (suggested)");
            if label == obj.AUTO_LABEL || strlength(label) == 0
                name = "";
            elseif isKey(obj.LabelToName, label)
                name = obj.LabelToName(label);
            else
                % A registry key typed directly is accepted as it is.
                name = label;
            end
        end

        function state = currentState(obj)
            state = string(jsonencode(obj.Config.toStruct()));
        end
    end
end

function names = defaultVariableNames()
%defaultVariableNames - The current project's data variables, if there is one

    names = strings(1, 0);
    try
        variableModel = nansen.VariableModel();
        if ~isempty(variableModel)
            names = reshape(string(variableModel.VariableNames), 1, []);
        end
    catch
        % Without NANSEN or a current project, items are added by name.
    end
end

function sourceInfo = sourceInfoFor(variableName)
%sourceInfoFor - Source evidence for a variable, from the project's variable model

    try
        sourceInfo = nansen.module.nwb.session.NWBSessionConfigBuilder.sourceInfoForVariable(variableName);
    catch
        sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
    end
end

function typeName = resolvedType(descriptor, item)
%resolvedType - The neurodata type a resolution produces

    typeName = descriptor.ProducesNWBType;
    if typeName == "*"
        typeName = item.TargetNWBType;
    end
end

function tf = ownsPlacement(descriptor)
%ownsPlacement - Whether a converter, not the item, decides placement

    tf = descriptor.PlacementPolicy == "converter" && ~descriptor.AllowsPlacementOverride;
end

function word = statusWord(isSet)
%statusWord - "customized" or "unconfigured"

    if isSet
        word = "customized";
    else
        word = "unconfigured";
    end
end

function tf = isUnsetText(value)
%isUnsetText - True for blank text or a configurator placeholder

    value = strtrim(string(value));
    tf = ismissing(value) || strlength(value) == 0 || startsWith(value, "<");
end
