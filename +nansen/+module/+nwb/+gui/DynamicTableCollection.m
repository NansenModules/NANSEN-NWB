classdef DynamicTableCollection < handle
%DataVariableConfigTable
    %   Detailed explanation goes here


    % Todo: 
    %   [ ] Store multiple tables
    %   [ ] Have a button for each table to initialize table
    %   [ ] OR: An option in the sidebar to add new table from a dropdown
    
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
            tf = arrayfun(@(dt) dt.IsDirty, obj.DynamicTable.values);
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
            tableNames = {'Electrodes', 'Trials'};
            buttonGroup = nansen.ui.widget.ButtonGroup(obj.Parent, 'Items', tableNames);
            buttonGroup.updateLocation()
            buttonGroup.SelectionChangedFcn = @obj.onDynamicTableTypeChanged;
            obj.DynamicTableSelector = buttonGroup;
            %app.updateTablePosition()
        end
        
        function createContextMenus(obj)
            hFigure = ancestor(obj.Parent, 'figure');
            obj.TableContextMenu = uicontextmenu(hFigure);
            mitem = uimenu(obj.TableContextMenu, 'Text', 'Remove Task');
            %mitem.Callback = @obj.onRemoveTaskMenuItemClicked;
        end
   
        function initializeTables(obj)

            % obj.NWBConfigurationData.General.ExtracellularEphys.Electrodes = ...
            %     nansen.module.nwb.internal.dtable.initializeElectrodesTable();
            electrodeTable = obj.NWBConfigurationData.General.ExtracellularEphys.Electrodes;

            hPanel = uipanel(obj.Parent, BorderType="none", BackgroundColor='b');
            obj.TablePanels('Trials') = hPanel;

            hPanel = uipanel(obj.Parent, BorderType="none");
            obj.TablePanels('Electrodes') = hPanel;

            key = "General_ExtracellularEphys_Electrodes";

            obj.DynamicTable(key) = nansen.module.nwb.gui.UIDynamicTable(...
                electrodeTable, 'TableName', 'Electrode', 'Parent', hPanel);
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

            %tablePosition = getpixelposition(uiTable);
            tablePosition = getpixelposition( obj.TablePanels('Electrodes') );
            tablePosition(1) = w + xPadding;
            tablePosition(3) = panelWidth - (w + xPadding + 1);
            %tablePosition(4) =  parentPosition(4);
            %setpixelposition(uiTable, tablePosition)
            
            arrayfun( @(h) setpixelposition(h, tablePosition), [obj.TablePanels.values]);
        end
    end
    
    methods (Access = protected)
        
        function onDynamicTableTypeChanged(obj, s, e)

            selectedTableName = s.Text;
            set( [obj.TablePanels.values], 'Visible', 'off')
            obj.TablePanels(selectedTableName).Visible='on';
        end
            
        function setDefaultFigureCallbacks(obj)
            %obj.Figure.WindowKeyPressFcn = @obj.onKeyPressedInTable;
        end
    
        function onThemeChanged(obj)
            % Todo:
        end
    end
end
