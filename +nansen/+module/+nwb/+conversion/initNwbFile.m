function nwbFilePath = initNwbFile(sessionObject, targetFolder, options)
    
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
