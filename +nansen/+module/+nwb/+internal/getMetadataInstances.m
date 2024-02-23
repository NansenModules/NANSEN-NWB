function instanceNames = getMetadataInstances(neuroDataType)
    % Todo: Rename to getMetadataInstanceNames

    catalog = nansen.module.nwb.internal.getMetadataCatalog(neuroDataType);
    
    % Todo: Specify name property.
    instanceNames = catalog.ItemNames;
end