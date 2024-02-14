classdef DataVariableConfigTable < handle & applify.mixin.HasUserData
%DataVariableConfigTable
    %   Detailed explanation goes here
    
    % Todo:
    %  [ ] No need to store NWB Configuration Data internally

    properties (Constant, Hidden)
        DEFAULT_THEME = nansen.theme.getThemeColors('deepblue')
    end

    properties % Table Display Preferences
        PreferredColumnWidth = [150, 150, 170, 150, 150, 1]
        MinimumColumnWidth = [150, 150, 170, 150, 150, 150]
        MaximumColumnWidth
    end

    properties (Dependent)
        ColumnWidth
    end
    
    properties (SetAccess = private)
        NWBConfigurationData
    end

    properties (Dependent)
        TableDataCurrent % Todo: Rename
    end

    properties (Access = protected) % UI Components
        Parent
        AddTaskButton
        AutoCompleteWidget
        BrowseTaskFunctionButton
        UITable
        
        HintTextbox
        
        TableContextMenu
        
        UiMenuA
        UiMenuB
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
        
        function obj = DataVariableConfigTable(parent, nwbConfigurationData)
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
            obj.updateSize()
            obj.createContextMenus()
            
            % Set data for table (important to do after creating table...)
            dataItemTable = struct2table( nwbConfigurationData.DataItems, 'AsArray', true );
            obj.TableDataCurrent = dataItemTable;
            
            %obj.IsConstructed = true;

            if ~nargout
                clear obj
            end
        end

    end
    
    methods %(Access = protected) % Override AppWindow methods
        
        function updateSize(obj)
            
            MARGIN = [20,20,20,30];
            parentSize = getpixelposition(obj.Parent);
            totalWidth = parentSize(3)-MARGIN(1)-MARGIN(3);
            
            % h+w of autocomplete and buttons:
            componentHeight = [30, 22, 22]; 
            componentWidth = [1, 50, 60];
            
            % Calculate position:
            [x, w] = uim.utility.layout.subdividePosition(MARGIN(1), ...
                totalWidth, componentWidth, 15);

            % Complete ad hoc...
            y = parentSize(4) - MARGIN(4) - (componentHeight/3);

            
            % Set positions:
            obj.AutoCompleteWidget.Position = [x(1), y(1), w(1), componentHeight(1)];
            obj.AddTaskButton.Position = [x(2), y(2), w(2), componentHeight(2)];
            obj.BrowseTaskFunctionButton.Position = [x(3), y(3), w(3), componentHeight(3)];
            
            obj.UITable.Position = [MARGIN(1:2), ...
                totalWidth, y(1) - sum(MARGIN([2,4])) - 10]; % Substract 10 to not interfere with button tooltips...Yeah, i know...
            
            [~, colWidth] = uim.utility.layout.subdividePosition(1, ...
                totalWidth, obj.PreferredColumnWidth, 0);

            colWidth = max( [colWidth; obj.MinimumColumnWidth] );

            obj.UITable.ColumnPreferredWidth = colWidth;
            %obj.UITable.ColumnWidth = [40, 100, 100, 100];
            
            obj.HintTextbox.Position = [MARGIN(1), sum(obj.UITable.Position([2,4])) + 15];
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
            
            % Create search dialog
            variableNames = obj.NWBConfigurationData.AllVariableNames;
            
            obj.AutoCompleteWidget = uics.searchAutoCompleteInputDlg(obj.Parent, variableNames);
            obj.AutoCompleteWidget.PromptText = 'Search for variable to add';
            
            % Create buttons
            buttonProps = {'Style', uim.style.buttonLightMode, ...
                'HorizontalTextAlignment', 'center'};
            
            obj.AddTaskButton = uim.control.Button_(obj.Parent, 'Text', 'Add', buttonProps{:});
            obj.AddTaskButton.Tooltip = 'Add data variable to configuration';
            obj.AddTaskButton.TooltipYOffset = 10;
            obj.BrowseTaskFunctionButton = uim.control.Button_(obj.Parent, 'Text', 'Browse', buttonProps{:});
            %obj.BrowseTaskFunctionButton.Tooltip = 'Browse to find function';
            obj.BrowseTaskFunctionButton.TooltipYOffset = 10;
            
            obj.AddTaskButton.Callback = @obj.onAddTaskButtonPushed;
            obj.BrowseTaskFunctionButton.Callback = @obj.onBrowseFunctionButtonPushed;
            
            uicc = getappdata(obj.Parent, 'UIComponentCanvas');
            obj.HintTextbox = text(uicc.Axes, 1,1, '');
            obj.HintTextbox.String = 'Hint: Search in the above dropdown to add more variables';
            obj.HintTextbox.HorizontalAlignment = 'left';
            obj.HintTextbox.FontSize = 10;
            %obj.HintTextbox.BackgroundColor = 'none';
            % Create table
            obj.UITable  = uim.widget.StylableTable('Parent', obj.Parent, ...
                        'RowHeight', 25, ...
                        'FontSize', 8, ...
                        'FontName', 'helvetica', ...
                        'FontName', 'avenir next', ...
                        'Theme', uim.style.tableLight, ...
                        'Units', 'pixels' );
                    
            obj.UITable.CellEditCallback = @obj.onTableCellEdited;
            obj.UITable.MouseClickedCallback = @obj.onTableCellClicked;
            obj.UITable.CellSelectionCallback = @obj.onTableCellSelected;
            obj.UITable.KeyPressFcn = @obj.onKeyPressedInTable;

            addlistener(obj.UITable, 'MouseMotion', @obj.onMouseMotionOnTable);
            %addlistener(obj.UITable, 'KeyPress', @obj.onKeyPressedInTable);
        end
        
        function createContextMenus(obj)
            hFigure = ancestor(obj.Parent, 'figure');
            obj.TableContextMenu = uicontextmenu(hFigure);
            mitem = uimenu(obj.TableContextMenu, 'Text', 'Remove Task');
            mitem.Callback = @obj.onRemoveTaskMenuItemClicked;
        end
    end

    methods % Set/get
        
        function set.TableDataCurrent(obj, newValue)
            obj.Data = newValue;
            obj.onTableDataCurrentSet()
        end

        function value = get.TableDataCurrent(obj)
            value = obj.Data;
        end
    end
    
    methods (Access = private) % Component and user invoked callbacks
        
        function onKeyPressedInTable(obj, src, evt)
            
            switch evt.Key
                case {'backspace', '⌫'}
                    selectedRow = obj.UITable.SelectedRows;
                    if ~isempty(selectedRow)
                        obj.removeTask(selectedRow)
                    end
            end
            
        end

        function onTableDataCurrentSet(obj)

            isInitialized = ~isempty(obj.UITable.DataTable);
            
            % Reformat table data before assigning.
            metadataColumnData = obj.TableDataCurrent.DefaultMetadata;
            
            % Convert metadata struct to a display string
            isEmpty = cellfun(@(c) isempty(c), metadataColumnData);
            [metadataColumnData{isEmpty}] = deal('<Unconfigured>');
            [metadataColumnData{~isEmpty}] = deal('<Customized>');

            converterColumnData = obj.TableDataCurrent.Converter;
            converterNames = utility.string.getSimpleClassName(converterColumnData);

            tableDataDisplay = obj.TableDataCurrent;
            tableDataDisplay.DefaultMetadata = metadataColumnData;
            tableDataDisplay.Converter = converterNames;

            % Set the DataTable for display
            obj.UITable.DataTable = tableDataDisplay;

            if ~isInitialized
                        
                numRows = size(obj.TableDataCurrent, 1);

                % Update the column formatting properties
                obj.UITable.ColumnFormat = {'char', 'char', 'popup', 'popup', 'popup', 'popup', 'char'};

                nwbModules = obj.NWB_MODULES;
                [~, neuroDataTypes] = enumeration( 'nansen.module.nwb.enum.NeuroDataType' );
                [~, groupNames] = enumeration( 'nansen.module.nwb.enum.PrimaryGroupName' );

                colFormatData = {[], [], groupNames, nwbModules, neuroDataTypes, [{''}; obj.NWBConverters.keys()], []};

                obj.UITable.ColumnFormatData = colFormatData;

                columnNames = obj.TableDataCurrent.Properties.VariableNames;
                numColumns = numel(columnNames);

                isEditable = true(1, numColumns);
                isEditable( strcmp(columnNames, 'VariableName') ) = false;
                isEditable( strcmp(columnNames, 'DefaultMetadata') ) = false;
                obj.UITable.ColumnEditable = isEditable;
            end
        end
        
        function onTableCellEdited(obj, src, evt)
        %onTableCellEdited Callback for table cell edits..
            
            rowNumber = evt.Indices(1);
            colNumber = evt.Indices(2);
            columnName = obj.getColumnName(colNumber);

            newValue = evt.NewValue;

            switch columnName
                case 'NeuroDataType'
                    % Check if metadata is set for current type and ask
                    % user if they really want to change the neurodata type.
                    if ~isempty( obj.TableDataCurrent.DefaultMetadata{rowNumber} )
    
                        % Ask if user want to reset metadata for this variable
                        message = sprintf('Changing %s will reset metadata for this variable. Continue?', columnName);
                        answer = questdlg( message, 'Confirm Change', 'Yes', 'No', 'Yes' );
                        switch answer
                            case 'Yes'
                                obj.TableDataCurrent{rowNumber, 'DefaultMetadata'} = {struct.empty};
                            case 'No'
                                % This should be a method, i.e
                                % resetNeuroDataType, and that should
                                % trigger the question above...
                                obj.TableDataCurrent{rowNumber, colNumber} = {evt.OldValue};
                                return
                        end
                    end

                case 'NwbModule'
                    obj.updateNeurodataTypeSelectionDropdown(rowNumber)
                    % Reset value for neurodata type
                    obj.TableDataCurrent{rowNumber, 'NeuroDataType'} = {''};

                case 'Converter'
                    if ~isempty(newValue)
                        newValue = obj.NWBConverters{{newValue}};
                    end
                otherwise
                    % pass
            end

            obj.TableDataCurrent{rowNumber, colNumber} = {newValue};
            return
            % Do we need to rearrange rows?
            % switch evt.Indices(2) % Column numbers..
            % 
            %     case 1 % Column showing task numbers
            %         obj.rearrangeRows(src, evt)
            % 
            %     case 4 % Column showing option presets
            %         obj.TableDataCurrent{evt.Indices(1), evt.Indices(2)} = {evt.NewValue};
            % end
        end

        function onTableCellClicked(obj, src, evt)
  
            if evt.Button == 3 || strcmp(evt.SelectionType, 'alt')
                obj.onMouseRightClickedInTable(src, evt)
            elseif strcmp(evt.SelectionType, 'open')
                obj.onTableCellDoubleClicked(src, evt)
            end

        end

        function onTableCellDoubleClicked(obj, src, evt)
            rowNumber = evt.Cell(1);
            columnNumber = evt.Cell(2);

            columnName = obj.getColumnName( columnNumber );

            if strcmp(columnName, 'DefaultMetadata') %column == 6
                obj.uiEditMetadata(rowNumber)
            end
        end
        
        function onTableCellSelected(obj, src, evt)
                         
            colNum = obj.UITable.JTable.getSelectedColumns() + 1;
            rowNum = evt.SelectedRows;
            
            if colNum == 4
                obj.dropdownOpen = true;
            else
                obj.dropdownOpen = false;
            end
            
            
            %cellRenderer = obj.UITable.JTable.getCellRenderer(rowNum-1,colNum-1);
            
            %mPos = java.awt.Point(x,y)
            
            %obj.UITable.JTable.getPoint(rowNum, colNum)
            %obj.UiMenuA.Visible = 'on';
            %colNum = evt.Cell(2);
            
        end
        
        function onMouseRightClickedInTable(obj, src, evt)
            
            % Get row where mouse press ocurred.
            row = evt.Cell(1);

            % Select row where mouse is pressed if it is not already
            % selected
            if ~ismember(row, obj.UITable.SelectedRows)
                obj.UITable.SelectedRows = row;
            end

            % Get scroll positions in table
            xScroll = obj.UITable.JScrollPane.getHorizontalScrollBar().getValue();
            yScroll = obj.UITable.JScrollPane.getVerticalScrollBar().getValue();

            % Get position where mouseclick occured (in figure)
            clickPosX = evt.Position(1) - xScroll;
            clickPosY = evt.Position(2) - yScroll;

            % Open context menu for table
            if ~isempty(obj.TableContextMenu)
                obj.openTableContextMenu(clickPosX, clickPosY);
            end
        end
        
        function onMouseMotionOnTable(obj, src, evt)

            persistent previousRow
            if isempty(previousRow); previousRow = 0; end
            
            rowNum = evt.Cell(1);
            colNum = evt.Cell(2);

            if rowNum ~= previousRow && rowNum ~= 0                
                obj.updateNeurodataTypeSelectionDropdown(rowNum)
                previousRow = rowNum;
            end

            obj.updateTableTooltip(rowNum, colNum)
        end
        
        function rearrangeRows(obj, hTable, eventData)
        %rearrangeRows Rearrange table rows in response to user input
        
            data = obj.UITable.DataTable;
            rowData = data(eventData.OldValue,:);
            data(eventData.OldValue,:) = [];

            data = utility.insertRowInTable(data, rowData, eventData.NewValue);

            numRows = size(data,1);
            for i = 1:numRows
                data{i, 1} = uint8(i);
            end
        
            obj.UITable.DataTable = data;
            obj.TableDataCurrent = data;
        end

        function updateRowOrder(obj)
        %updateRowOrder Update order of rows in list. 
        %
        %   Useful when rows are removed.
        
            data = obj.UITable.DataTable;
            numRows = size(data,1);
            for i = 1:numRows
                data{i, 1} = uint8(i);
            end
            
            obj.TableDataCurrent = data;
            %obj.UITable.DataTable = data;
            
            % Update the items in the dropdown on the first row.
            % obj.UITable.ColumnFormatData{1} = arrayfun(@(x) uint8(x), 1:numRows, 'uni',0);

        end
        
        function onAddTaskButtonPushed(obj, src, evt)
            
            % Retrieve current task name from autocomplete field.
            errordlg('')
            % retrieve task object from task catalog
            
            % create a table data row
            
            % Add to table..
            % obj.addTask()
        end
        
        function onBrowseFunctionButtonPushed(obj, src, evt)
        %onBrowseFunctionButtonPushed Callback for browse button
        
            % Open uigetfile in nansen (filter for .m files)
            fileSpec = {  '*.m', 'M Files (*.mat)'; ...
                            '*', 'All Files (*.*)' };
            
            [filename, folder] = uigetfile(fileSpec, 'Find Session Method');
            
            if filename == 0; return; end
            
            % Get full filepath. return if 0
            
            filePath = fullfile(folder, filename);
            
            %Todo: make sure function is on path....
            % IS this relevant for this class?
            % % S = obj.SessionMethodCatalog.addSessionMethodFromPath(filePath);

            % Update autocomplete widget.
            obj.AutoCompleteWidget.Items{end+1} = S.FunctionName;
            obj.AutoCompleteWidget.Value = S.FunctionName;
            
            
            % Store:
            %   - filepath
            %   - package+function name
            %   - function name
            
            % Save to taskCatalog
            % Add to search list
            % Set as current string
            
            
        end
        
        function onRemoveTaskMenuItemClicked(obj, src, evt)
            rowNumber = obj.UITable.SelectedRows;
            
            if ~isempty(rowNumber)
                obj.removeTask(rowNumber)
            end

        end
        
    end
    
    methods (Access = private) % Internal methods
        function columnName = getColumnName(obj, columnNumber )
            columnNames = obj.TableDataCurrent.Properties.VariableNames;
            columnName = columnNames{columnNumber};
        end

        function updateTableTooltip(obj, rowNumber, columnNumber)

            persistent prevRow prevCol
            
            thisRow = rowNumber;
            thisCol = columnNumber;
            
            if thisRow == 0 || thisCol == 0
                return
            end
            
            if isequal(prevRow, thisRow) && isequal(prevCol, thisCol)
                % Skip tooltip update if mouse pointer is still on previous cell
                return
            else
                prevRow = thisRow;
                prevCol = thisCol;
            end

            if strcmp(obj.getColumnName(columnNumber), 'NeuroDataType')
                str = obj.getNeuroDataTypeTooltip(rowNumber);
            else
                str = '';
            end

            set(obj.UITable.JTable, 'ToolTipText', str)
        end
    
        function str = getNeuroDataTypeTooltip(obj, rowNumber)
            
            import nansen.module.nwb.internal.schemautil.getTypesForModule

            persistent descriptionMap
            if isempty(descriptionMap); descriptionMap = dictionary; end

            str = '';
            neurodataType = obj.TableDataCurrent.NeuroDataType{rowNumber};
            if isempty(neurodataType); return; end

            if ~descriptionMap.isConfigured() || ~descriptionMap.isKey(neurodataType)
                % Get nwb module from column
                nwbModuleName = obj.TableDataCurrent.NwbModule{rowNumber};
                if isempty(nwbModuleName); return; end
    
                [neuroDataTypes, descriptions] = getTypesForModule(nwbModuleName);
                descriptionMap(neuroDataTypes) = descriptions;
            end
            try
                str = descriptionMap(neurodataType);
            catch
                disp('a')
            end
            str = utility.string.foldStr(str, 100);

            str = strrep(str, newline, '<br/>');
            str = sprintf('<html><div align="left"> %s </div>', str);
        end
    end

    methods (Access = private) % Actions
        
        function addTask(obj, newTask)
            
            functionName = obj.AutoCompleteWidget.Value;
            
            if isempty(functionName); return; end
            
            % Find in sessionMethodCatalog
            sMethodItem = obj.SessionMethodCatalog.getItem(functionName);
            
            % Create task...
            task = nansen.pipeline.PipelineCatalog.getTask();
            task.TaskNum = uint8( size(obj.TableDataCurrent, 1) ) + 1;
            task.TaskName = sMethodItem.FunctionAlias;
            task.TaskFunction = sMethodItem.FunctionName;
            task.OptionPresetSelection = sMethodItem.OptionsAlternatives{1};
            
            % Initialize task table, or add task to existing table.
            taskAsTable = struct2table(task, 'AsArray', true);
            if isempty(obj.TableDataCurrent)
                obj.TableDataCurrent = taskAsTable;
            else
                obj.TableDataCurrent(end+1,:) = struct2table(task, 'AsArray', true);
            end
            
            
            if size(obj.TableDataCurrent, 1) == 1
                obj.updateOptionSelectionDropdown(1)
            end
            
            fprintf('Added task %s\n', obj.AutoCompleteWidget.Value)
            
            % Update task numbers
            obj.updateRowOrder()
        end
        
        function removeTask(obj, rowIdx)
            variableName = obj.TableDataCurrent{rowIdx, 'VariableName'};
            if iscell(variableName); variableName = variableName{1}; end
            obj.TableDataCurrent(rowIdx, :) = [];
            fprintf('Removed variable %s\n', variableName)

            % Update task numbers
            % obj.updateRowOrder()
        end
        
        function openTableContextMenu(obj, x, y)
            
            if isempty(obj.TableContextMenu); return; end
            
            % This is now corrected for in caller function...
            tablePosition = getpixelposition(obj.UITable, true);
            tableLocationX = tablePosition(1) + 1; % +1 because ad hoc...
            tableHeight = tablePosition(4);
            
            cMenuPos = [tableLocationX + x, tableHeight - y + 15]; % +15 because ad hoc...
                        
            % Set position and make menu visible.
            obj.TableContextMenu.Position = cMenuPos;
            obj.TableContextMenu.Visible = 'on';
            
        end
        
        function updateNeurodataTypeSelectionDropdown(obj, rowNumber)
        %updateOptionSelectionDropdown Update table columnformatdata to
        %show options alternatives for current row.
        
            import nansen.module.nwb.internal.schemautil.getTypesForModule

            % Get nwb module from column
            nwbModuleName = obj.TableDataCurrent.NwbModule{rowNumber};
            if isempty(nwbModuleName); return; end
            %disp(nwbModuleName)
            
            neuroDataTypes = getTypesForModule(nwbModuleName);
            
            % Todo: Should this filtering be included in function above?
            metadataTypes = nansen.module.nwb.internal.lookup.getMetadataClassNames();
            abstractTypes = nansen.module.nwb.internal.lookup.getAbstractClassNames();
            neuroDataTypes = setdiff(neuroDataTypes, metadataTypes);
            neuroDataTypes = setdiff(neuroDataTypes, abstractTypes);

            isColumn = strcmp( obj.TableDataCurrent.Properties.VariableNames, 'NeuroDataType');

            % % fcnName = obj.UITable.Data{rowNumber, 3};
            % % isMatch = strcmp({obj.SessionMethodCatalog.Data.FunctionName}, fcnName);
            % % 
            obj.UITable.ColumnFormatData{isColumn} = cellstr( neuroDataTypes );
        end
    
        function uiEditMetadata(obj, rowNumber)

            neuroDataType = obj.TableDataCurrent{rowNumber, 'NeuroDataType'}{1};
            varName = obj.TableDataCurrent{rowNumber, 1}{1};
            
            if isempty(neuroDataType)
                errordlg('Please select a Neurodata Type for this variable in order to edit metadata', 'Neurodata Type Not Selected')
                return
            end

            nwbClassName = nansen.module.nwb.internal.lookup.getFullTypeName(neuroDataType);
            %nwbClassName = sprintf( 'types.core.%s', neuroDataType );
            [S, info, isRequired] = nansen.module.nwb.internal.getTypeMetadataStruct(nwbClassName);
            
            if ~isempty( obj.TableDataCurrent{rowNumber, 'DefaultMetadata'}{1} )
                S = obj.TableDataCurrent{rowNumber, 'DefaultMetadata'}{1};
            end

            % Need to add this after we load metadata, because the
            % saved user instances might have been updated since
            % default metadata was last edited
            S = nansen.module.nwb.internal.addLinkedTypeInstances(S, nwbClassName);

            [S, wasAborted] = tools.editStruct(S, 'all', 'Edit Default Metadata', ...
                'Prompt', sprintf('Edit metadata for %s (%s)', varName, neuroDataType), ...
                'DataTips', info, ...
                'ValueChangedFcn', @obj.onValueChanged);
            
            if ~wasAborted
                % Update table
                obj.TableDataCurrent{rowNumber, 'DefaultMetadata'} = {S};
            end
        end

        function onValueChanged(obj, src, evt)
            % Todo: should not be part of this class
            %disp('a')
        end
    end
    
end
