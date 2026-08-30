function defaults = loadMetadataDefaults(filePath)
%loadMetadataDefaults - Load project-wide metadata defaults from JSON
%   DEFAULTS = loadMetadataDefaults(filePath) reads the JSON file at
%   filePath and returns a struct suitable for applyDefaults on an
%   NWBFileConfiguration.
%
%   The file holds what every conversion in a project shares, under any
%   subset of the sections SessionMetadata, SubjectMetadata and
%   GeneralMetadata:
%
%       {
%         "SubjectMetadata": {
%           "species": "Mus musculus",
%           "strain": "129S6/C57BL6"
%         },
%         "GeneralMetadata": {
%           "institution": "University of Oslo",
%           "lab": "Example lab",
%           "experimenter": ["Lastname, Firstname"],
%           "keywords": ["patch-clamp", "hippocampus"],
%           "experiment_description": "..."
%         }
%       }
%
%   Values a session supplies win over these; the defaults only fill
%   gaps. That is also what NWB Inspector asks after: experimenter,
%   keywords and experiment description are per-project facts no session
%   object carries.
%
%   Errors:
%     nansen:nwb:invalidConfigFile - filePath does not hold valid JSON.
%     nansen:nwb:invalidMetadataDefaults - the JSON carries a field that
%                     is not a metadata section.
%
%   See also nansen.module.nwb.config.NWBFileConfiguration,
%   nansen.module.nwb.session.NWBSessionConfigBuilder

    arguments
        filePath (1,1) string {mustBeFile}
    end

    jsonText = fileread(filePath);

    try
        defaults = jsondecode(jsonText);
    catch cause
        exception = MException("nansen:nwb:invalidConfigFile", ...
            ['Could not read the metadata defaults ''%s'': the file is ', ...
             'not valid JSON.'], filePath);
        throw(addCause(exception, cause))
    end

    % Fail on an unknown section here, with the file named, rather than
    % letting a typo like "GeneralMetdata" silently contribute nothing.
    sectionNames = ["SessionMetadata", "SubjectMetadata", "GeneralMetadata"];
    unknownFields = setdiff(string(fieldnames(defaults)), sectionNames);
    if ~isempty(unknownFields)
        error("nansen:nwb:invalidMetadataDefaults", ...
            ['''%s'' contains the section ''%s'', but metadata defaults ', ...
             'may only carry: %s.'], filePath, unknownFields(1), ...
            strjoin(sectionNames, ", "))
    end
end
