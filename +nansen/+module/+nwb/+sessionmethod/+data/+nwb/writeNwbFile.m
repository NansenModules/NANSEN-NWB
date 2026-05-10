function varargout = writeNwbFile(sessionObject, varargin)
%writeNwbFile Write an NWB file for a NANSEN session.

    import nansen.session.SessionMethod

    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'queueable'};

    if ~nargin && nargout > 0
        fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
        varargout = {fcnAttributes};
        return
    end

    params = utility.parsenvpairs(params, true, varargin);

    currentProject = nansen.getCurrentProject();
    configurationFolderPath = currentProject.getConfigurationFolder( ...
        'Subfolder', 'nwb');
    configurationFilePath = getConfigurationFilePath( ...
        configurationFolderPath, params.ConfigurationFileName);

    if ismissing(configurationFilePath)
        errordlg(['NWB conversion configuration was not found. Please run ', ...
            'Tools -> NWB -> Configure NWB File.'])
        if nargout > 0
            varargout = {string(missing)};
        end
        return
    end

    config = nansen.module.nwb.config.loadConfiguration(configurationFilePath);
    config = completeSessionConfiguration(config, sessionObject, currentProject);

    warnings = nansen.module.nwb.file.validateNwbConfiguration( ...
        dataItemsToStruct(config.DataItems));
    if ~isempty(warnings)
        error('NansenNwb:InvalidConfiguration', ...
            'NWB configuration is incomplete:%s%s', newline, strjoin(warnings, newline))
    end

    dataResolver = @(variableName) sessionObject.loadData(char(variableName));
    converter = nansen.module.nwb.conversion.NwbFileConverter( ...
        config, 'DataResolver', dataResolver);
    nwbFilePath = converter.convert();

    fprintf('Finished writing file ''%s''\n', nwbFilePath)
    if nargout > 0
        varargout = {nwbFilePath};
    end
end

function params = getDefaultParameters()
    params = struct();
    params.ConfigurationFileName = "";
end

function config = completeSessionConfiguration(config, sessionObject, currentProject)
    if strlength(config.OutputPath) == 0
        saveFolder = sessionObject.getSessionFolder('', 'create');
        nwbFilename = sprintf('sub-%s_ses-%s.nwb', ...
            sessionObject.subjectID, sessionObject.sessionID);
        config.OutputPath = string(fullfile(saveFolder, nwbFilename));
    end

    sessionMetadata = config.SessionMetadata;
    sessionMetadata = setIfMissing(sessionMetadata, ...
        'session_description', sessionObject.Description);
    sessionMetadata = setIfMissing(sessionMetadata, ...
        'identifier', strjoin([string(currentProject.Name), ...
        string(sessionObject.subjectID), string(sessionObject.sessionID)], '_'));
    sessionMetadata = setIfMissing(sessionMetadata, ...
        'session_start_time', getSessionStartTime(sessionObject));
    sessionMetadata = setIfMissing(sessionMetadata, ...
        'general_session_id', sessionObject.sessionID);
    config.SessionMetadata = sessionMetadata;

    if isempty(fieldnames(config.SubjectMetadata))
        config.SubjectMetadata = getSubjectMetadata(sessionObject);
    end
end

function sessionStartTime = getSessionStartTime(sessionObject)
    sessionStartTime = sessionObject.Date;
    if isprop(sessionObject, 'Time') && ~isempty(sessionObject.Time)
        sessionStartTime = sessionStartTime + duration(char(sessionObject.Time));
    end

    if sessionStartTime.TimeZone == ""
        sessionStartTime.TimeZone = "UTC";
    end
end

function subjectMetadata = getSubjectMetadata(sessionObject)
    subjectMetadata = struct();

    try
        subjectInfo = sessionObject.getSubject();
    catch
        return
    end

    subjectMetadata.subject_id = subjectInfo.SubjectID;
    subjectMetadata.description = subjectInfo.Description;
    subjectMetadata.species = subjectInfo.Species;
    subjectMetadata.sex = subjectInfo.BiologicalSex;

    if ~isempty(subjectInfo.DateOfBirth)
        subjectMetadata.date_of_birth = subjectInfo.DateOfBirth;
        ageInDays = days(getSessionStartTime(sessionObject) - subjectInfo.DateOfBirth);
        subjectMetadata.age = sprintf('P%dD', round(ageInDays));
    end
end

function S = setIfMissing(S, fieldName, value)
    if ~isfield(S, fieldName) || isempty(S.(fieldName))
        S.(fieldName) = value;
    end
end

function dataItems = dataItemsToStruct(configItems)
    if isempty(configItems)
        dataItems = struct.empty;
        return
    end

    dataItems = repmat(configItems(1).toStruct(), numel(configItems), 1);
    for i = 2:numel(configItems)
        dataItems(i) = configItems(i).toStruct();
    end
end

function configurationFilePath = getConfigurationFilePath(configurationFolderPath, configurationFileName)
    defaultConfigurationFileName = "nwb_conversion_configuration.json";
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

    availableFiles = dir(fullfile(configurationFolderPath, '*.json'));
    if isempty(availableFiles)
        return
    end

    defaultConfigurationFilePath = string(fullfile( ...
        configurationFolderPath, defaultConfigurationFileName));
    if isfile(defaultConfigurationFilePath)
        configurationFilePath = defaultConfigurationFilePath;
    elseif isscalar(availableFiles)
        configurationFilePath = string(fullfile( ...
            availableFiles(1).folder, availableFiles(1).name));
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
