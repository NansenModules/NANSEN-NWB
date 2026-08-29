function electrodeTable = initializeElectrodesTable()
%initializeElectrodesTable - Create an empty table for editing NWB electrodes
%
%   electrodeTable = initializeElectrodesTable() returns an empty MATLAB
%   table whose columns mirror the NWB ElectrodesTable neurodata type. The
%   table is used by the dynamic table editor, so it carries the column
%   descriptions and the group-to-group_name dependency the editor reads.
%
%   Output Arguments:
%     electrodeTable - Empty table with one variable per electrode column.
%
%   See also: nansen.module.nwb.internal.schemautil.getProcessedClass

    % NWB 2.9.0 moved the electrode columns off an anonymous group on
    % NWBFile and into the ElectrodesTable neurodata type, leaving that
    % group with no datasets of its own. The column set is therefore read
    % from the type rather than by walking NWBFile's subgroups.
    [classInfo, ~] = nansen.module.nwb.internal.schemautil ...
        .getProcessedClass('ElectrodesTable');

    columns = selectDataColumns(classInfo.datasets);

    columnNames = {columns.name};
    variableTypes = cellfun(@matlabTypeForColumn, {columns.dtype}, ...
        'UniformOutput', false);

    % The columns are built here rather than by preallocating with
    % table(Size=...), because matnwb's "types" package shares its name
    % with a variable inside table's preallocation code. Resolving
    % "types.core.ElectrodeGroup" in that scope fails, while calling empty
    % on the class from here works.
    columnValues = cellfun(@(t) feval(sprintf('%s.empty', t), 0, 1), ...
        variableTypes, 'UniformOutput', false);

    electrodeTable = table(columnValues{:}, 'VariableNames', columnNames);

    electrodeTable.Properties.Description = classInfo.type;
    electrodeTable.Properties.VariableDescriptions = {columns.doc};

    % The editor stores an electrode group as an object in "group" but
    % writes its name into the separate "group_name" column, so the link
    % between the two travels with the table.
    electrodeTable = addprop(electrodeTable, 'ColumnDependency', 'variable');
    columnDependency = repmat(string(missing), 1, width(electrodeTable));
    columnDependency(strcmp(columnNames, 'group')) = "group_name";
    electrodeTable.Properties.CustomProperties.ColumnDependency = columnDependency;

    electrodeTable.Properties.DimensionNames{1} = 'Electrode';
end

function columns = selectDataColumns(datasets)
% selectDataColumns - Keep the named data columns, in a stable order
%
%   The processed class also carries the anonymous VectorData placeholder
%   inherited from DynamicTable and the "id" row identifier, neither of
%   which is an editable data column. Sorting by name keeps the column
%   order stable across matnwb versions, which the schema order is not.

    isDataColumn = ~cellfun(@isempty, {datasets.name}) ...
        & ~strcmp({datasets.name}, 'id');
    columns = datasets(isDataColumn);

    [~, order] = sort(string({columns.name}));
    columns = columns(order);
end

function typeName = matlabTypeForColumn(dtype)
% matlabTypeForColumn - Map an NWB schema dtype onto a MATLAB table type

    if isa(dtype, 'containers.Map')
        % An object reference. The column holds instances of the target
        % type, for example ElectrodeGroup for the "group" column.
        typeName = nansen.module.nwb.internal.lookup.getMatNWBTypeName( ...
            'core', dtype('target_type'));
    elseif strcmp(dtype, 'char')
        % Text columns are edited as strings rather than character arrays.
        typeName = 'string';
    else
        typeName = dtype;
    end
end
