function instanceNames = getMetadataInstances(neuroDataType)
    catalog = nansen.module.nwb.internal.getMetadataCatalog(neuroDataType);
    
    % Todo: Specify name property.
    instanceNames = catalog.ItemNames;
end