function S = initializeNwbFileConfiguration(currentProject)

    import nansen.module.nwb.file.getDefaultFileConfigurationItem
    
    if ~nargin
        currentProject = nansen.getCurrentProject();
    end

    variableItems = currentProject.VariableModel.Data;
    filteredVariableItems = variableItems(~[variableItems.IsInternal]);
    filteredVariableItems = filteredVariableItems([filteredVariableItems.IsCustom]); % Todo: Remove as this is temporary

    if isempty(filteredVariableItems)
        S = struct.empty; return
    end

    defaultItem = getDefaultFileConfigurationItem();
    configItems = repmat(defaultItem, 1, numel(filteredVariableItems));

    [configItems(:).VariableName] = deal(filteredVariableItems.VariableName);
    [configItems(:).NWBVariableName] = deal(filteredVariableItems.VariableName);

    S = struct;
    S.Name = "Processed"; % Use for differentiating different NWB files, i.e raw data for internal use, processed data for sharing
    S.Description = "Processed Data for Sharing";

    S.DataItems = configItems;
    S.General.ExtracellularEphys.Electrodes = initializeElectrodesTable();
    S.AllVariableNames = {variableItems.VariableName};
end

function electrodeTable = initializeElectrodesTable()
% Todo: Add ID.
    electrodeGroup = nansen.module.nwb.internal.schemautil.getElectrodesTableGroup();

    dynamicTableColumns = electrodeGroup.datasets;

    columnNames = {dynamicTableColumns.name};
    columnDescriptions = {dynamicTableColumns.doc};
    numColumns = numel(columnNames);

    variableTypes = {dynamicTableColumns.dtype};
    variableTypes{7} = 'matnwb.types.core.ElectrodeGroup';
    variableTypes = string(variableTypes);
    variableTypes(variableTypes=="char")="string";

    electrodeTable = table('Size', [0,numColumns], 'VariableTypes', variableTypes);

    electrodeTable.Properties.Description = electrodeGroup.doc;
    electrodeTable.Properties.VariableNames = columnNames;
    electrodeTable.Properties.VariableDescriptions = columnDescriptions;
end
