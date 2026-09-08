function nwbTable = convertToNWBTable(matlabTable, tableName)
%convertToNWBTable - Convert a MATLAB table to the NWB table type it stands for
%
%   nwbTable = convertToNWBTable(matlabTable, tableName) converts a MATLAB
%   table to a DynamicTable object of the neurodata type that a table of
%   the given name must have in an NWB file.
%
%   Since NWB 2.9.0 the electrodes table is its own neurodata type,
%   ElectrodesTable, and NwbFile rejects a plain DynamicTable in its place.
%   Every other table this module stores is a plain DynamicTable.
%
%   Input Arguments:
%     matlabTable - Table whose columns hold NWB-compatible values. Object
%                   reference columns must already hold ObjectView objects.
%     tableName   - Name of the stored table, for example "ElectrodesTable".
%
%   Output Arguments:
%     nwbTable - A types.hdmf_common.DynamicTable, or a subclass of it for
%                the electrodes table.
%
%   See also: util.table2nwb,
%             nansen.module.nwb.internal.dtable.initializeElectrodesTable

    arguments
        matlabTable table
        tableName (1,1) string
    end

    import nansen.module.nwb.internal.lookup.getMatNWBTypeName

    if tableName == "ElectrodesTable"
        tableType = getMatNWBTypeName('core', 'ElectrodesTable');
    else
        tableType = getMatNWBTypeName('hdmf_common', 'DynamicTable');
    end

    % The stored tables carry no description of their own, so the matnwb
    % default is passed explicitly to reach the type argument.
    description = "no description";
    nwbTable = util.table2nwb(matlabTable, description, tableType);
end
