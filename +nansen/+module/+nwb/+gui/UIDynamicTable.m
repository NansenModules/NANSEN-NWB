classdef UIDynamicTable < handle & nansen.ui.mixin.HasPropertyArgs & applify.mixin.HasUserData
% UIDynamicTable - General UI for the dynamic table type of NWB.
%
%   Key features
%     - Add rows and columns on demand.
%     - Option to select and create new instances for columns of Neurodata
%     types.

    % A table widget with methods for adding rows (x amount), removing rows
    % Adding columns
    % Context menu for performing those operations
    % UI interface for creating a region view.
    %   This could be as simple as popping up a button, instructing users
    %   to select rows and then press the button when finished


    % Todo:
    %  [ ] Column descriptions available from tooltips
    %  [ ] Context menu on column header
    %  [ ] Strategy for setting column widths. Make table scrollable horizontally
    %  [ ] Populate dropdowns for columns of types "matnwb.types.core..."
    %  [ ] Have an add/create new instance method for the columns of nwb types...
    %  [ ] Visible property to turn on/off visible state...

    properties (Dependent)
        DynamicTable % The original dynamic table data object
    end

    properties (Access = private)
        LastClickedCell
    end

    properties (Access = ?nansen.ui.mixin.HasPropertyArgs)
        TableName
    end

    properties (Access = ?nansen.ui.mixin.HasPropertyArgs)
        Parent % The immediate parent container of the table
        Figure % The figure the table is located
        UITable
        UITableContextMenu
    end

    methods % Constructor
        function obj = UIDynamicTable(dynamicTable, options)

            arguments
                dynamicTable = []
                options.Parent = []
                options.TableName (1,1) string = missing
            end

            obj.assignPropertyArguments(options)

            if isempty(obj.Parent)
                obj.createFigure()
            else
                obj.Figure = ancestor(obj.Parent, 'figure');
            end
                
            obj.createLayout()
            obj.createComponents()
            obj.createContextMenus()

            obj.DynamicTable = dynamicTable;
        
            %obj.UITable.ColumnName = app.UITable.Data.Properties.VariableNames;
        end
    end

    methods % Set/get
        
        function set.DynamicTable(obj, newValue)
            obj.Data = newValue;
            obj.onDynamicTableSet()
        end

        function value = get.DynamicTable(obj)
            value = obj.Data;
        end
    end

    methods

        function position = getpixelposition(obj, isRecursive)
            if nargin < 2; isRecursive=false; end
            position = getpixelposition(obj.UITable, isRecursive);
        end

        function setpixelposition(obj, position, isRecursive)
            if nargin < 3; isRecursive=false; end
            setpixelposition(obj.UITable, position, isRecursive);
        end

        function addColumns(obj, numColumns, columnIndex, location)
            arguments
                obj
                numColumns (1,1) double = 1
                columnIndex (1,1) double = []
                location (1,1) string {mustBeMember(location, ["before", "after"])} = "after"
            end

            if isempty( columnIndex )
                columnIndex = size(obj.DynamicTable, 2);
            end
            error('Not implemented yet')
        end

        function addRows(obj, numRows, rowIndex, location)
            arguments
                obj
                numRows = 1
                rowIndex = []
                location (1,1) string {mustBeMember(location, ["below", "above"])} = "below"
            end

            numColumns = size(obj.DynamicTable, 2);
            columnNames = string( obj.DynamicTable.Properties.VariableNames );
            
            if isempty( rowIndex )
                rowIndex = size(obj.DynamicTable, 1);
            end

            if strcmp(location, 'above'); rowIndex = max([0,rowIndex-1]); end
            if rowIndex > size(obj.DynamicTable, 1); rowIndex = size(obj.DynamicTable, 1); end

            newRowData = repmat(missing, numRows, numColumns);
            newRowData = array2table(newRowData, 'VariableNames', obj.DynamicTable.Properties.VariableNames );
            
            tablePreInsert = obj.DynamicTable(1:rowIndex, :);
            tablePostInsert = obj.DynamicTable(rowIndex+1:end, :);
            
            for iName = columnNames
                if startsWith( class( obj.DynamicTable.(iName) ), 'matnwb' )
                    instance(numRows) = feval( class( obj.DynamicTable.(iName) ) ); %#ok<AGROW>
                    newRowData.(iName) = reshape( instance, [], 1 );
                elseif isnumeric( obj.DynamicTable.(iName) )
                    newRowData.(iName) = zeros(numRows, 1);
                end
            end
            
            numRows = size(obj.DynamicTable, 1) +  numRows;
            newTable = cat(1, tablePreInsert, newRowData, tablePostInsert);
            obj.DynamicTable(1:numRows, :) = newTable;
            
            % % if isempty(obj.DynamicTable)
            % %     obj.DynamicTable(1:numRows, :) = newTable;
            % % else
            % %     obj.DynamicTable = cat(1, tablePreInsert, newRowData, tablePostInsert);
            % % end
        end
    end

    methods (Access = private)

        function onDynamicTableSet(obj)

            isInitialized = ~isempty(obj.UITable.DataTable);
            
            % Reformat table data before assigning.
            
            tableDataDisplay = obj.DynamicTable;

            % Update values for nwb types based on the data in their
            % dependent columns. Still remains to be seen if every
            % vectordata nwb type has a dependent column...
            columnNames = obj.DynamicTable.Properties.VariableNames;
            columnFormat = cellfun(@(c) class( obj.DynamicTable.(c) ), columnNames, 'UniformOutput', false );
            isNwbType = startsWith(columnFormat, 'matnwb.types.core');

            nwbTypeInd = find(isNwbType);
            for idx = nwbTypeInd
                dependentColumnName = obj.getDependentColumnName(idx);
                tableDataDisplay.(columnNames{idx}) = tableDataDisplay.(dependentColumnName);
            end

            % Set the DataTable for display
            obj.UITable.DataTable = tableDataDisplay;

            if ~isInitialized
                obj.updateTableColumnAttributes()
            end
        end
        
        function onTableCellEdited(obj, src, evt)
            rowNumber = evt.Indices(1);
            colNumber = evt.Indices(2);  
            newValue = evt.NewValue;
            
            if strcmp(obj.UITable.ColumnFormat{colNumber}, 'popup')
                if startsWith(newValue, '<Create')
                    obj.createNewNWBType(rowNumber, colNumber)
                    return
                end
            end

            if obj.isNwbType(colNumber)
                nwbDataType = obj.getNwbType(colNumber);
                % Get the corresponding item for the catalog.
                catalog = nansen.module.nwb.internal.getMetadataCatalog(nwbDataType);
                
                instanceName = newValue;
                S = catalog.get(instanceName);

                % Todo: This should be internal to the catalog...
                S = rmfield(S, ["name", "Uuid"]);
                nvPairs = namedargs2cell(S);
                newValue = feval( nwbDataType, nvPairs{:} );
                
                % Update dependent column.
                obj.updateDependentColumn(rowNumber, colNumber, instanceName)
            end

            if ischar(newValue)
                obj.DynamicTable{rowNumber, colNumber} = {newValue};
            else
                obj.DynamicTable{rowNumber, colNumber} = newValue;
            end

            obj.UITable.ColumnEditable(colNumber) = false;

        end

        function onTableCellSelected(obj, src, evt)
            %obj.UITable.ColumnEditable(:) = false;
        end

        function onTableCellClicked(obj, src, evt)
  
            if evt.Button == 3 || strcmp(evt.SelectionType, 'alt')
                obj.onMouseRightClickedInTable(src, evt)
            elseif strcmp(evt.SelectionType, 'open')
                obj.onTableCellDoubleClicked(src, evt)
            else
                if any(evt.Cell==0)
                    obj.UITable.ColumnEditable(:) = false;
                end
            end
        end

        function onMouseRightClickedInTable(obj, src, evt)
            
            if isempty(obj.UITableContextMenu); return; end

            % Get row where mouse press ocurred.
            row = evt.Cell(1);
            obj.LastClickedCell = evt.Cell;

            % Select row where mouse is pressed if it is not already
            % selected
            if ~ismember(row, obj.UITable.SelectedRows) && row~=0
                obj.UITable.SelectedRows = row;
            end

            % Get scroll positions in table
            xScroll = obj.UITable.JScrollPane.getHorizontalScrollBar().getValue();
            yScroll = obj.UITable.JScrollPane.getVerticalScrollBar().getValue();

            % Get position where mouseclick occured (in figure)
            clickPosX = evt.Position(1) - xScroll;
            clickPosY = evt.Position(2) - yScroll;

            % Open context menu for table
            if ~isempty(obj.UITableContextMenu)
                obj.openTableContextMenu(clickPosX, clickPosY);
            end
        end
        
        function onTableCellDoubleClicked(obj, src, evt)
            row = evt.Cell(1);
            col = evt.Cell(2);
            
            if row >= 1 && col >= 0
                obj.UITable.ColumnEditable(col) = true;
                obj.UITable.JTable.editCellAt(row-1, col-1);
            end
        end

        function onAddNewRowMenuItemClicked(obj, src, evt, location)
            rowNumber = obj.LastClickedCell(1);
            obj.addRows(1, rowNumber, location)
        end

        function onAddXNewRowsMenuItemClicked(obj, src, evt, location)
            x = inputdlg('Enter number of rows');

            if ~isempty(x)
                x = str2double(x);
                rowNumber = obj.LastClickedCell(1);
                obj.addRows(x, rowNumber, location)
            end
        end
    end

    methods (Access = private)
            
        function createFigure(obj)
            % Create the figure window
            obj.Figure = figure('Visible', 'on');
            obj.Figure.NumberTitle = 'off';
            obj.Figure.MenuBar = 'none';
            obj.Figure.ToolBar = 'none';

            if ~ismissing(obj.TableName)
                obj.Figure.Name = sprintf('Dynamic Table (%ss)', obj.TableName);
            else
                obj.Figure.Name = "Dynamic Table";
            end
            %obj.Figure.CloseRequestFcn = @(s, e) obj.delete;
        end

        function createLayout(obj)
            if ~isempty(obj.Parent) && ~isequal(obj.Parent, obj.Figure)
                return
            end

            obj.Parent = uipanel(obj.Figure);
            obj.Parent.BorderType = 'none';
            obj.Parent.Position = [0,0,1,1];
            obj.Parent.Tag = 'UITable Panel';
        end
    
        function createComponents(obj)
            obj.createUITable()
        end

        function createUITable(obj)
        
            obj.UITable = uim.widget.StylableTable('Parent', obj.Parent, ...
                        'RowHeight', 25, ...
                        'FontSize', 8, ...
                        'FontName', 'helvetica', ...
                        'FontName', 'avenir next', ...
                        'Theme', uim.style.tableLight, ...
                        'Units', 'normalized', ...
                        'Position', [0.05,0.025,0.9,0.95]);
            
            obj.UITable.CellEditCallback = @obj.onTableCellEdited;
            obj.UITable.MouseClickedCallback = @obj.onTableCellClicked;
            obj.UITable.CellSelectionCallback = @obj.onTableCellSelected;
            % obj.UITable.KeyPressFcn = @obj.onKeyPressedInTable;

            % addlistener(obj.UITable, 'MouseMotion', @obj.onMouseMotionOnTable);
        end
    
        function createContextMenus(obj)
            
            obj.UITableContextMenu = uicontextmenu(obj.Figure);

            if ismissing(obj.TableName)
                rowName = 'Row';
            else
                rowName = obj.TableName;
            end

            mitem = uimenu(obj.UITableContextMenu, 'Text', sprintf('Add %s Above', rowName));
            mitem.Callback = @(s,e) obj.onAddNewRowMenuItemClicked(s,e,'above');
            mitem = uimenu(obj.UITableContextMenu, 'Text', sprintf('Add %s Below', rowName));
            mitem.Callback = @(s,e) obj.onAddNewRowMenuItemClicked(s,e,'below');

            %mitem.Callback = @obj.onRemoveTaskMenuItemClicked;
            mitem = uimenu(obj.UITableContextMenu, 'Text', 'Add Column Before');
            mitem = uimenu(obj.UITableContextMenu, 'Text', 'Add Column Before');

            mitem = uimenu(obj.UITableContextMenu, 'Text', sprintf('Add N %ss Above...', rowName), 'Separator', 'on');
            mitem.Callback = @(s,e) obj.onAddXNewRowsMenuItemClicked(s,e,'above');
            mitem = uimenu(obj.UITableContextMenu, 'Text', sprintf('Add N %ss Below...', rowName));
            mitem.Callback = @(s,e) obj.onAddXNewRowsMenuItemClicked(s,e,'below');

            mitem = uimenu(obj.UITableContextMenu, 'Text', 'Delete Row', 'Separator', 'on');
            %mitem.Callback = @obj.onRemoveTaskMenuItemClicked;
            mitem = uimenu(obj.UITableContextMenu, 'Text', 'Delete Column');

        end

        function updateComponentLayout(obj)
        end
        
        function openTableContextMenu(obj, x, y)
            
            if isempty(obj.UITableContextMenu); return; end
            
            % This is now corrected for in caller function...
            tablePosition = getpixelposition(obj.UITable, true);
            tableLocationX = tablePosition(1) + 1; % +1 because ad hoc...
            tableHeight = tablePosition(4);
            
            offset = 0; % 15
            cMenuPos = [tableLocationX + x, tableHeight - y + offset]; % +15 because ad hoc...
                        
            % Set position and make menu visible.
            obj.UITableContextMenu.Position = cMenuPos;
            obj.UITableContextMenu.Visible = 'on';
        end

        function updateTableColumnAttributes(obj)
            
            numRows = size(obj.DynamicTable, 1);
            
            columnNames = obj.DynamicTable.Properties.VariableNames;
            columnFormat = cellfun(@(c) class( obj.DynamicTable.(c) ), columnNames, 'UniformOutput', false );
            columnEditable = false(size(columnNames));
            columnWidth = ones(size(columnNames))*150;
            colFormatData = cell(size(columnNames));


            columnFormat(strcmp(columnFormat, 'single'))={'numeric'};
            columnWidth(strcmp(columnFormat, 'numeric')) = 60;
            columnFormat(strcmp(columnFormat, 'string'))={'char'};

            isNwbType = startsWith(columnFormat, 'matnwb.types.core');

            for i = find(isNwbType)
                colFormatData{i} = obj.getNwbTypeOptionsForDropdown( columnFormat{i} );
            end

            columnFormat(isNwbType)={'popup'};

            % Update the column formatting properties
            %obj.UITable.ColumnFormat = {'char', 'char', 'popup', 'popup', 'popup', 'popup', 'char'};

            %nwbModules = obj.NWB_MODULES;
            %[~, neuroDataTypes] = enumeration( 'nansen.module.nwb.enum.NeuroDataType' );
            %[~, groupNames] = enumeration( 'nansen.module.nwb.enum.PrimaryGroupName' );


            %obj.UITable.ColumnFormatData = colFormatData;

            %columnNames = obj.DynamicTable.Properties.VariableNames;
            %numColumns = numel(columnNames);

            % % isEditable = true(1, numColumns);
            % % isEditable( strcmp(columnNames, 'VariableName') ) = false;
            % % isEditable( strcmp(columnNames, 'DefaultMetadata') ) = false;
           
            obj.UITable.ColumnFormat = columnFormat;
            obj.UITable.ColumnFormatData = colFormatData;
            obj.UITable.ColumnEditable = columnEditable;
            obj.UITable.ColumnWidth = columnWidth;
            obj.UITable.ColumnPreferredWidth = columnWidth;
        end
        
        function options = getNwbTypeOptionsForDropdown(obj, neurodataType)
            
            instanceCatalog = nansen.module.nwb.internal.getMetadataCatalog(neurodataType);
            typeShortName = utility.string.getSimpleClassName(neurodataType);

            actionLabel = sprintf("<Create a new %s>", typeShortName);

            options = cellstr(instanceCatalog.ItemNames);
            options = [{actionLabel}, options];
        end
    end
   
    methods (Access = private)
        function createNewNWBType(obj, rowNumber, colNumber)

            fullLinkedTypeName = class( obj.DynamicTable{rowNumber, colNumber});
            
            existingItems = obj.DynamicTable{:, colNumber};
            [newItemName, newItem] = nansen.module.nwb.internal.createNewNwbInstance(existingItems, fullLinkedTypeName);
            
            obj.UITable.ColumnFormatData{colNumber}{end+1} = newItemName;
            obj.DynamicTable{rowNumber, colNumber} = newItem;

            % Todo: Figure out if this is general:
            obj.updateDependentColumn(rowNumber, colNumber, newItemName)
        end
    end

    % Internal methods the might be moved to a DynamicTable class if the
    % need for such a class arises.
    methods (Access = private)
        
        function columnName = getColumnName(obj, columnNumber)
            columnName = obj.DynamicTable.Properties.VariableNames{columnNumber};
        end

        function columnName = getDependentColumnName(obj, columnNumber)
            columnName = obj.DynamicTable.Properties.CustomProperties.ColumnDependency(columnNumber);
        end

        function tf = isNwbType(obj, columnNumber)
            columnNames = obj.DynamicTable.Properties.VariableNames(columnNumber);
            columnFormat = cellfun(@(c) class( obj.DynamicTable.(c) ), columnNames, 'UniformOutput', false );
            tf = startsWith(columnFormat, 'matnwb.types.core');
        end

        function nwbType = getNwbType(obj, columnNumber)
            columnName = obj.getColumnName(columnNumber);
            nwbType = class( obj.DynamicTable.(columnName) );
        end
               
        function updateDependentColumn(obj, rowNumber, colNumber, newItemName)
            % This is some ad hoc code to place the name to the correct
            % columns. Todo: Still remains to be seen if this will be a 
            % general pattern for dynamic tables.
            dependentColumnName = obj.getDependentColumnName(colNumber);
            if ~ismissing(dependentColumnName)
                obj.DynamicTable{rowNumber, dependentColumnName} = {newItemName};
            end
        end
    end
end