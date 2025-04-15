function nwbFile = initNwbFile(sessionObject)
% initNwbFile - Initializes an NWB file using session details and metadata.
% 
% Syntax:
%   nwbFilePath = initNwbFile(sessionObject, targetFolder, options)
%
% Input Arguments:
%   sessionObject - An object representing the session information.
%
% Output Arguments:
%   nwbFilePath - The full file path of the created NWB file.

    arguments
        sessionObject
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
end
