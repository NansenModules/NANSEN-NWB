function configureNwbFile()

    import nansen.module.nwb.file.initializeNwbFileConfiguration

    currentProject = nansen.getCurrentProject();
    configurationFolderPath = currentProject.getConfigurationFolder('Subfolder', 'nwb');
    configurationFilePath = fullfile(configurationFolderPath, 'nwb_conversion_configuration.mat');

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
        if numel(L) == 1
            configurationFilePath = fullfile(L(1).folder, L(1).name);
        else
            [selectedIndex, wasConfirmed] = listdlg( ...
                'ListString', {L.name}, ...
                'SelectionMode', 'single', ...
                'Name', 'Select NWB Configuration', ...
                'PromptString', 'Select an NWB conversion configuration to load:');

            if ~wasConfirmed || isempty(selectedIndex)
                return
            end

            configurationFilePath = fullfile(L(selectedIndex).folder, L(selectedIndex).name);
        end

        S = load(configurationFilePath);
        configurationCatalog = S.nwbConfigurationData;
    end

    variableModel = nansen.VariableModel();
    if variableModel.NumVariables == 0
        errordlg([...
            'No data variables are present on this project. One or more ', ...
            'data variables are needed to configure NWB conversion. Please ', ...
            'add data variables and try again.'], 'Aborted NWB configuration.')
    end

    % Todo: Pass filepath where to save configuration
    % If this is a catalog, it should be a persistent catalog ant it will
    % alread have a filepath.
    nansen.module.nwb.gui.NWBConfigurator(configurationCatalog, 'FilePath', configurationFilePath)
end
