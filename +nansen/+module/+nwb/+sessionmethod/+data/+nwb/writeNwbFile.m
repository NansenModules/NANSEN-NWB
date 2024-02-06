function varargout = writeNwbFile(sessionObject, varargin)
% writeNwbFile - Write an NWB file for a session
%
%   This method requires an NWB Configuration File to be present. This file
%   can be created from tools -> Configure NWB File. It is also possible to
%   customize the NWB Configuration for individual sessions by running the
%   session method from data -> nwb -> Customize Nwb Configuration

import nansen.session.SessionMethod


% % % % % % % % % % % % CONFIGURATION CODE BLOCK % % % % % % % % % % % % 
% Create a struct of default parameters (if applicable) and specify one or 
% more attributes (see nansen.session.SessionMethod.setAttributes) for 
% details. You can use the local function "getDefaultParameters" at the 
% bottom of this file to define default parameters.

    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'queueable'};
    
    % Todo: Provide each of the configured NWB files as alternatives
    % nwbFiles = getNwbFileNames();
    % ATTRIBUTES = [ATTRIBUTES, {'Alternatives', nwbFiles}];
    

% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % % 
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - - 
   
    % % % Initialization block for a session method function.

    if ~nargin && nargout > 0
        fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
        varargout = {fcnAttributes};   return
    end
    
    %params.Alternative = nwbFiles{1}; % Set a default value.

    % % % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, true, varargin);
    
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % 
% Sketch for session method

    % options: 
    % - File (if there are multiple configurations)
    % - Mode : append, rewrite 

    %% Initialize configurations

    % Load default NWB Conversion settings
    currentProject = nansen.getCurrentProject();
    configurationFolderPath = currentProject.getConfigurationFolder('Subfolder', 'nwb');
    configurationFilePath = fullfile(configurationFolderPath, 'test.mat');

    S = load(configurationFilePath);
    configurationCatalog = S.nwbConfigurationData;

    % Todo: Load session specific NWB conversion setting

    % Todo: Merge

    % Create filepath
    % Todo: nwbConfig should specify data location
    saveFolder = sessionObject.getSessionFolder();
    nwbFilename = [configurationCatalog.Name, '.nwb'];

    nwbFilePath = sessionObject.getDataFilePath(configurationCatalog.Name, 'FileType', 'nwb');
    

    %% Open or create NWB file depending on if file exists.
    % Todo: Function of nwb module:
    if isfile(nwbFilePath)
        nwbFile = nwbRead(nwbFilePath);
        wasInitialized = false;
    else
        nwbFile = NwbFile();
        wasInitialized = true;
    end

    % Question: Is there anything against saving right away?
    % % if wasInitialized
    % %     nwbExport(nwbFile, nwbFilePath);
    % % end

    %% Todo Add general metadata like dataset info, subjects etc.:
     
    
    %% Loop through each variable of the NWB configuration
    for i = 1:numel(configurationCatalog.DataItems)
        variableConfiguration = configurationCatalog.DataItems(i);
        
        variableName = variableConfiguration.VariableName;

        % Get custom metadata
        metadata = variableConfiguration.DefaultMetadata;
        metadata = utility.struct.removeConfigFields(metadata);

        nvPairs = namedargs2cell(metadata);
        nvPairs(1:2:end) = cellfun(@(c) utility.string.camel2snake(c), nvPairs(1:2:end), 'UniformOutput', false);

        % Load data
        data = sessionObject.loadData(variableName);
        if isa(data, 'timetable')
            dataV = data{:,1};
            nvPairs = [nvPairs, {'timestamps', seconds(data.Time), 'data' dataV}];
        end
        
        
        % Get custom conversion function
        
        % Neurodata type
        nwbData = feval(sprintf('types.core.%s', variableConfiguration.NeuroDataType), nvPairs{:});
        
        
        nwb.acquisition.set('2pInternal', InternalTwoPhoton);
        
        primaryGroupName = lower(variableConfiguration.PrimaryGroupName);
        nwbVariableName = variableConfiguration.NWBVariableName;
        nwbFile.(primaryGroupName).set(nwbVariableName, nwbData);
        
        %nwbFile = nansen.module.nwb.convert.writeDataToFile(nwbFile, data, metadata, customConversinFcn); % anything else???
    
    end

    %% Export the file
    if wasInitialized
        nwbExport(obj.NWBObject, obj.PathName);
    end

end

function params = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    params = struct();
end