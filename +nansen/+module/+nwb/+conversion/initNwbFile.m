function nwbFilePath = initNwbFile(sessionObject, targetFolder, options)
% initNwbFile - Initializes an NWB file using session details and metadata.
% 
% Syntax:
%   nwbFilePath = initNwbFile(sessionObject, targetFolder, options)
%
% Input Arguments:
%   sessionObject - An object representing the session information.
%   targetFolder - The folder path where the NWB file will be saved.
%   options - A structure containing additional options for file creation.
%     options.FilenameSuffix - Optional string suffix for the file name.
%
% Output Arguments:
%   nwbFilePath - The full file path of the created NWB file.

    arguments
        sessionObject
        targetFolder (1,1) string {mustBeFolder}
        options.FilenameSuffix (1,:) string = string.empty
    end
    
    nwbFileMetadata = nansen.module.nwb.conversion.loadMetadata("NWBFile");
    assert(iscell(nwbFileMetadata) && mod(numel(nwbFileMetadata), 2) == 0, ...
        "Expected cell array of name-value pairs")

    nwbFile = NwbFile( ...
        'session_description', sessionObject.Description, ...
        'identifier', sessionObject.sessionID, ...
        'session_start_time', sessionObject.Date, ...
        nwbFileMetadata{:});
    
    subjectInfo = sessionObject.getSubject();

    % Assumes age reference is birth
    if ~isempty( subjectInfo.DateOfBirth )
        ageInDays = days(sessionObject.Date - subjectInfo.DateOfBirth);
        ageInDaysText = sprintf('P%dD', ageInDays);
    else
        ageInDaysText = '';
    end

    subject = types.core.Subject( ...
        'subject_id', subjectInfo.SubjectID, ...
        'age', ageInDaysText, ...
        'description', subjectInfo.Description, ...
        'species', subjectInfo.Species, ...
        'date_of_birth', subjectInfo.DateOfBirth, ...
        'sex', subjectInfo.BiologicalSex ...
    );

    nwbFile.general_subject = subject;

    nwbFilePath = createNwbFilePath(targetFolder, ...
        "SubjectID", subjectInfo.SubjectID, ...
        "SessionID", sessionObject.sessionID, ...
        "FilenameSuffix", options.FilenameSuffix);

    nwbExport(nwbFile, nwbFilePath)
end

function nwbFilePath = createNwbFilePath(targetFolder, options)
% createNwbFilePath - Creates a file path for the NWB file based on
% the specified folder and options.
%
% Syntax:
%   nwbFilePath = createNwbFilePath(targetFolder, options)
%
% Input Arguments:
%   targetFolder - The folder path where the NWB file will be saved.
%   options - A structure containing options for file naming.
%     options.SessionID - The session identifier.
%     options.SubjectID - The subject identifier.
%     options.FilenameSuffix - Optional string suffix for the file name.
%
% Output Arguments:
%   nwbFilePath - The constructed path for the NWB file.

    arguments
        targetFolder
        options.SessionID
        options.SubjectID
        options.FilenameSuffix (1,:) string = string.empty
    end

    subjectId = options.SubjectID;
    if startsWith(options.SessionID, subjectId)
        sessionId = replace(options.SessionID, options.SubjectID, '');
        if startsWith(sessionId, '_')
            sessionId = sessionId(2:end);
        end
    else
        sessionId = options.SessionID;
    end
    
    subjectPart = sprintf("sub-%s", subjectId);
    sessionPart = sprintf("ses-%s", sessionId);

    fileName = join([subjectPart, sessionPart, options.FilenameSuffix], "_");
    nwbFilePath = fullfile(targetFolder, fileName+".nwb");
end
