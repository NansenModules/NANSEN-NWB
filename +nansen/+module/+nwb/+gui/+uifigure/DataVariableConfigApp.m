classdef DataVariableConfigApp < handle
%DataVariableConfigApp Modern uifigure app for NWB data variable config.

    properties (Constant, Access = private)
        MINIMUM_MATLAB_VERSION = '24.1' % R2024a

        COLUMN_NAMES = { ...
            'VariableName', ...
            'NWBVariableName', ...
            'PrimaryGroupName', ...
            'NwbModule', ...
            'NeuroDataType', ...
            'Converter', ...
            'DefaultMetadata' }

        COLUMN_INDEX = struct( ...
            'VariableName', 1, ...
            'NWBVariableName', 2, ...
            'PrimaryGroupName', 3, ...
            'NwbModule', 4, ...
            'NeuroDataType', 5, ...
            'Converter', 6, ...
            'DefaultMetadata', 7)

        SELECT_GROUP_LABEL = '<Select a group>'
        SELECT_MODULE_LABEL = '<Select an NWB module>'
        SELECT_NEURODATA_LABEL = '<Select a neurodata type>'
        DEFAULT_CONVERTER_LABEL = 'Default'
    end

    properties (SetAccess = private)
        Data table
        FilePath (1,1) string = missing
    end

    properties (Dependent, SetAccess = private)
        IsDirty logical
    end

    properties (Access = private)
        Figure matlab.ui.Figure
        Table
        VariableDropdown matlab.ui.control.DropDown
        AddButton matlab.ui.control.Button
        AddManyButton matlab.ui.control.Button
        SaveButton matlab.ui.control.Button
        SaveCloseButton matlab.ui.control.Button
        OriginalData table
        NWBConverters
        VariableNames (1,:) string = strings(1, 0)
        NWBConfigurationData
    end

    methods
        function obj = DataVariableConfigApp(nwbConfigurationData, options)
            arguments
                nwbConfigurationData
                options.FilePath (1,1) string = missing
                options.Visible (1,1) matlab.lang.OnOffSwitchState = "on"
            end

            obj.assertModernUiSupport()
            obj.assertWidgetTableSupport()

            obj.NWBConfigurationData = nwbConfigurationData;
            obj.FilePath = options.FilePath;
            obj.VariableNames = obj.getAvailableVariableNames(nwbConfigurationData);
            obj.NWBConverters = obj.listConverters();
            obj.Data = obj.createDataTable(nwbConfigurationData);
            obj.OriginalData = obj.Data;

            obj.createComponents(options.Visible)
            obj.renderTable()

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
            tf = ~isequaln(obj.Data, obj.OriginalData);
        end

        function addVariable(obj, variableName)
        %addVariable Add one data variable to the configuration.
            arguments
                obj
                variableName (1,1) string = string(obj.VariableDropdown.Value)
            end

            variableName = strtrim(variableName);
            if variableName == ""
                return
            end

            obj.assertKnownVariable(variableName)

            newItem = nansen.module.nwb.file.getDefaultFileConfigurationItem();
            newItem.VariableName = char(variableName);
            newItem.NWBVariableName = char(variableName);

            newRow = obj.createDataTable(struct('DataItems', newItem));
            obj.Data = [obj.Data; newRow];

            displayRow = obj.createDisplayTable(newRow);
            if isempty(obj.Table.Data)
                obj.Table.addRow(displayRow)
            else
                obj.Table.addRow(displayRow)
            end

            obj.applyNeuroDataTypeOptions(height(obj.Data))
        end

        function setCellValue(obj, rowIndex, columnName, value)
        %setCellValue Programmatically update one data cell.
            arguments
                obj
                rowIndex (1,1) double {mustBeInteger, mustBePositive}
                columnName (1,1) string
                value
            end

            obj.assertValidDataCell(rowIndex, columnName)
            previousValue = obj.getDisplayValue(rowIndex, columnName);
            obj.applyCellEdit(rowIndex, columnName, value, previousValue, false)

            if ~isempty(obj.Table) && ~isempty(obj.Table.Data)
                displayValue = obj.getDisplayValue(rowIndex, columnName);
                obj.Table.updateCellValue(rowIndex, obj.getColumnIndex(columnName), displayValue)
            end
        end

        function saveNwbConfigurationData(obj)
        %saveNwbConfigurationData Save only DataItems back to the config file.
            if ismissing(obj.FilePath)
                error('NansenNwb:MissingFilePath', ...
                    'FilePath is required for saving the NWB configuration.')
            end
            if ~isfile(obj.FilePath)
                error('NansenNwb:FileNotFound', ...
                    'NWB configuration file does not exist: %s', obj.FilePath)
            end

            fileData = load(obj.FilePath, 'nwbConfigurationData');
            if isfield(fileData, 'nwbConfigurationData')
                nwbConfigurationData = fileData.nwbConfigurationData;
            else
                nwbConfigurationData = obj.NWBConfigurationData;
            end

            nwbConfigurationData.DataItems = table2struct(obj.Data);
            save(obj.FilePath, 'nwbConfigurationData')

            obj.NWBConfigurationData = nwbConfigurationData;
            obj.OriginalData = obj.Data;
        end

        function markClean(obj)
            obj.OriginalData = obj.Data;
        end
    end

    methods (Access = private)
        function createComponents(obj, visibleState)
            obj.Figure = uifigure( ...
                'Name', 'NWB Data Variable Configurator', ...
                'Position', [100, 100, 1050, 620], ...
                'Visible', visibleState);
            obj.Figure.CloseRequestFcn = @(~, ~) obj.onFigureCloseRequested();

            rootGrid = uigridlayout(obj.Figure, [4, 1]);
            rootGrid.RowHeight = {40, 20, '1x', 50};
            rootGrid.ColumnWidth = {'1x'};
            rootGrid.Padding = [18, 16, 18, 16];
            rootGrid.RowSpacing = 8;

            controlGrid = uigridlayout(rootGrid, [1, 3]);
            controlGrid.Layout.Row = 1;
            controlGrid.ColumnWidth = {'1x', 80, 110};
            controlGrid.RowHeight = {'1x'};
            controlGrid.Padding = [0, 0, 0, 0];
            controlGrid.ColumnSpacing = 10;

            variableDropdownItems = cellstr(obj.VariableNames);
            if isempty(variableDropdownItems)
                variableDropdownItems = {''};
            end

            obj.VariableDropdown = uidropdown(controlGrid, ...
                'Items', variableDropdownItems, ...
                'Editable', 'on', ...
                'Tooltip', 'Select or type a data variable to add');
            obj.VariableDropdown.Layout.Column = 1;

            obj.AddButton = uibutton(controlGrid, ...
                'Text', 'Add', ...
                'ButtonPushedFcn', @(~, ~) obj.onAddButtonPushed());
            obj.AddButton.Layout.Column = 2;

            obj.AddManyButton = uibutton(controlGrid, ...
                'Text', 'Add Many...', ...
                'ButtonPushedFcn', @(~, ~) obj.onAddManyButtonPushed());
            obj.AddManyButton.Layout.Column = 3;

            hintLabel = uilabel(rootGrid, ...
                'Text', 'Search above to add data variables to the NWB configuration.', ...
                'FontSize', 11);
            hintLabel.Layout.Row = 2;

            obj.Table = WidgetTable(rootGrid, ...
                'EnableAddRows', 'off', ...
                'ShowColumnHeaderHelp', 'off', ...
                'HeaderBackgroundColor', '#FFFFFF', ...
                'HeaderForegroundColor', '#002054', ...
                'HeaderTextColor', '#002054', ...
                'BackgroundColor', 'white');
            obj.Table.Layout.Row = 3;
            obj.Table.ColumnNames = obj.COLUMN_NAMES;
            obj.Table.ColumnWidth = {150, 150, 160, 180, 190, 160, 170};
            obj.Table.MinimumColumnWidth = [120, 120, 140, 150, 160, 130, 150];
            obj.Table.MaximumColumnWidth = [240, 240, 240, 280, 300, 240, 260];
            obj.Table.RowHeight = 32;
            obj.Table.RowSpacing = 8;
            obj.Table.CellEditedFcn = @obj.onTableCellEdited;
            obj.Table.ColumnWidget = { ...
                @obj.createReadOnlyTextCell, ...
                [], ...
                @(parent) obj.createDropdown(parent, obj.getPrimaryGroupOptions()), ...
                @(parent) obj.createDropdown(parent, obj.getNwbModuleOptions()), ...
                @obj.createNeuroDataTypeDropdown, ...
                @(parent) obj.createDropdown(parent, obj.getConverterOptions()), ...
                @obj.createMetadataCell };

            footerGrid = uigridlayout(rootGrid, [1, 4]);
            footerGrid.Layout.Row = 4;
            footerGrid.ColumnWidth = {'1x', 180, 180, '1x'};
            footerGrid.RowHeight = {'1x'};
            footerGrid.Padding = [0, 6, 0, 0];
            footerGrid.ColumnSpacing = 12;

            obj.SaveButton = uibutton(footerGrid, ...
                'Text', 'Save', ...
                'ButtonPushedFcn', @(~, ~) obj.onSaveButtonPushed());
            obj.SaveButton.Layout.Column = 2;

            obj.SaveCloseButton = uibutton(footerGrid, ...
                'Text', 'Save & Close', ...
                'ButtonPushedFcn', @(~, ~) obj.onSaveCloseButtonPushed());
            obj.SaveCloseButton.Layout.Column = 3;
        end

        function renderTable(obj)
            displayTable = obj.createDisplayTable(obj.Data);
            if ~isempty(displayTable)
                obj.Table.Data = displayTable;
                for iRow = 1:height(displayTable)
                    obj.applyNeuroDataTypeOptions(iRow)
                end
            end
        end

        function onAddButtonPushed(obj)
            obj.runUiAction(@() obj.addVariable(string(obj.VariableDropdown.Value)))
        end

        function onAddManyButtonPushed(obj)
            obj.runUiAction(@() obj.addManyVariables())
        end

        function onSaveButtonPushed(obj)
            obj.runUiAction(@() obj.saveAndNotify(false))
        end

        function onSaveCloseButtonPushed(obj)
            obj.runUiAction(@() obj.saveAndNotify(true))
        end

        function onTableCellEdited(obj, ~, evt)
            obj.runUiAction(@() obj.applyCellEdit( ...
                evt.Indices(1), string(evt.ColumnName), ...
                evt.NewData, evt.PreviousData, true))
        end

        function onFigureCloseRequested(obj)
            if obj.IsDirty
                answer = uiconfirm(obj.Figure, ...
                    'Save changes to the NWB data variable configuration?', ...
                    'Confirm Close', ...
                    'Options', {'Save', 'Discard', 'Cancel'}, ...
                    'DefaultOption', 'Save', ...
                    'CancelOption', 'Cancel');

                switch answer
                    case 'Save'
                        obj.saveNwbConfigurationData()
                    case 'Discard'
                        % Close without saving.
                    otherwise
                        return
                end
            end

            delete(obj.Figure)
        end

        function addManyVariables(obj)
            selectedNames = obj.selectMultipleVariables();
            for i = 1:numel(selectedNames)
                obj.addVariable(selectedNames(i))
            end
        end

        function selectedNames = selectMultipleVariables(obj)
            selectedNames = strings(1, 0);
            if isempty(obj.VariableNames)
                uialert(obj.Figure, ...
                    'No data variables are available to add.', ...
                    'No Variables Available', ...
                    'Icon', 'warning')
                return
            end

            dlg = uifigure( ...
                'Name', 'Add Variables', ...
                'WindowStyle', 'modal', ...
                'Position', obj.getCenteredDialogPosition([360, 460]));

            cleanupObj = onCleanup(@() obj.deleteFigureIfValid(dlg));

            grid = uigridlayout(dlg, [3, 1]);
            grid.RowHeight = {'1x', 1, 38};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12, 12, 12, 12];

            listBox = uilistbox(grid, ...
                'Items', cellstr(obj.VariableNames), ...
                'Multiselect', 'on');
            listBox.Layout.Row = 1;

            buttonGrid = uigridlayout(grid, [1, 3]);
            buttonGrid.Layout.Row = 3;
            buttonGrid.ColumnWidth = {'1x', 90, 90};
            buttonGrid.RowHeight = {'1x'};
            buttonGrid.Padding = [0, 0, 0, 0];

            cancelButton = uibutton(buttonGrid, ...
                'Text', 'Cancel', ...
                'ButtonPushedFcn', @(~, ~) uiresume(dlg));
            cancelButton.Layout.Column = 2;

            confirmButton = uibutton(buttonGrid, ...
                'Text', 'Add', ...
                'ButtonPushedFcn', @(~, ~) onConfirm());
            confirmButton.Layout.Column = 3;

            uiwait(dlg)

            function onConfirm()
                selectedNames = string(listBox.Value);
                uiresume(dlg)
            end
        end

        function applyCellEdit(obj, rowIndex, columnName, newValue, previousValue, confirmMetadataReset)
            columnName = string(columnName);
            newValue = obj.normalizeDisplayValue(newValue);

            switch columnName
                case "NwbModule"
                    obj.setDataValue(rowIndex, "NwbModule", newValue)
                    obj.setDataValue(rowIndex, "NeuroDataType", obj.SELECT_NEURODATA_LABEL)
                    obj.applyNeuroDataTypeOptions(rowIndex)

                case "NeuroDataType"
                    if confirmMetadataReset && obj.hasMetadata(rowIndex)
                        answer = uiconfirm(obj.Figure, ...
                            'Changing NeuroDataType will reset metadata for this variable. Continue?', ...
                            'Confirm Change', ...
                            'Options', {'Yes', 'No'}, ...
                            'DefaultOption', 'Yes', ...
                            'CancelOption', 'No');

                        if ~strcmp(answer, 'Yes')
                            obj.Table.updateCellValue(rowIndex, obj.COLUMN_INDEX.NeuroDataType, previousValue)
                            return
                        end
                    end

                    obj.setDataValue(rowIndex, "NeuroDataType", newValue)
                    obj.setDataValue(rowIndex, "DefaultMetadata", struct.empty)
                    obj.updateMetadataCell(rowIndex)

                case "Converter"
                    obj.setDataValue(rowIndex, "Converter", obj.resolveConverterName(newValue))

                case "DefaultMetadata"
                    % Metadata is edited via the per-row button.

                otherwise
                    obj.setDataValue(rowIndex, columnName, newValue)
            end
        end

        function saveAndNotify(obj, doClose)
            obj.saveNwbConfigurationData()

            if doClose
                delete(obj.Figure)
            else
                uialert(obj.Figure, ...
                    'NWB data variable configuration saved successfully.', ...
                    'Save Successful', ...
                    'Icon', 'success')
            end
        end

        function runUiAction(obj, actionFcn)
            try
                actionFcn()
            catch exception
                if ~isempty(obj.Figure) && isvalid(obj.Figure)
                    uialert(obj.Figure, exception.message, 'NWB Configuration Error', ...
                        'Icon', 'error')
                else
                    rethrow(exception)
                end
            end
        end

        function hControl = createReadOnlyTextCell(~, parent)
            hControl = uieditfield(parent, ...
                'Editable', 'off', ...
                'BackgroundColor', [0.96, 0.96, 0.96]);
        end

        function hControl = createDropdown(~, parent, items)
            hControl = uidropdown(parent, ...
                'Items', cellstr(items));
        end

        function hControl = createNeuroDataTypeDropdown(obj, parent)
            rowIndex = parent.Layout.Row;
            hControl = uidropdown(parent, ...
                'Items', cellstr(obj.getNeuroDataTypeOptions(rowIndex)));
        end

        function hControl = createMetadataCell(obj, parent)
            rowIndex = parent.Layout.Row;

            hControl = uigridlayout(parent, [1, 2]);
            hControl.ColumnWidth = {'1x', 58};
            hControl.RowHeight = {'1x'};
            hControl.ColumnSpacing = 6;
            hControl.Padding = [0, 0, 0, 0];
            hControl.BackgroundColor = 'white';

            statusLabel = uilabel(hControl, ...
                'Text', obj.getMetadataStatus(rowIndex), ...
                'Tag', 'MetadataStatusLabel', ...
                'FontSize', 11);
            statusLabel.Layout.Column = 1;

            editButton = uibutton(hControl, ...
                'Text', 'Edit...', ...
                'ButtonPushedFcn', @(~, ~) obj.onEditMetadataButtonPushed(rowIndex));
            editButton.Layout.Column = 2;
        end

        function onEditMetadataButtonPushed(obj, rowIndex)
            obj.runUiAction(@() obj.editMetadata(rowIndex))
        end

        function editMetadata(obj, rowIndex)
            neuroDataType = string(obj.getDataValue(rowIndex, "NeuroDataType"));
            if obj.isPlaceholder(neuroDataType, "NeuroDataType")
                uialert(obj.Figure, ...
                    'Please select a NeuroDataType before editing metadata.', ...
                    'NeuroDataType Not Selected', ...
                    'Icon', 'warning')
                return
            end

            nwbClassName = nansen.module.nwb.internal.lookup.getFullTypeName(char(neuroDataType));
            [metadataStruct, info] = nansen.module.nwb.internal.getTypeMetadataStruct(nwbClassName);

            currentMetadata = obj.getDataValue(rowIndex, "DefaultMetadata");
            if ~isempty(currentMetadata)
                metadataStruct = currentMetadata;
            end

            metadataStruct = nansen.module.nwb.internal.addLinkedTypeInstances( ...
                metadataStruct, nwbClassName);

            variableName = obj.getDataValue(rowIndex, "VariableName");
            [metadataStruct, wasAborted] = tools.editStruct( ...
                metadataStruct, 'all', 'Edit Default Metadata', ...
                'Prompt', sprintf('Edit metadata for %s (%s)', variableName, neuroDataType), ...
                'DataTips', info);

            if ~wasAborted
                metadataStruct = utility.struct.removeConfigFields(metadataStruct);
                obj.setDataValue(rowIndex, "DefaultMetadata", metadataStruct)
                obj.updateMetadataCell(rowIndex)
            end
        end

        function applyNeuroDataTypeOptions(obj, rowIndex)
            items = obj.getNeuroDataTypeOptions(rowIndex);
            value = string(obj.getDataValue(rowIndex, "NeuroDataType"));
            if ~any(value == items)
                value = items(1);
                obj.setDataValue(rowIndex, "NeuroDataType", value)
            end
            obj.Table.setCellOptions(rowIndex, obj.COLUMN_INDEX.NeuroDataType, items, value)
        end

        function updateMetadataCell(obj, rowIndex)
            hControl = obj.Table.getCellComponent(rowIndex, obj.COLUMN_INDEX.DefaultMetadata);
            statusLabel = findobj(hControl, 'Tag', 'MetadataStatusLabel');
            if ~isempty(statusLabel)
                statusLabel.Text = obj.getMetadataStatus(rowIndex);
            end
        end

        function options = getPrimaryGroupOptions(obj)
            options = string(obj.SELECT_GROUP_LABEL);
            try
                [~, groupNames] = enumeration('nansen.module.nwb.enum.PrimaryGroupName');
                options = [options, string(groupNames(:)')];
            catch
                % Keep the placeholder if enum metadata is unavailable.
            end
        end

        function options = getNwbModuleOptions(obj)
            options = string(obj.SELECT_MODULE_LABEL);
            try
                moduleNames = nansen.module.nwb.internal.schemautil.getNwbModules();
                options = [options, string(moduleNames(:)')];
            catch
                % Keep the placeholder if schema metadata is unavailable.
            end
        end

        function options = getConverterOptions(obj)
            options = string(obj.DEFAULT_CONVERTER_LABEL);
            if isa(obj.NWBConverters, 'containers.Map') && obj.NWBConverters.Count > 0
                options = [options, string(keys(obj.NWBConverters))];
            end
        end

        function options = getNeuroDataTypeOptions(obj, rowIndex)
            currentValue = string(obj.getDataValue(rowIndex, "NeuroDataType"));
            moduleName = string(obj.getDataValue(rowIndex, "NwbModule"));

            if obj.isPlaceholder(moduleName, "NwbModule")
                options = string(obj.SELECT_NEURODATA_LABEL);
            else
                try
                    neuroDataTypes = nansen.module.nwb.internal.schemautil.getTypesForModule(char(moduleName));
                    metadataTypes = nansen.module.nwb.internal.lookup.getMetadataClassNames();
                    abstractTypes = nansen.module.nwb.internal.lookup.getAbstractClassNames();
                    neuroDataTypes = setdiff(neuroDataTypes, metadataTypes);
                    neuroDataTypes = setdiff(neuroDataTypes, abstractTypes);
                    options = string(neuroDataTypes(:)');
                catch
                    options = strings(1, 0);
                end

                if isempty(options)
                    options = string(obj.SELECT_NEURODATA_LABEL);
                end
            end

            if currentValue ~= "" && ~any(currentValue == options)
                options = [options, currentValue];
            end
        end

        function displayTable = createDisplayTable(obj, dataTable)
            displayTable = table();
            if isempty(dataTable)
                return
            end

            displayTable.VariableName = string(dataTable.VariableName);
            displayTable.NWBVariableName = string(dataTable.NWBVariableName);
            displayTable.PrimaryGroupName = string(dataTable.PrimaryGroupName);
            displayTable.NwbModule = string(dataTable.NwbModule);
            displayTable.NeuroDataType = string(dataTable.NeuroDataType);
            displayTable.Converter = obj.getConverterDisplayNames(dataTable.Converter);

            metadataStatus = strings(height(dataTable), 1);
            for iRow = 1:height(dataTable)
                metadataStatus(iRow) = obj.getMetadataStatus(iRow, dataTable);
            end
            displayTable.DefaultMetadata = metadataStatus;
        end

        function dataTable = createDataTable(obj, nwbConfigurationData)
            defaultItem = nansen.module.nwb.file.getDefaultFileConfigurationItem();

            if isfield(nwbConfigurationData, 'DataItems')
                dataItems = nwbConfigurationData.DataItems;
            else
                dataItems = struct.empty;
            end

            if isempty(dataItems)
                dataTable = obj.createEmptyDataTable();
                return
            end

            dataItems = obj.fillMissingDataItemFields(dataItems, defaultItem);
            numRows = numel(dataItems);
            columns = cell(1, numel(obj.COLUMN_NAMES));

            for iColumn = 1:numel(obj.COLUMN_NAMES)
                columnName = obj.COLUMN_NAMES{iColumn};
                columns{iColumn} = cell(numRows, 1);
                for iRow = 1:numRows
                    columns{iColumn}{iRow} = dataItems(iRow).(columnName);
                end
            end

            dataTable = table(columns{:}, 'VariableNames', obj.COLUMN_NAMES);
        end

        function dataTable = createEmptyDataTable(obj)
            columns = repmat({cell(0, 1)}, 1, numel(obj.COLUMN_NAMES));
            dataTable = table(columns{:}, 'VariableNames', obj.COLUMN_NAMES);
        end

        function dataItems = fillMissingDataItemFields(obj, dataItems, defaultItem)
            for i = 1:numel(dataItems)
                for iColumn = 1:numel(obj.COLUMN_NAMES)
                    columnName = obj.COLUMN_NAMES{iColumn};
                    if ~isfield(dataItems, columnName) || isempty(dataItems(i).(columnName))
                        dataItems(i).(columnName) = defaultItem.(columnName);
                    end
                end
            end
        end

        function names = getConverterDisplayNames(obj, converterValues)
            names = strings(numel(converterValues), 1);
            for i = 1:numel(converterValues)
                converterName = string(converterValues{i});
                if converterName == "" || converterName == string(obj.DEFAULT_CONVERTER_LABEL)
                    names(i) = string(obj.DEFAULT_CONVERTER_LABEL);
                else
                    names(i) = obj.getSimpleClassName(converterName);
                end
            end
        end

        function converterName = resolveConverterName(obj, displayName)
            displayName = string(displayName);
            if displayName == "" || displayName == string(obj.DEFAULT_CONVERTER_LABEL)
                converterName = char(obj.DEFAULT_CONVERTER_LABEL);
                return
            end

            if isa(obj.NWBConverters, 'containers.Map') && isKey(obj.NWBConverters, char(displayName))
                converterName = obj.NWBConverters(char(displayName));
            else
                converterName = char(displayName);
            end
        end

        function value = getDataValue(obj, rowIndex, columnName)
            columnName = char(columnName);
            value = obj.Data.(columnName){rowIndex};
        end

        function setDataValue(obj, rowIndex, columnName, value)
            columnName = char(columnName);
            obj.Data.(columnName){rowIndex} = obj.unwrapScalarCell(value);
        end

        function value = getDisplayValue(obj, rowIndex, columnName)
            columnName = string(columnName);
            switch columnName
                case "DefaultMetadata"
                    value = obj.getMetadataStatus(rowIndex);
                case "Converter"
                    value = obj.getConverterDisplayNames(obj.Data.Converter(rowIndex));
                otherwise
                    value = string(obj.getDataValue(rowIndex, columnName));
            end
        end

        function columnIndex = getColumnIndex(obj, columnName)
            columnIndex = find(strcmp(obj.COLUMN_NAMES, char(columnName)), 1);
        end

        function status = getMetadataStatus(obj, rowIndex, dataTable)
            if nargin < 3
                dataTable = obj.Data;
            end

            metadata = dataTable.DefaultMetadata{rowIndex};
            if isempty(metadata)
                status = "<Unconfigured>";
            else
                status = "<Customized>";
            end
        end

        function tf = hasMetadata(obj, rowIndex)
            tf = ~isempty(obj.getDataValue(rowIndex, "DefaultMetadata"));
        end

        function assertKnownVariable(obj, variableName)
            if isempty(obj.VariableNames)
                return
            end

            if ~any(variableName == obj.VariableNames)
                error('NansenNwb:UnknownVariable', ...
                    'Unknown data variable: %s', variableName)
            end
        end

        function assertValidDataCell(obj, rowIndex, columnName)
            if rowIndex > height(obj.Data)
                error('NansenNwb:InvalidRowIndex', ...
                    'Row index exceeds the number of configured data variables.')
            end
            if ~any(strcmp(obj.COLUMN_NAMES, char(columnName)))
                error('NansenNwb:InvalidColumnName', ...
                    'Unknown data variable configuration column: %s', columnName)
            end
        end

        function tf = isPlaceholder(obj, value, columnName)
            value = string(value);
            switch string(columnName)
                case "PrimaryGroupName"
                    tf = value == string(obj.SELECT_GROUP_LABEL);
                case "NwbModule"
                    tf = value == "" || value == string(obj.SELECT_MODULE_LABEL);
                case "NeuroDataType"
                    tf = value == "" || value == string(obj.SELECT_NEURODATA_LABEL);
                otherwise
                    tf = value == "";
            end
        end

        function position = getCenteredDialogPosition(obj, dialogSize)
            figurePosition = obj.Figure.Position;
            position = [ ...
                figurePosition(1) + (figurePosition(3) - dialogSize(1)) / 2, ...
                figurePosition(2) + (figurePosition(4) - dialogSize(2)) / 2, ...
                dialogSize(1), ...
                dialogSize(2)];
        end
    end

    methods (Static, Access = private)
        function assertModernUiSupport()
            if verLessThan('matlab', nansen.module.nwb.gui.uifigure.DataVariableConfigApp.MINIMUM_MATLAB_VERSION)
                error('NansenNwb:UnsupportedMatlabRelease', ...
                    ['The modern NWB data variable configurator requires MATLAB R2024a or newer. ', ...
                     'Use the legacy NWBConfigurator on this release.'])
            end
        end

        function assertWidgetTableSupport()
            if exist('WidgetTable', 'class') ~= 8
                error('NansenNwb:MissingWidgetTable', ...
                    'WidgetTable is required for the modern NWB data variable configurator.')
            end

            requiredMethods = ["setCellOptions", "getCellComponent"];
            availableMethods = string(methods('WidgetTable'));
            isMissing = ~ismember(requiredMethods, availableMethods);
            if any(isMissing)
                error('NansenNwb:UnsupportedWidgetTable', ...
                    'WidgetTable must provide these APIs: %s.', ...
                    strjoin(requiredMethods(isMissing), ', '))
            end
        end

        function variableNames = getAvailableVariableNames(nwbConfigurationData)
            variableNames = strings(1, 0);
            if isfield(nwbConfigurationData, 'AllVariableNames') && ~isempty(nwbConfigurationData.AllVariableNames)
                variableNames = string(nwbConfigurationData.AllVariableNames);
                return
            end

            try
                variableModel = nansen.VariableModel();
                variableNames = string(variableModel.VariableNames);
            catch
                variableNames = strings(1, 0);
            end
        end

        function converterMap = listConverters()
            converterMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
            try
                currentProject = nansen.getCurrentProject();
                nwbConverters = currentProject.listMixins('nwbconverter');
            catch
                return
            end

            baseNames = arrayfun( ...
                @(name) nansen.module.nwb.gui.uifigure.DataVariableConfigApp.getSimpleClassName(name), ...
                string(nwbConverters), 'UniformOutput', false);

            for i = 1:numel(baseNames)
                converterMap(char(baseNames{i})) = char(string(nwbConverters(i)));
            end
        end

        function simpleName = getSimpleClassName(fullName)
            parts = strsplit(char(fullName), '.');
            simpleName = string(parts{end});
        end

        function value = normalizeDisplayValue(value)
            value = nansen.module.nwb.gui.uifigure.DataVariableConfigApp.unwrapScalarCell(value);
            if isstring(value) || ischar(value)
                value = string(value);
            end
        end

        function value = unwrapScalarCell(value)
            if iscell(value) && isscalar(value)
                value = value{1};
            end
        end

        function deleteFigureIfValid(fig)
            if ~isempty(fig) && isvalid(fig)
                delete(fig)
            end
        end
    end
end
