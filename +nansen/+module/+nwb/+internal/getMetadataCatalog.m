function catalog = getMetadataCatalog(neuroDataType)
%getMetadataCatalog - Get the catalog of stored instances of a type
%   catalog = getMetadataCatalog(neuroDataType) returns the catalog
%   holding the saved instances of one neurodata type for the current
%   project, creating the folder that backs it if needed.
%
%   Each type has its own catalog file, named after the type. Pass a
%   type, not the name of an instance.
%
%   See also nansen.module.nwb.internal.getMetadataInstance,
%   nansen.module.nwb.internal.getMetadataInstanceNames

    currentProject = nansen.getCurrentProject();
    nwbInstanceFolderPath = fullfile( currentProject.getMetadataFolder(), 'nwb', 'instances' );
    if ~isfolder(nwbInstanceFolderPath); mkdir(nwbInstanceFolderPath); end
    
    neuroDataType = strrep(neuroDataType, '.', '_');
    instanceFileName = fullfile(nwbInstanceFolderPath, neuroDataType+".mat");
    catalog = PersistentCatalog('SaveFolder', instanceFileName);
    catalog.NameField = 'name';
end
