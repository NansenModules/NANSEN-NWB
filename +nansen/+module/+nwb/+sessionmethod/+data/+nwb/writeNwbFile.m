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
    
    % params.Alternative = nwbFiles{1}; % Set a default value.

    % % % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, true, varargin);
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Sketch for session method

    % options:
    % - File (if there are multiple configurations)
    % - Mode : append, rewrite

    %% Initialize configurations

    currentProject = nansen.getCurrentProject();
    projectName = string(currentProject.Name);

    configurationFolderPath = currentProject.getConfigurationFolder('Subfolder', 'nwb');
    configurationFilePath = getConfigurationFilePath( ...
        configurationFolderPath, params.ConfigurationFileName);

    if ismissing(configurationFilePath)
        errordlg(['NWB conversion configuration was not found. Please run ', ...
            'the NWB Configuration under Tools -> NWB -> Configure NWB File.'])
        return
    end

    S = load(configurationFilePath);
    configurationCatalog = S.nwbConfigurationData;

    % Todo: Load session specific NWB conversion setting

    % Todo: Merge

    % Create filepath
    % Todo: nwbConfig should specify data location. For now, use default
    % data location
    saveFolder = sessionObject.getSessionFolder('', 'create');

    % Both the filename below and the NWB identifier are built from the
    % subject and session IDs. A blank component would silently collapse the
    % name instead of failing, so reject it before anything is written.
    mustHaveSessionIdentifiers(sessionObject)

    % We build the filename using BIDS/DandiArchive convention.
    % Todo: Add custom postfix via configuration
    nwbFilename = sprintf('sub-%s_ses-%s.nwb', sessionObject.subjectID, sessionObject.sessionID);
    nwbFilePath = fullfile(saveFolder, nwbFilename);
    
    if strcmp(params.WriteMode, 'Overwrite') && isfile(nwbFilePath)
        delete(nwbFilePath);
    end

    %% Open or create NWB file depending on if file exists.
    % hasUnexportedChanges tracks whether the in-memory NwbFile is ahead of
    % the file on disk. Custom converters below work on the file on disk,
    % so pending changes must be flushed before one runs, and the final
    % export can be skipped when nothing is pending.
    if isfile(nwbFilePath)
        nwbFile = nwbRead(nwbFilePath);
        hasUnexportedChanges = false;
    else
        nwbFile = NwbFile(...
            'identifier', strjoin([projectName, string(sessionObject.subjectID), string(sessionObject.sessionID)], '_'), ...
            'session_description', sessionObject.Description, ...
            'session_start_time', getSessionStartTime(sessionObject, params.TimeZone), ...
            'general_session_id', sessionObject.sessionID);

        hasUnexportedChanges = true;
    end

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
            % resolveMetadata adds linked instances (devices, electrode
            % groups, ...) to the in-memory NwbFile as a side effect.
            hasUnexportedChanges = true;
        end
        
        % Run default or custom converter.
        if isempty(variableConfiguration.Converter) || strcmp(variableConfiguration.Converter, "Default")
            try
                if isempty(metadata); metadata = struct(); end
                neuroData = ...
                    nansen.module.nwb.file.convertToNeuroDataType(...
                        metadata, data, nwbDataType);
            catch ME
                warning('Could not add %s to nwb file: Caused by\n %s\n', variableName, ME.message);
                continue
            end
        else
            % Custom converters receive the file path and read, extend and
            % write the file on disk themselves. Flush pending in-memory
            % changes first: the re-read below would otherwise replace them
            % with the file's last exported state, and a converter running
            % as the first item would not find a file at all.
            if hasUnexportedChanges
                nwbExport(nwbFile, nwbFilePath)
            end
            customConverterFcn = variableConfiguration.Converter;
            feval(customConverterFcn, metadata, data, nwbFilePath);
            nwbFile = nwbRead(nwbFilePath);
            hasUnexportedChanges = false;
            continue
        end

        switch variableConfiguration.PrimaryGroupName
            case 'Acquisition'
                if isa(neuroData, 'struct')
                    for j = 1:numel(neuroData)
                        nwbFile.acquisition.set(neuroData(j).name, neuroData(j).data);
                    end
                else
                    nwbFile.acquisition.set(variableName, neuroData);
                end

            case 'Processing'
                moduleName = variableConfiguration.NwbModule;
                % Create or get processing module based on nwb module
                processingModule = nansen.module.nwb.file.getProcessingModule(nwbFile, moduleName, 'No Description');
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

        hasUnexportedChanges = true;

        % primaryGroupName = lower(variableConfiguration.PrimaryGroupName);
        % nwbVariableName = variableConfiguration.NWBVariableName;
        % nwbFile.(primaryGroupName).set(nwbVariableName, nwbData);

        % nwbFile = nansen.module.nwb.convert.writeDataToFile(nwbFile, data, metadata, customConversinFcn); % anything else???
    end

    % Export pending changes once, after the last data item. NwbFile.export
    % appends an entry to file_create_date on each call, so exporting more
    % often than necessary stamps the file repeatedly and rewrites the
    % whole file every pass.
    if hasUnexportedChanges
        nwbExport(nwbFile, nwbFilePath)
    end

    fprintf('Finished writing file ''%s''\n', nwbFilePath)
end

function params = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    params = struct();
    params.ConfigurationFileName = "";
    params.TimeZone = "local";
    params.WriteMode = 'Overwrite'; % 'Overwrite' | 'Append'
end

function mustHaveSessionIdentifiers(sessionObject)
% mustHaveSessionIdentifiers - Verify the session has a subject and session ID
%
%   strjoin drops blank components silently, so a session with no subject ID
%   would otherwise produce the identifier "Project_ses-01" and the filename
%   "sub-_ses-01.nwb", both of which collide with any other subject sharing
%   that session ID. NWB identifiers are required to be globally unique.

    missingNames = string.empty;

    if isBlank(sessionObject.subjectID)
        missingNames(end+1) = "subjectID";
    end
    if isBlank(sessionObject.sessionID)
        missingNames(end+1) = "sessionID";
    end

    if ~isempty(missingNames)
        error('nansen:nwb:missingSessionIdentifier', ...
            ['Session is missing a value for %s. These identify the NWB file ', ...
             'and form its globally unique identifier. Set them for this ', ...
             'session, or configure the data location so they can be detected ', ...
             'from the session folder, before writing an NWB file.'], ...
            strjoin(missingNames, ' and '))
    end
end

function tf = isBlank(value)
% isBlank - True if a value holds no usable text

    text = strtrim(string(value));
    tf = isempty(text) || ~isscalar(text) || strlength(text) == 0;
end

function sessionStartTime = getSessionStartTime(sessionObject, timeZone)
% getSessionStartTime - Combine a session's date and time into a zoned datetime
%
%   NWB records session_start_time as an ISO 8601 timestamp. matnwb writes
%   the UTC offset only when the datetime carries a time zone, so an
%   unzoned value would produce a timestamp that cannot be placed on an
%   absolute timeline. The session's date and time come from folder names
%   and carry no zone of their own, so one is attached here.

    if isempty(sessionObject.Date) || isempty(sessionObject.Time)
        error('nansen:nwb:missingSessionStartTime', ...
            ['Session "%s" has no date or time, so session_start_time ', ...
             'cannot be determined. Set the Date and Time metadata for ', ...
             'the session before writing an NWB file.'], sessionObject.sessionID)
    end

    % DataLocationModel.getDate only parses a datetime when the "Experiment
    % Date" metadata variable has a string format configured. Without one it
    % returns the raw substring, which would fail further down with an error
    % that does not point at the cause.
    if ~isdatetime(sessionObject.Date)
        error('nansen:nwb:unparsedSessionDate', ...
            ['Session "%s" has a date of type %s rather than datetime, so ', ...
             'session_start_time cannot be determined. Configure a string ', ...
             'format for the "Experiment Date" metadata variable so that it ', ...
             'is parsed as a date.'], sessionObject.sessionID, class(sessionObject.Date))
    end

    sessionStartTime = sessionObject.Date + duration( char( sessionObject.Time ) );
    sessionStartTime.TimeZone = timeZone;
end

function configurationFilePath = getConfigurationFilePath(configurationFolderPath, configurationFileName)

    defaultConfigurationFileName = "nwb_conversion_configuration.mat";
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

    availableFiles = dir(fullfile(configurationFolderPath, '*.mat'));
    if isempty(availableFiles)
        return
    end

    defaultConfigurationFilePath = string(fullfile(configurationFolderPath, defaultConfigurationFileName));
    if isfile(defaultConfigurationFilePath)
        configurationFilePath = defaultConfigurationFilePath;
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
        error(['Multiple NWB configuration files were found. Specify ', ...
            '''ConfigurationFileName'' when running writeNwbFile without a desktop session.'])
    end
end
