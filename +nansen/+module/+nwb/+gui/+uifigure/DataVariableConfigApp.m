classdef DataVariableConfigApp < handle
%DataVariableConfigApp Modern uifigure app for NWB data variable config.

    properties (Constant, Access = private)
        MINIMUM_MATLAB_VERSION = '24.1' % R2024a

        COLUMN_NAMES = { ...
            'VariableName', ...
            'NWBVariableName', ...
            'ConverterName', ...
            'PrimaryGroup', ...
            'NwbModule', ...
            'TargetNwbType', ...
            'Metadata' }

        DATA_FIELD_NAMES = { ...
            'VariableName', ...
            'NWBVariableName', ...
            'ConverterName', ...
            'TargetNwbType', ...
            'PrimaryGroup', ...
            'NwbModule', ...
            'Metadata', ...
            'ConverterArgs', ...
            'SourceInfo' }

        COLUMN_INDEX = struct( ...
            'VariableName', 1, ...
            'NWBVariableName', 2, ...
            'ConverterName', 3, ...
            'PrimaryGroup', 4, ...
            'NwbModule', 5, ...
            'TargetNwbType', 6, ...
            'Metadata', 7)

        SELECT_GROUP_LABEL = '<Select a group>'
        SELECT_MODULE_LABEL = '<Select an NWB module>'
        SELECT_NEURODATA_LABEL = '<Select a neurodata type>'
        DEFAULT_CONVERTER_LABEL = 'Default'
        CONVERTER_CONTROLLED_TARGET_LABEL = '<Converter controlled>'
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
        NWBConverterDescriptors
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
            [obj.NWBConverters, obj.NWBConverterDescriptors] = obj.listConverters();
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

            % WidgetTable cannot append rows after its internal add/remove
            % column is hidden, so refresh from the canonical table.
            obj.renderTable()
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
                obj.refreshDisplayedRow(rowIndex)
            end
        end

        function saveNwbConfigurationData(obj)
        %saveNwbConfigurationData Save data-item settings back to JSON.
            if ismissing(obj.FilePath)
                error('NansenNwb:MissingFilePath', ...
                    'FilePath is required for saving the NWB configuration.')
            end

            [~, ~, extension] = fileparts(obj.FilePath);
            if extension ~= ".json"
                error('NansenNwb:UnsupportedConfigurationFile', ...
                    'NWB configurations are saved as JSON files. Unsupported file: %s', obj.FilePath)
            end

            config = nansen.module.nwb.config.NwbFileConfiguration.fromAny( ...
                obj.NWBConfigurationData);
            config.DataItems = nansen.module.nwb.config.NwbDataItemConfig.fromStruct( ...
                table2struct(obj.Data));
            nansen.module.nwb.config.saveConfiguration(config, obj.FilePath)

            obj.NWBConfigurationData = config.toStruct();
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

            rootGrid = uigridlayout(obj.Figure, [5, 1]);
            rootGrid.RowHeight = {25, 20, '1x', 5, 34};
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
                'ShowColumnHeaderHelp', 'off', ...
                'HeaderBackgroundColor', '#FFFFFF', ...
                'HeaderForegroundColor', '#002054', ...
                'HeaderTextColor', '#002054', ...
                'BackgroundColor', 'white');
            obj.Table.Layout.Row = 3;
            obj.Table.ColumnNames = obj.COLUMN_NAMES;
            obj.Table.ColumnWidth = {150, 150, 250, 140, 170, 190, 170};
            obj.Table.MinimumColumnWidth = [120, 120, 190, 120, 140, 150, 150];
            obj.Table.MaximumColumnWidth = [240, 240, 360, 220, 260, 300, 260];
            obj.Table.RowHeight = 32;
            obj.Table.RowSpacing = 8;
            obj.Table.CellEditedFcn = @obj.onTableCellEdited;
            obj.Table.ColumnWidget = { ...
                @obj.createReadOnlyTextCell, ...
                [], ...
                @obj.createConverterDropdown, ...
                @(parent) obj.createDropdown(parent, obj.getPrimaryGroupOptions()), ...
                @(parent) obj.createDropdown(parent, obj.getNwbModuleOptions()), ...
                @obj.createNeuroDataTypeDropdown, ...
                @obj.createMetadataCell };

            footerGrid = uigridlayout(rootGrid, [1, 4]);
            footerGrid.Layout.Row = 5;
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
                obj.Table.EnableAddRows = 'off';
                for iRow = 1:height(displayTable)
                    obj.applyConverterOptions(iRow)
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
                    obj.setDataValue(rowIndex, "TargetNwbType", obj.SELECT_NEURODATA_LABEL)
                    obj.applyConverterOptions(rowIndex)
                    obj.applyNeuroDataTypeOptions(rowIndex)

                case "TargetNwbType"
                    if obj.converterControlsTarget(rowIndex)
                        obj.Table.updateCellValue(rowIndex, obj.COLUMN_INDEX.TargetNwbType, previousValue)
                        return
                    end

                    if confirmMetadataReset && obj.hasMetadata(rowIndex)
                        answer = uiconfirm(obj.Figure, ...
                            'Changing TargetNwbType will reset metadata for this variable. Continue?', ...
                            'Confirm Change', ...
                            'Options', {'Yes', 'No'}, ...
                            'DefaultOption', 'Yes', ...
                            'CancelOption', 'No');

                        if ~strcmp(answer, 'Yes')
                            obj.Table.updateCellValue(rowIndex, obj.COLUMN_INDEX.TargetNwbType, previousValue)
                            return
                        end
                    end

                    obj.setDataValue(rowIndex, "TargetNwbType", newValue)
                    obj.setDataValue(rowIndex, "Metadata", struct.empty)
                    obj.updateMetadataCell(rowIndex)

                case "ConverterName"
                    converterName = obj.resolveConverterName(newValue);
                    obj.setDataValue(rowIndex, "ConverterName", converterName)
                    obj.applyConverterDefaults(rowIndex, converterName)

                case "Metadata"
                    % Metadata is edited via the per-row button.

                otherwise
                    obj.setDataValue(rowIndex, columnName, newValue)
            end

            obj.refreshDisplayedRow(rowIndex)
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

        function hControl = createConverterDropdown(obj, parent)
            rowIndex = parent.Layout.Row;
            hControl = uidropdown(parent, ...
                'Items', cellstr(obj.getConverterOptions(rowIndex)));
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
            descriptor = obj.getRowConverterDescriptor(rowIndex);
            if ~isempty(descriptor) && descriptor.Source == "neuroconv"
                obj.editNeuroconvMetadata(rowIndex, descriptor)
                return
            end

            neuroDataType = string(obj.getDataValue(rowIndex, "TargetNwbType"));
            if obj.isPlaceholder(neuroDataType, "TargetNwbType")
                uialert(obj.Figure, ...
                    'Please select a TargetNwbType before editing metadata.', ...
                    'TargetNwbType Not Selected', ...
                    'Icon', 'warning')
                return
            end

            nwbClassName = nansen.module.nwb.internal.lookup.getFullTypeName(char(neuroDataType));
            [metadataStruct, info] = nansen.module.nwb.internal.getTypeMetadataStruct(nwbClassName);

            currentMetadata = obj.getDataValue(rowIndex, "Metadata");
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
                obj.setDataValue(rowIndex, "Metadata", metadataStruct)
                obj.updateMetadataCell(rowIndex)
            end
        end

        function editNeuroconvMetadata(obj, rowIndex, descriptor)
            metadataStruct = obj.getDataValue(rowIndex, "Metadata");
            if isempty(metadataStruct)
                metadataStruct = struct();
            end

            variableName = obj.getDataValue(rowIndex, "VariableName");
            [metadataStruct, wasAborted] = tools.editStruct( ...
                metadataStruct, 'all', 'Edit NeuroConv Metadata', ...
                'Prompt', sprintf('Edit metadata for %s (%s)', ...
                variableName, descriptor.DisplayName));

            if ~wasAborted
                metadataStruct = utility.struct.removeConfigFields(metadataStruct);
                obj.setDataValue(rowIndex, "Metadata", metadataStruct)
                obj.updateMetadataCell(rowIndex)
            end
        end

        function applyNeuroDataTypeOptions(obj, rowIndex)
            if obj.converterControlsTarget(rowIndex)
                value = obj.getTargetDisplayValue(rowIndex);
                obj.Table.setCellOptions(rowIndex, obj.COLUMN_INDEX.TargetNwbType, value, value)
                hControl = obj.Table.getCellComponent(rowIndex, obj.COLUMN_INDEX.TargetNwbType);
                hControl.Enable = 'off';
                hControl.Tooltip = 'The selected converter controls the NWB type and placement.';
                return
            end

            items = obj.getNeuroDataTypeOptions(rowIndex);
            value = string(obj.getDataValue(rowIndex, "TargetNwbType"));
            if ~any(value == items)
                value = items(1);
                obj.setDataValue(rowIndex, "TargetNwbType", value)
            end
            obj.Table.setCellOptions(rowIndex, obj.COLUMN_INDEX.TargetNwbType, items, value)
            hControl = obj.Table.getCellComponent(rowIndex, obj.COLUMN_INDEX.TargetNwbType);
            hControl.Enable = 'on';
            hControl.Tooltip = '';
        end

        function applyConverterOptions(obj, rowIndex)
            items = obj.getConverterOptions(rowIndex);
            value = obj.getDisplayValue(rowIndex, "ConverterName");
            if ~any(value == items)
                items = [items, value];
            end
            obj.Table.setCellOptions(rowIndex, obj.COLUMN_INDEX.ConverterName, items, value)
        end

        function updateMetadataCell(obj, rowIndex)
            hControl = obj.Table.getCellComponent(rowIndex, obj.COLUMN_INDEX.Metadata);
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
            options = obj.appendOptionValues(options, obj.Data.PrimaryGroup);
        end

        function options = getNwbModuleOptions(obj)
            options = string(obj.SELECT_MODULE_LABEL);
            try
                moduleNames = nansen.module.nwb.internal.schemautil.getNwbModules();
                options = [options, string(moduleNames(:)')];
            catch
                % Keep the placeholder if schema metadata is unavailable.
            end
            options = obj.appendOptionValues(options, obj.Data.NwbModule);
        end

        function options = getConverterOptions(obj, rowIndex)
            options = string(obj.DEFAULT_CONVERTER_LABEL);
            if isa(obj.NWBConverterDescriptors, 'containers.Map') && obj.NWBConverterDescriptors.Count > 0
                descriptors = obj.getConverterDescriptorsForRow(rowIndex);
                if ~isempty(descriptors)
                    options = [options, string({descriptors.DisplayName})];
                end
            end
            currentNames = obj.getConverterDisplayNames(obj.Data.ConverterName(rowIndex));
            options = obj.appendOptionValues(options, currentNames);
        end

        function options = getNeuroDataTypeOptions(obj, rowIndex)
            currentValue = string(obj.getDataValue(rowIndex, "TargetNwbType"));
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

        function descriptors = getConverterDescriptorsForRow(obj, rowIndex)
            descriptorCells = values(obj.NWBConverterDescriptors);
            if isempty(descriptorCells)
                descriptors = nansen.module.nwb.conversion.NwbConverterDescriptor.empty(0, 1);
                return
            end

            descriptors = [descriptorCells{:}];
            moduleName = string(obj.getDataValue(rowIndex, "NwbModule"));
            if obj.isPlaceholder(moduleName, "NwbModule")
                return
            end

            isMatch = false(size(descriptors));
            for i = 1:numel(descriptors)
                isMatch(i) = obj.matchesNwbModule(descriptors(i), moduleName);
            end
            descriptors = descriptors(isMatch);
        end

        function tf = matchesNwbModule(obj, descriptor, moduleName)
            moduleName = lower(string(moduleName));
            tags = lower(string(descriptor.NwbModuleTags));
            tf = isempty(tags) || any(tags == "*" | tags == moduleName);
        end

        function descriptor = getRowConverterDescriptor(obj, rowIndex)
            converterName = string(obj.getDataValue(rowIndex, "ConverterName"));
            descriptor = obj.getConverterDescriptor(converterName);
        end

        function descriptor = getConverterDescriptor(obj, converterName)
            descriptor = [];
            converterName = string(converterName);
            if converterName == "" || converterName == string(obj.DEFAULT_CONVERTER_LABEL)
                return
            end

            if isa(obj.NWBConverterDescriptors, 'containers.Map') && ...
                    isKey(obj.NWBConverterDescriptors, char(converterName))
                descriptor = obj.NWBConverterDescriptors(char(converterName));
            end
        end

        function tf = converterControlsTarget(obj, rowIndex)
            descriptor = obj.getRowConverterDescriptor(rowIndex);
            tf = ~isempty(descriptor) && descriptor.PlacementPolicy == "converter" && ...
                ~descriptor.AllowsPlacementOverride;
        end

        function value = getTargetDisplayValue(obj, rowIndex, dataTable)
            if nargin < 3
                dataTable = obj.Data;
            end

            converterName = string(dataTable.ConverterName{rowIndex});
            descriptor = obj.getConverterDescriptor(converterName);
            if ~isempty(descriptor) && descriptor.PlacementPolicy == "converter" && ...
                    ~descriptor.AllowsPlacementOverride
                value = string(descriptor.ProducesNwbType);
                if value == "" || value == "*"
                    value = string(obj.CONVERTER_CONTROLLED_TARGET_LABEL);
                end
                return
            end

            value = string(dataTable.TargetNwbType{rowIndex});
        end

        function applyConverterDefaults(obj, rowIndex, converterName)
            descriptor = obj.getConverterDescriptor(converterName);
            if isempty(descriptor)
                obj.setDataValue(rowIndex, "ConverterArgs", struct())
                return
            end

            obj.setDataValue(rowIndex, "ConverterArgs", descriptor.DefaultConverterArgs)

            if descriptor.PlacementPolicy == "converter" && ~descriptor.AllowsPlacementOverride
                obj.setDataValue(rowIndex, "PrimaryGroup", descriptor.PrimaryGroup)

                producedType = string(descriptor.ProducesNwbType);
                if producedType == "*"
                    producedType = "";
                end
                obj.setDataValue(rowIndex, "TargetNwbType", producedType)
            elseif descriptor.ProducesNwbType ~= "*" && descriptor.ProducesNwbType ~= "" && ...
                    obj.isPlaceholder(obj.getDataValue(rowIndex, "TargetNwbType"), "TargetNwbType")
                obj.setDataValue(rowIndex, "TargetNwbType", descriptor.ProducesNwbType)
            end

            tags = string(descriptor.NwbModuleTags);
            tags = tags(tags ~= "" & tags ~= "*");
            if isscalar(tags) && obj.isPlaceholder(obj.getDataValue(rowIndex, "NwbModule"), "NwbModule")
                obj.setDataValue(rowIndex, "NwbModule", tags)
            end
        end

        function refreshDisplayedRow(obj, rowIndex)
            if isempty(obj.Table) || isempty(obj.Table.Data)
                return
            end

            obj.applyConverterOptions(rowIndex)
            obj.applyNeuroDataTypeOptions(rowIndex)

            for iColumn = 1:numel(obj.COLUMN_NAMES)
                columnName = string(obj.COLUMN_NAMES{iColumn});
                if columnName == "ConverterName" || columnName == "TargetNwbType" || ...
                        columnName == "Metadata"
                    continue
                end
                obj.Table.updateCellValue(rowIndex, iColumn, ...
                    obj.getDisplayValue(rowIndex, columnName))
            end
            obj.updateMetadataCell(rowIndex)
        end

        function options = appendOptionValues(~, options, values)
            values = string(values);
            values = strtrim(values(:)');
            values = values(values ~= "" & ~ismissing(values));
            values = unique(values, 'stable');

            for i = 1:numel(values)
                if ~any(values(i) == options)
                    options = [options, values(i)]; %#ok<AGROW>
                end
            end
        end

        function displayTable = createDisplayTable(obj, dataTable)
            displayTable = table();
            if isempty(dataTable)
                return
            end

            displayTable.VariableName = string(dataTable.VariableName);
            displayTable.NWBVariableName = string(dataTable.NWBVariableName);
            displayTable.ConverterName = obj.getConverterDisplayNames(dataTable.ConverterName);
            displayTable.PrimaryGroup = string(dataTable.PrimaryGroup);
            displayTable.NwbModule = string(dataTable.NwbModule);
            displayTable.TargetNwbType = strings(height(dataTable), 1);
            for iRow = 1:height(dataTable)
                displayTable.TargetNwbType(iRow) = obj.getTargetDisplayValue(iRow, dataTable);
            end

            metadataStatus = strings(height(dataTable), 1);
            for iRow = 1:height(dataTable)
                metadataStatus(iRow) = obj.getMetadataStatus(iRow, dataTable);
            end
            displayTable.Metadata = metadataStatus;
        end

        function dataTable = createDataTable(obj, nwbConfigurationData)
            if isa(nwbConfigurationData, "nansen.module.nwb.config.NwbFileConfiguration")
                nwbConfigurationData = nwbConfigurationData.toStruct();
            end

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
            columns = cell(1, numel(obj.DATA_FIELD_NAMES));

            for iColumn = 1:numel(obj.DATA_FIELD_NAMES)
                columnName = obj.DATA_FIELD_NAMES{iColumn};
                columns{iColumn} = cell(numRows, 1);
                for iRow = 1:numRows
                    columns{iColumn}{iRow} = dataItems(iRow).(columnName);
                end
            end

            dataTable = table(columns{:}, 'VariableNames', obj.DATA_FIELD_NAMES);
        end

        function dataTable = createEmptyDataTable(obj)
            columns = repmat({cell(0, 1)}, 1, numel(obj.DATA_FIELD_NAMES));
            dataTable = table(columns{:}, 'VariableNames', obj.DATA_FIELD_NAMES);
        end

        function dataItems = fillMissingDataItemFields(obj, dataItems, defaultItem)
            for i = 1:numel(dataItems)
                for iColumn = 1:numel(obj.DATA_FIELD_NAMES)
                    columnName = obj.DATA_FIELD_NAMES{iColumn};
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
                    descriptor = obj.getConverterDescriptor(converterName);
                    if ~isempty(descriptor)
                        names(i) = descriptor.DisplayName;
                    else
                        names(i) = obj.getSimpleClassName(converterName);
                    end
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
                case "Metadata"
                    value = obj.getMetadataStatus(rowIndex);
                case "ConverterName"
                    value = obj.getConverterDisplayNames(obj.Data.ConverterName(rowIndex));
                case "TargetNwbType"
                    value = obj.getTargetDisplayValue(rowIndex);
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

            metadata = dataTable.Metadata{rowIndex};
            if isempty(metadata)
                status = "<Unconfigured>";
            else
                status = "<Customized>";
            end
        end

        function tf = hasMetadata(obj, rowIndex)
            tf = ~isempty(obj.getDataValue(rowIndex, "Metadata"));
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
                case "PrimaryGroup"
                    tf = value == string(obj.SELECT_GROUP_LABEL);
                case "NwbModule"
                    tf = value == "" || value == string(obj.SELECT_MODULE_LABEL);
                case "TargetNwbType"
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
            if isstruct(nwbConfigurationData) && isfield(nwbConfigurationData, 'AllVariableNames') && ...
                    ~isempty(nwbConfigurationData.AllVariableNames)
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

        function [converterMap, descriptorMap] = listConverters()
            converterMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
            descriptorMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            try
                registry = nansen.module.nwb.conversion.ConverterRegistry.instance();
                descriptors = registry.list();
            catch
                return
            end

            for i = 1:numel(descriptors)
                converterMap(char(descriptors(i).DisplayName)) = char(descriptors(i).Name);
                descriptorMap(char(descriptors(i).Name)) = descriptors(i);
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
