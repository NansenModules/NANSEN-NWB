function metadataStruct = getMetadataInstance(instanceName, nwbType)
% getMetadataInstance - Get nwb instance from catalog by name
    
    if isempty(instanceName); metadataStruct = struct.empty; return; end

    catalog = nansen.module.nwb.internal.getMetadataCatalog(nwbType);
    metadataStruct = catalog.get(instanceName);
    [metadataStruct, ~] = utility.struct.popfield(metadataStruct, 'Uuid', false);    
end
