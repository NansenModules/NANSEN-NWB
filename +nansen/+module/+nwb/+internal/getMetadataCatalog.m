function catalog = getMetadataCatalog(neuroDataType)

    currentProject = nansen.getCurrentProject();
    nwbInstanceFolderPath = fullfile( currentProject.getMetadataFolder(), 'nwb', 'instances' );
    if ~isfolder(nwbInstanceFolderPath); mkdir(nwbInstanceFolderPath); end
    
    neuroDataType = strrep(neuroDataType, '.', '_');
    instanceFileName = fullfile(nwbInstanceFolderPath, neuroDataType+".mat");
    catalog = PersistentCatalog('SaveFolder', instanceFileName);
    catalog.NameField = 'name';
end

