function dynamicTable = getDynamicTableByName(instanceName)

    % Todo: Need to generalize this for all dynamic tables and subtypes...
    
    catalog = nansen.module.nwb.internal.getMetadataCatalog(instanceName);
    item = catalog.get(instanceName);
    dynamicTable = item.DynamicTable;
end