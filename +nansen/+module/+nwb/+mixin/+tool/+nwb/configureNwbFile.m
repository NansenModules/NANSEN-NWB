function configureNwbFile()
%configureNwbFile - Open the NWB configurator for the current project
%   configureNwbFile() opens the configurator on the project's conversion
%   configuration, a JSON file in the project's nwb configuration folder.
%   A project with several asks which to open. A project that still has
%   only a pilot ".mat" configuration has it converted on opening; saving
%   writes ".json" beside it. A project with neither starts an empty
%   configuration under the default name.
%
%   See also nansen.module.nwb.gui.NWBConfiguratorApp,
%   nansen.module.nwb.config.convertLegacyConfiguration

    import nansen.module.nwb.config.loadConfiguration
    import nansen.module.nwb.config.convertLegacyConfiguration

    currentProject = nansen.getCurrentProject();
    configurationFolder = currentProject.getConfigurationFolder('Subfolder', 'nwb');
    defaultFilePath = fullfile(configurationFolder, "nwb_conversion_configuration.json");

    % The metadata defaults live in the same folder but are not a
    % conversion configuration.
    jsonFiles = dir(fullfile(configurationFolder, "*.json"));
    jsonFiles = jsonFiles(~strcmp({jsonFiles.name}, "nwb_metadata_defaults.json"));
    matFiles = dir(fullfile(configurationFolder, "*.mat"));

    if ~isempty(jsonFiles)
        filePath = chooseFile(jsonFiles);
        if strlength(filePath) == 0
            return
        end
        config = loadConfiguration(filePath);
    elseif ~isempty(matFiles)
        filePath = chooseFile(matFiles);
        if strlength(filePath) == 0
            return
        end
        loaded = load(filePath);
        config = convertLegacyConfiguration(loaded.nwbConfigurationData.DataItems);
    else
        filePath = defaultFilePath;
        config = nansen.module.nwb.config.NWBFileConfiguration();
    end

    nansen.module.nwb.gui.NWBConfiguratorApp(config, FilePath=filePath)
end

function filePath = chooseFile(files)
%chooseFile - The one file, or the one the user picks; "" when cancelled

    if isscalar(files)
        filePath = string(fullfile(files(1).folder, files(1).name));
        return
    end

    [selectedIndex, wasConfirmed] = listdlg( ...
        'ListString', {files.name}, ...
        'SelectionMode', 'single', ...
        'Name', 'Select NWB Configuration', ...
        'PromptString', 'Select an NWB conversion configuration to open:');

    filePath = "";
    if wasConfirmed && ~isempty(selectedIndex)
        filePath = string(fullfile(files(selectedIndex).folder, files(selectedIndex).name));
    end
end
