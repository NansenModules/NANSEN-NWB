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

    % Some ad-hoc mess to account for the fact that the name of an
    % electrode group is stored in a separate vectordata entry in the
    % dynamic table.
    electrodeTable = addprop(electrodeTable, 'ColumnDependency', 'variable');
    columnDependency = repmat(string(missing), 1, width(electrodeTable));
    isGroup = strcmp(electrodeTable.Properties.VariableNames, 'group');
    columnDependency(isGroup) = "group_name";
    
    electrodeTable.Properties.CustomProperties.ColumnDependency = columnDependency;
end