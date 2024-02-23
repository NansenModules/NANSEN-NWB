function rowInd = uiSelectTableRegion(S, nwbNodes)
% uiSelectTableRegion - "Callback" function for selecting DynamicTableRegion
%
%   This function initializes the GUI for selecting a region (i.e rows) of
%   a dynamic table.

%   Currently only works for a predefined tables. Should be generalized to 
%   load any dynamic table from a dynamic table catalog.
    
    arguments
        S (1,1) struct
        nwbNodes (1,:) nansen.module.nwb.internal.NwbNode
    end

    import nansen.module.nwb.internal.lookup.getDynamicTableForRegionView

    % Use a lookup function to figure out if a special table is going to be created.
    ancestorNeuroDataType = nwbNodes(end-1).DefiningType;
    ancestorPropertyName = nwbNodes(end-1).PropertyName;
    linkedTableName = getDynamicTableForRegionView(ancestorNeuroDataType, ancestorPropertyName);

    % The struct S should contain a field, "table" with information about
    % which table should be selected...
    % Todo: Get table name from S and open the correct table... 
            
    catalog = nansen.module.nwb.internal.getMetadataCatalog(linkedTableName);

    catalogItem = catalog.get(S.table);
    dynamicTable = catalogItem.DynamicTable;

    [h, data] = nansen.module.nwb.gui.UIDynamicTableRegionSelector(dynamicTable);
    
    % Note: The data is stored as a cell array in order to be properly
    % handled by the struct editor. Here it is important that the cell
    % array is converted to a numeric vector. Note: Indices are
    % 0-references due to nwb specification.
    selectedRows = [S.data{:}] + 1;
    h.setSelection(selectedRows)

    uiwait(h)

    if strcmp(data('State'), 'Saved')
        rowInd = data('Selection');
        rowInd = rowInd-1; % Todo: Consider whether to change values to 0-indexed here or only eventually when creating the NWB DynamicTableRegion
        rowInd = num2cell(rowInd);
        
        % Todo: If table is edited, we replace the item and save the catalog

        catalogItem.DynamicTable = data('Table');
        catalog.replace(catalogItem);
        catalog.save()
    end
end
