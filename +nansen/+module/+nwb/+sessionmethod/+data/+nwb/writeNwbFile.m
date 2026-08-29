function varargout = writeNwbFile(sessionObject, varargin)
%writeNwbFile - Write an NWB file for a session
%
%   This method requires an NWB Configuration File to be present. This file
%   can be created from tools -> Configure NWB File. It is also possible to
%   customize the NWB Configuration for individual sessions by running the
%   session method from data -> nwb -> Customize NWB Configuration.
%
%   Use the 'ConfigurationFileName' parameter to select a specific
%   configuration file when multiple NWB configuration files are present.
%
%   The method itself only assembles the configuration for this session and
%   hands it to the conversion runner. Everything about how data becomes
%   neurodata lives in the converters, and everything about how the file is
%   written lives in NWBFileConverter.
%
%   See also nansen.module.nwb.session.NWBSessionConfigBuilder,
%   nansen.module.nwb.conversion.NWBFileConverter

import nansen.session.SessionMethod

% % % % % % % % % % % % CONFIGURATION CODE BLOCK % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify one or
% more attributes (see nansen.session.SessionMethod.setAttributes) for
% details. You can use the local function "getDefaultParameters" at the
% bottom of this file to define default parameters.

    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'queueable'};

% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % %
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - -

    % % % Initialization block for a session method function.

    if ~nargin && nargout > 0
        fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
        varargout = {fcnAttributes};   return
    end

    % % % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, true, varargin);

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %

    currentProject = nansen.getCurrentProject();

    configurationFolderPath = currentProject.getConfigurationFolder('Subfolder', 'nwb');
    configurationFilePath = getConfigurationFilePath( ...
        configurationFolderPath, params.ConfigurationFileName);

    if ismissing(configurationFilePath)
        errordlg(['NWB conversion configuration was not found. Please run ', ...
            'the NWB Configuration under Tools -> NWB -> Configure NWB File.'])
        return
    end

    dataItems = loadConfiguredDataItems(configurationFilePath);

    config = nansen.module.nwb.session.NWBSessionConfigBuilder.buildConfig( ...
        sessionObject, dataItems, ...
        TimeZone=params.TimeZone, ...
        WriteMode=lower(string(params.WriteMode)), ...
        ProjectName=string(currentProject.Name));

    % Checking the file is worth the Python round trip here: a session
    % export that is missing metadata a repository requires should say so
    % while the user is still looking at it.
    converter = nansen.module.nwb.conversion.NWBFileConverter(config, ...
        DataResolver=@(variableName) sessionObject.loadData(char(variableName)), ...
        Validate=params.Validate);

    nwbFilePath = converter.convert();

    fprintf('Finished writing file ''%s''\n', nwbFilePath)

    if nargout > 0
        varargout = {nwbFilePath};
    end
end

function params = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    params = struct();
    params.ConfigurationFileName = "";
    params.TimeZone = "local";
    params.WriteMode = 'Overwrite'; % 'Overwrite' | 'Append'
    params.Validate = true; % Check the written file against NWB Best Practices
end

function dataItems = loadConfiguredDataItems(configurationFilePath)
%loadConfiguredDataItems - Read the configured items from a configuration file
%
%   Configurations are JSON. A pilot .mat configuration is still accepted
%   here because the configurator has not been moved over yet, but it is
%   converted on the spot rather than read, and the user is told to save
%   it in the current format.

    if endsWith(configurationFilePath, ".json")
        config = nansen.module.nwb.config.loadConfiguration(configurationFilePath);
        dataItems = config.DataItems;
        return
    end

    loaded = load(configurationFilePath);
    legacyConfig = nansen.module.nwb.config.convertLegacyConfiguration( ...
        loaded.nwbConfigurationData.DataItems);
    dataItems = legacyConfig.DataItems;

    warning("nansen:nwb:legacyConfigurationFile", ...
        ['''%s'' uses the pilot configuration format. It was converted for ', ...
         'this run. Re-save it from the configurator to store it as JSON.'], ...
        configurationFilePath)
end

function configurationFilePath = getConfigurationFilePath(configurationFolderPath, configurationFileName)
%getConfigurationFilePath - Find the configuration file to convert with

    defaultConfigurationFileName = "nwb_conversion_configuration";
    configurationFilePath = string(missing);
    configurationFileName = string(configurationFileName);

    if ~ismissing(configurationFileName) && strlength(configurationFileName) > 0
        requestedFilePath = string(fullfile(configurationFolderPath, configurationFileName));
        if isfile(requestedFilePath)
            configurationFilePath = requestedFilePath;
        else
            errordlg(sprintf('NWB conversion configuration "%s" was not found.', ...
                configurationFileName), 'Missing NWB Configuration')
        end
        return
    end

    availableFiles = [dir(fullfile(configurationFolderPath, '*.json')); ...
                      dir(fullfile(configurationFolderPath, '*.mat'))];
    if isempty(availableFiles)
        return
    end

    % A JSON configuration wins over a .mat of the same name, since the
    % .mat is the pilot version of the same configuration.
    defaultJsonPath = string(fullfile(configurationFolderPath, ...
        defaultConfigurationFileName + ".json"));
    defaultMatPath = string(fullfile(configurationFolderPath, ...
        defaultConfigurationFileName + ".mat"));

    if isfile(defaultJsonPath)
        configurationFilePath = defaultJsonPath;
    elseif isfile(defaultMatPath)
        configurationFilePath = defaultMatPath;
    elseif isscalar(availableFiles)
        configurationFilePath = string(fullfile(availableFiles(1).folder, availableFiles(1).name));
    elseif usejava('desktop')
        [selectedIndex, wasConfirmed] = listdlg( ...
            'ListString', {availableFiles.name}, ...
            'SelectionMode', 'single', ...
            'Name', 'Select NWB Configuration', ...
            'PromptString', 'Select an NWB conversion configuration to use:');

        if wasConfirmed && ~isempty(selectedIndex)
            configurationFilePath = string(fullfile( ...
                availableFiles(selectedIndex).folder, ...
                availableFiles(selectedIndex).name));
        end
    else
        error('nansen:nwb:ambiguousConfiguration', ...
            ['Multiple NWB configuration files were found. Specify ', ...
             '''ConfigurationFileName'' when running writeNwbFile without ', ...
             'a desktop session.'])
    end
end
