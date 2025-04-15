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
    %saveFolder = sessionObject.getSessionFolder();
    %nwbFilename = [configurationCatalog.Name, '.nwb'];

    nwbFilePath = sessionObject.getDataFilePath(char(configurationCatalog.Name), ...
        '-w', 'FileType', 'nwb'); %, 'DataLocation', 'Sharing');
    
    if isfile(nwbFilePath); delete(nwbFilePath); end

    %% Open or create NWB file depending on if file exists.
    % Todo: Function of nwb module:
    if isfile(nwbFilePath)
        nwbFile = nansen.module.nwb.file.NWBFile(nwbFilePath);
        wasInitialized = false;
    else
        nwbFile = nansen.module.nwb.file.NWBFile();
        wasInitialized = true;
    end

    % Question: Is there anything against saving right away?
    % % if wasInitialized
    % %     nwbExport(nwbFile, nwbFilePath);
    % % end

    % Create a map for holding resolved metadata / neurodata types.
    instanceMap = dictionary;

    %% Todo Add general metadata like dataset info, subjects etc.:

    
    %% Loop through each variable of the NWB configuration
    for i = 1:numel(configurationCatalog.DataItems)
        
        variableConfiguration = configurationCatalog.DataItems(i);

        variableName = variableConfiguration.VariableName;
        
        nwbDataType = variableConfiguration.NeuroDataType;
        metadata = variableConfiguration.DefaultMetadata;

        metadata = utility.struct.removeConfigFields(metadata); %todo: remove
        
        % Load data
        data = sessionObject.loadData(variableConfiguration.VariableName);

        % Todo: Load metadata instances, resolve linked/embedded instances
        if ~isempty(metadata)
            [metadata, instanceMap] = ...
                nansen.module.nwb.internal.resolveMetadata(...
                    metadata, nwbDataType, nwbFile, instanceMap);
        end
        
        % Run default or custom converter.
        if isempty(variableConfiguration.Converter) || strcmp(variableConfiguration.Converter, 'Default')
            try
                if isempty(metadata); metadata = struct(); end
                neuroData = ...
                    nansen.module.nwb.file.convertToDataType(...
                        metadata, data, nwbDataType);
            catch ME
                warning('Could not add %s to nwb file: Caused by\n %s\n', variableName, ME.message);
                continue
            end
        else
            customConverterFcn = variableConfiguration.Converter;
            feval(customConverterFcn, metadata, data, nwbFilePath);
            nwbFile = nansen.module.nwb.file.NWBFile(nwbFilePath);
            continue
        end

        switch variableConfiguration.PrimaryGroupName
            case 'Acquisition'
                nwbFile.acquisition.set(variableName, neuroData);
            
            case 'Processing'
                moduleName = variableConfiguration.NwbModule;
                % Create or get processing module based on nwb module
                 processingModule = nwbFile.getProcessingModule(moduleName, 'No Description');
                if isa(neuroData, 'struct')
                    for j = 1:numel(neuroData)
                        processingModule.nwbdatainterface.set(...
                            neuroData(j).name, neuroData(j).data);
                    end
                else
                    processingModule.nwbdatainterface.set(variableName, neuroData);
                end
                % Add to processing module
        end

        % primaryGroupName = lower(variableConfiguration.PrimaryGroupName);
        % nwbVariableName = variableConfiguration.NWBVariableName;
        % nwbFile.(primaryGroupName).set(nwbVariableName, nwbData);
        
        %nwbFile = nansen.module.nwb.convert.writeDataToFile(nwbFile, data, metadata, customConversinFcn); % anything else???
    
        nwbExport(nwbFile, nwbFilePath)
    end
            
    %nwbExport(nwbFile, nwbFilePath)
    fprintf('Finished writing file ''%s''\n', nwbFilePath)

    %% Export the file
    if wasInitialized
        %nwbExport(obj.NWBObject, obj.PathName);
    end

end

function params = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    params = struct();
end