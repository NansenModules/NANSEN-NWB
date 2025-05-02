classdef DynamicTableCollection < handle
%DynamicTableCollection A GUI tab component for handling a collection of
%dynamic tables.
    
    % Note: Currently only supports an electrodes table.

    % Todo: 
    %   [ ] Store multiple tables
    %   [ ] Add options for creating new dynamic tables.
    %   [ ] Add dynamic tables programmatically, i.e from a function or
    %       from tabular files, i.e csv, or excel files
    
    properties (Constant, Hidden)
        DEFAULT_THEME = nansen.theme.getThemeColors('deepblue')
    end

    properties
        DynamicTable (1,1) dictionary
    end

    properties (SetAccess = private)
        NWBConfigurationData
    end
    
    properties (Access = protected) % UI Components
        Parent
        UITable
        
        HintTextbox
        DynamicTableSelector
        TableContextMenu
        
        UiMenuA
        UiMenuB

        TablePanels = dictionary
    end
    
    properties (Access = private)
        dropdownOpen = false;
    end
    
    properties (Access = private)
        NWBConverters = dictionary % classname -> package-prefixed classname
    end

    properties (Constant, Access=private)
        NWB_MODULES = nansen.module.nwb.internal.schemautil.getNwbModules()
    end
    
    methods % Constructor
        
        function obj = DynamicTableCollection(parent, nwbConfigurationData)
        %PIPELINEBUILDERUI Construct an instance of this class
            %   Detailed explanation goes here
            
            arguments
                parent
                nwbConfigurationData
            end

            obj.Parent = parent;

            % Assign input to properties
            obj.NWBConfigurationData = nwbConfigurationData;
            
            obj.listConverters()

            % Create components
            obj.createComponents()
            % obj.updateSize()
            % obj.createContextMenus()
            
            obj.initializeTables()
            
            %obj.IsConstructed = true;
            obj.onThemeChanged()

            if ~nargout
                clear obj
            end
        end

    end
    
    methods 
        function tf = isDirty(obj)
            % Check if any tables are dirty, handling case where tables might not exist
            if ~isConfigured(obj.DynamicTable)
                tf = false;
                return
            end
            tf = arrayfun(@(dt) dt.IsDirty, obj.DynamicTable.values);
        end
    
        function deactivate(obj)
            % Save dynamic tables
            
            % Check if electrodes table exists before saving
            if isConfigured(obj.DynamicTable)
                if isKey(obj.DynamicTable, "General_ExtracellularEphys_Electrodes")
                    catalog = nansen.module.nwb.internal.getMetadataCatalog("ElectrodesTable");
                    
                    catalogItem = catalog.get("ElectrodesTable");
                    catalogItem.DynamicTable = obj.DynamicTable("General_ExtracellularEphys_Electrodes").DynamicTable;
                    catalog.replace(catalogItem)
        
                    catalog.save()
                end
            end
        end

        function activate(obj)
            % Reload dynamic tables
            
            % Check if electrodes table exists before reloading
            if isConfigured(obj.DynamicTable)
                if isKey(obj.DynamicTable, "General_ExtracellularEphys_Electrodes")
                    catalog = nansen.module.nwb.internal.getMetadataCatalog("ElectrodesTable");
                    catalogItem = catalog.get("ElectrodesTable");
                    electrodeTable = catalogItem.DynamicTable;
                
                    obj.DynamicTable("General_ExtracellularEphys_Electrodes").DynamicTable = electrodeTable;
                end
            end
        end
    end

    methods %(Access = protected) % Override AppWindow methods
        % function assignDefaultSubclassProperties(obj)
        %     obj.DEFAULT_FIGURE_SIZE = [1000 560];
        %     obj.MINIMUM_FIGURE_SIZE = [560 420];
        % end 
        
        function updateSize(obj)
            obj.updateTablePosition()
        end
        
    end
    
    methods (Access = private)
        
        function listConverters(obj)
            currentProject = nansen.getCurrentProject();
            nwbConverters = currentProject.listMixins('nwbconverter');

            baseNames = utility.string.getSimpleClassName(nwbConverters);
            
            obj.NWBConverters(baseNames) = nwbConverters;
        end

        function createComponents(obj)
            
            obj.Parent.BackgroundColor = ones(1,3)*0.91;

            % Create table menu (menu for selecting tables):
            % Make table names dynamic based on which tables exist
            tableNames = {'Trials'};
            
            % Add Electrodes to table names if it exists in the catalog
            catalog = nansen.module.nwb.internal.getMetadataCatalog("ElectrodesTable");
            if catalog.contains("ElectrodesTable")
                tableNames = [{'Electrodes'}, tableNames];
            end
            
            buttonGroup = nansen.ui.widget.ButtonGroup(obj.Parent, 'Items', tableNames);
            buttonGroup.updateLocation()
            buttonGroup.SelectionChangedFcn = @obj.onDynamicTableTypeChanged;
            obj.DynamicTableSelector = buttonGroup;

            obj.createAddTableButton()
            %obj.updateTablePosition()
        end
        
        function createContextMenus(obj)
            hFigure = ancestor(obj.Parent, 'figure');
            obj.TableContextMenu = uicontextmenu(hFigure);
            mitem = uimenu(obj.TableContextMenu, 'Text', 'Remove Task');
            %mitem.Callback = @obj.onRemoveTaskMenuItemClicked;
        end
        
        function createAddTableButton(obj)

            % Todo: This should be retrieved from a private property, and
            % used also when configuring the buttongroup for switching
            % tables
            xPad = 4;

            ICONS = uim.style.iconSet(nansen.App.getIconPath);
            icon = ICONS.plus;

            buttonConfig = {'FontSize', 15, 'FontName', 'helvetica', ...
                'Padding', [xPad,2,xPad,2], 'CornerRadius', 7, ...
                'Mode', 'pushbutton', 'Style', uim.style.tabButtonLight, ...
                'Icon', icon, 'IconSize', [14,14], 'IconTextSpacing', 7};

            W = obj.DynamicTableSelector.Width - 8;

            hButton = uim.control.Button_(obj.Parent, buttonConfig{:});
            hButton.Text = 'Add Table';
            hButton.updateLocation()
            hButton.Size = [W, 26];
            hButton.Margin = [0,5,4,0]; % Note: Ad hoc placement..
            hButton.Callback = @obj.addDynamicTable;
        end

        function initializeTables(obj)

            % obj.NWBConfigurationData.General.ExtracellularEphys.Electrodes = ...
            %     nansen.module.nwb.internal.dtable.initializeElectrodesTable();
            % electrodeTable = obj.NWBConfigurationData.General.ExtracellularEphys.Electrodes;
        

    
            % Todo: Create panels and dynamic tables for each dynamic table
            % of the NWB Configuration

            hPanel = uipanel(obj.Parent, BorderType="none");
            obj.TablePanels('Trials') = hPanel;

            catalog = nansen.module.nwb.internal.getMetadataCatalog("ElectrodesTable");
            if catalog.contains("ElectrodesTable")
                catalogItem = catalog.get("ElectrodesTable");
                electrodeTable = catalogItem.DynamicTable;
                hPanel = uipanel(obj.Parent, BorderType="none");
                obj.TablePanels('Electrodes') = hPanel;
    
                key = "General_ExtracellularEphys_Electrodes";
    
                obj.DynamicTable(key) = nansen.module.nwb.gui.UIDynamicTable(...
                    electrodeTable, 'TableName', 'Electrode', 'Parent', hPanel);
            end

            obj.updateTablePosition()
        end
    
        function updateTablePosition(obj)
        % updateTablePosition - Update position of table
        %
        %   If there is a table selector, this function is used to ensure
        %   the table is positioned left of the table selector menu.

            if isempty(obj.DynamicTableSelector); return; end
            
            w = obj.DynamicTableSelector.Width;
            uiTable = obj.DynamicTable;
            
            % Todo: Get the padding value programmatically
            xPadding = 3;
            
            parentPosition = getpixelposition(obj.Parent);
            panelWidth = parentPosition(3);

            % Get position from any available panel
            if isKey(obj.TablePanels, 'Trials')
                tablePosition = getpixelposition(obj.TablePanels('Trials'));
            elseif isKey(obj.TablePanels, 'Electrodes')
                tablePosition = getpixelposition(obj.TablePanels('Electrodes'));
            else
                % Create a default position if no panels exist
                tablePosition = [w + xPadding, 1, panelWidth - (w + xPadding + 1), parentPosition(4)];
            end
            
            tablePosition(1) = w + xPadding;
            tablePosition(3) = panelWidth - (w + xPadding + 1);
            
            % Only update panels that exist
            if ~isempty(obj.TablePanels)
                arrayfun(@(h) setpixelposition(h, tablePosition), [obj.TablePanels.values]);
            end
        end
    end
    
    methods (Access = protected)
        
        function addDynamicTable(obj, src, evt)
            msgbox('Not implemented yet', 'Error')
            % Todo: 
            
            % Select table from list

            % Abort if table already exists...?

            % Initialize table

            % Add table to NWB Configuration Data

            % Add button to GUI

        end

        function onDynamicTableTypeChanged(obj, s, e)

            selectedTableName = s.Text;
            % Only hide/show panels if they exist
            if ~isempty(obj.TablePanels)
                set([obj.TablePanels.values], 'Visible', 'off')
                if isKey(obj.TablePanels, selectedTableName)
                    obj.TablePanels(selectedTableName).Visible='on';
                end
            end
        end
            
        function setDefaultFigureCallbacks(obj)
            %obj.Figure.WindowKeyPressFcn = @obj.onKeyPressedInTable;
        end
    
        function onThemeChanged(obj)
            % Todo:
        end
    end
end
