function configureNwbFile()

    import nansen.module.nwb.file.initializeNwbFileConfiguration

    currentProject = nansen.getCurrentProject();
    configurationFolderPath = currentProject.getConfigurationFolder('Subfolder', 'nwb');
    configurationFilePath = fullfile(configurationFolderPath, 'test.mat');

    L = dir(fullfile( configurationFolderPath, '*.mat' ) );
    if isempty(L)
        % Todo: Open dialog for entering file name and description plus
        % other options.
        configurationCatalog = initializeNwbFileConfiguration();
        if isempty(configurationCatalog)
            errordlg(['This project does not contain any data variables.', ...
                'Please configure data variables before configuring an NWB conversion.'])
            return
        end
        % Todo: Save configuration catalog here or later?
    else
        % Todo: create listbox for selecting which configuration to load
        if isfile(configurationFilePath)
            S = load(configurationFilePath);
            configurationCatalog = S.nwbConfigurationData;
        else
            error('Test file not available')
        end
    end
    
    % Todo: Pass filepath where to save configuration
    % If this is a catalog, it should be a persistent catalog ant it will
    % alread have a filepath.
    nansen.module.nwb.gui.NWBConfigurator(configurationCatalog, 'FilePath', configurationFilePath)
end