classdef NWBSessionConfigBuilder
%NWBSessionConfigBuilder - Build a conversion configuration from a session
%   NWBSessionConfigBuilder turns a NANSEN session into an
%   NWBFileConfiguration: it works out where the NWB file goes, fills in
%   the session, subject and general metadata the project already holds,
%   and records for each data item what NANSEN knows about its source.
%
%   This is where the module's advantage over a standalone converter
%   lives. A project that has been set up in the normal way already knows
%   the subject, the session time, and which file each variable comes
%   from, so none of that has to be entered again at export time.
%
%   NWBSessionConfigBuilder functions:
%       buildConfig               - Build a configuration for one session
%       sourceInfoForItem         - Describe one variable's source
%       sourceInfoForVariable     - Describe a variable's source without a session
%       sourceInfoFromVariableInfo - Evidence from a variable model entry
%       subjectMetadataFromRecord - Map a subject record to NWB fields
%
%   See also nansen.module.nwb.config.NWBFileConfiguration,
%   nansen.module.nwb.conversion.NWBFileConverter

    methods (Static)

        function config = buildConfig(sessionObject, dataItems, options)
            %buildConfig - Build a configuration for one session
            %   CONFIG = buildConfig(sessionObject,dataItems) returns the
            %   configuration for converting sessionObject, with the
            %   file-level metadata filled in from the session and the
            %   source of each item in dataItems described from the
            %   project's variable model. A source field the variable
            %   model leaves empty keeps the value the item was configured
            %   with.
            %
            %   CONFIG = buildConfig(...,TimeZone=ZONE) also says which
            %   time zone the session's date and time are in. It defaults
            %   to "local", since a session folder records neither.
            %
            %   CONFIG = buildConfig(...,WriteMode=MODE) also says whether
            %   to overwrite the NWB file or append to it.
            %
            %   CONFIG = buildConfig(...,ProjectName=NAME) also sets the
            %   project the identifier is built from. It defaults to the
            %   current project.
            %
            %   CONFIG = buildConfig(...,SubjectRecord=RECORD) also fills
            %   the subject metadata from a subject record, typically the
            %   session's row of the project's Subject metatable. See
            %   subjectMetadataFromRecord for the fields that are read.
            %   Age or date of birth matter in particular: NWB Inspector
            %   rates a subject without either as a critical problem.
            %
            %   CONFIG = buildConfig(...,MetadataDefaults=DEFAULTS) also
            %   fills metadata gaps from project-wide defaults. DEFAULTS
            %   is a struct with any of the sections SessionMetadata,
            %   SubjectMetadata and GeneralMetadata, or the path of a
            %   JSON file holding one. Values from the session win.
            %
            %   CONFIG = buildConfig(...,OutputPath=PATH) also says
            %   exactly where the NWB file is written, instead of the
            %   default location in the session folder.
            %
            %   CONFIG = buildConfig(...,OutputPathFcn=FCN) also derives
            %   the output path by calling FCN(sessionObject). This is the
            %   hook for a project with its own layout, such as one that
            %   groups output by figure or writes to a Processed data
            %   location. Give either OutputPath or OutputPathFcn, not
            %   both.
            %
            %   CONFIG = buildConfig(...,SessionStartTime=T) also sets the
            %   session start time to the zoned datetime T instead of
            %   combining the session's Date and Time. A session whose
            %   folder records no time of day gets it from the recording
            %   itself this way.
            %
            %   CONFIG = buildConfig(...,SubjectAge=TEXT) also sets the
            %   subject's age from TEXT, as a session table does when it
            %   carries the subject's state at the time of the session.
            %   It replaces any age the subject record gives, being the
            %   age at this session. TEXT is an ISO 8601 duration such as
            %   "P90D", a value and unit such as "6 month" or "90 days",
            %   or a range such as "6-8 weeks".
            %
            %   A converter argument whose value is, or contains, the text
            %   "${session.<name>}" takes that property of the session
            %   object in its place, so a column of the session table
            %   becomes a per-session argument, such as the cell_id of an
            %   intracellular electrode. Nested structs, struct arrays,
            %   cell arrays and string arrays are resolved too; a resolved
            %   value is always a string. Placeholders in the default
            %   arguments of the converter an item resolves to are filled
            %   the same way, so a lab converter can declare one.
            %
            %   Errors:
            %     nansen:nwb:missingSessionIdentifier - the session has no
            %                     subject or session ID.
            %     nansen:nwb:ambiguousOutputPath - both OutputPath and
            %                     OutputPathFcn were given.
            %     nansen:nwb:missingTimeZone - SessionStartTime has no time
            %                     zone.
            %     nansen:nwb:invalidSubjectAge - SubjectAge is not a
            %                     duration this function can read.
            %     nansen:nwb:unknownSessionPlaceholder - a converter
            %                     argument names a session property that
            %                     does not exist or has no value.
            %     nansen:nwb:invalidSessionPlaceholder - a converter
            %                     argument names a session property that
            %                     holds more than one value, such as a
            %                     vector or a cell array.

            arguments
                sessionObject (1,1)
                dataItems = nansen.module.nwb.config.NWBDataItemConfig.empty(0, 1)
                options.TimeZone (1,1) string = "local"
                options.WriteMode (1,1) string ...
                    {mustBeMember(options.WriteMode, ["overwrite", "append"])} = "overwrite"
                options.ProjectName (1,1) string = ""
                options.SubjectRecord = []
                options.MetadataDefaults = struct()
                options.OutputPath (1,1) string = ""
                options.OutputPathFcn = function_handle.empty
                options.SessionStartTime datetime = datetime.empty
                options.SubjectAge (1,1) string = ""
            end

            import nansen.module.nwb.session.NWBSessionConfigBuilder
            import nansen.module.nwb.internal.deepMerge

            NWBSessionConfigBuilder.assertSessionIdentifiers(sessionObject)

            projectName = options.ProjectName;
            if strlength(projectName) == 0
                projectName = string(nansen.getCurrentProject().Name);
            end

            dataItems = nansen.module.nwb.config.NWBDataItemConfig.fromAny(dataItems);
            for i = 1:numel(dataItems)
                dataItems(i).SourceInfo = mergeSourceInfo(dataItems(i).SourceInfo, ...
                    NWBSessionConfigBuilder.sourceInfoForItem(sessionObject, dataItems(i)));
                dataItems(i).ConverterArgs = ...
                    NWBSessionConfigBuilder.resolveSessionPlaceholders( ...
                    withPlaceholderDefaults(dataItems(i)), sessionObject);
            end

            subjectMetadata = NWBSessionConfigBuilder.subjectMetadata(sessionObject);
            if ~isempty(options.SubjectRecord)
                % The record fills what the session does not carry; the
                % session-derived subject_id wins over the record's.
                subjectMetadata = deepMerge( ...
                    NWBSessionConfigBuilder.subjectMetadataFromRecord(options.SubjectRecord), ...
                    subjectMetadata);
            end

            % An age recorded on the session describes the subject at that
            % session, which is more specific than anything the subject
            % record holds, so it wins.
            if strlength(strtrim(options.SubjectAge)) > 0
                subjectMetadata.age = ageTextToIso8601(options.SubjectAge);
            end

            config = nansen.module.nwb.config.NWBFileConfiguration( ...
                OutputPath=NWBSessionConfigBuilder.resolveOutputPath(sessionObject, options), ...
                SessionMetadata=NWBSessionConfigBuilder.sessionMetadata( ...
                    sessionObject, projectName, options.TimeZone, options.SessionStartTime), ...
                SubjectMetadata=subjectMetadata, ...
                GeneralMetadata=NWBSessionConfigBuilder.generalMetadata(sessionObject), ...
                DataItems=dataItems, ...
                WriteMode=options.WriteMode);

            config = config.applyDefaults( ...
                NWBSessionConfigBuilder.resolveMetadataDefaults(options.MetadataDefaults));

            % NWB requires a session description, and an empty one fails
            % validation later with less to go on than this. Substituted
            % only now, so a description from the defaults is not shadowed
            % by a placeholder.
            if strlength(string(config.SessionMetadata.session_description)) == 0
                config.SessionMetadata.session_description = "no description";
            end
        end

        function sourceInfo = sourceInfoForItem(sessionObject, dataItem)
            %sourceInfoForItem - Describe one variable's source
            %   sourceInfo = sourceInfoForItem(sessionObject,dataItem)
            %   returns what the project knows about where the item's data
            %   comes from: the class the file adapter produces, the
            %   adapter itself as a format name, and the file path.
            %
            %   This reads the variable model rather than loading data, so
            %   a configurator can offer sensible converters for a session
            %   whose recordings are far too large to load.

            sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();

            variableName = char(dataItem.VariableName);
            if isempty(variableName)
                return
            end

            try
                [filePath, variableInfo] = sessionObject.getDataFilePath(variableName);
            catch
                % A variable with no file yet, or one this session does
                % not have, is not an error while building a
                % configuration; the converter reports it if it needs it.
                return
            end

            if ~isempty(filePath)
                sourceInfo.Path = string(filePath);
            end

            if isstruct(variableInfo)
                evidence = nansen.module.nwb.session.NWBSessionConfigBuilder ...
                    .sourceInfoFromVariableInfo(variableInfo);
                sourceInfo.MatlabClass = evidence.MatlabClass;
                sourceInfo.Format = evidence.Format;
            end
        end

        function sourceInfo = sourceInfoForVariable(variableName, variableModel)
            %sourceInfoForVariable - Describe a variable's source without a session
            %   sourceInfo = sourceInfoForVariable(variableName) returns
            %   the class and format evidence the current project's
            %   variable model records for the variable: what a
            %   configurator needs to suggest converters before any
            %   session is chosen. There is no file path, since a path
            %   belongs to a session.
            %
            %   sourceInfo = sourceInfoForVariable(variableName,variableModel)
            %   reads the given model instead of the current project's.
            %
            %   The evidence is empty when there is no current project or
            %   the model has no such variable; neither is an error while
            %   configuring.

            arguments
                variableName (1,1) string
                variableModel = []
            end

            sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();

            if isempty(variableModel)
                try
                    variableModel = nansen.VariableModel();
                catch
                    return
                end
                if isempty(variableModel)
                    return
                end
            end

            try
                [variableInfo, isExistingEntry] = variableModel.getVariableStructure(char(variableName));
            catch
                return
            end
            if ~isExistingEntry
                return
            end

            sourceInfo = nansen.module.nwb.session.NWBSessionConfigBuilder ...
                .sourceInfoFromVariableInfo(variableInfo);
        end

        function sourceInfo = sourceInfoFromVariableInfo(variableInfo)
            %sourceInfoFromVariableInfo - Evidence from a variable model entry
            %   sourceInfo = sourceInfoFromVariableInfo(variableInfo) reads
            %   the DataType and FileAdapter fields of a variable model
            %   entry. A named file adapter identifies the source format:
            %   a Suite2p adapter means Suite2p output whatever the file is
            %   called. The default adapter says nothing.

            sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
            if ~isstruct(variableInfo)
                return
            end

            sourceInfo.MatlabClass = readField(variableInfo, "DataType");

            fileAdapter = readField(variableInfo, "FileAdapter");
            if fileAdapter ~= "Default"
                sourceInfo.Format = fileAdapter;
            end
        end

        function metadata = subjectMetadataFromRecord(subjectRecord)
            %subjectMetadataFromRecord - Map a subject record to NWB fields
            %   METADATA = subjectMetadataFromRecord(subjectRecord) reads
            %   the subject fields NWB wants from a subject record — an
            %   object or struct, typically a row of the project's Subject
            %   metatable — and returns them named and formatted the way
            %   NWB expects. Fields the record does not carry are simply
            %   absent from the result.
            %
            %   The names looked for, and what becomes of them:
            %       AgeDays       - age as an ISO 8601 duration, "P90D"
            %       BiologicalSex - sex as M, F, O or U
            %       DateOfBirth   - date_of_birth as a zoned ISO 8601
            %                       timestamp at local midnight; a birth
            %                       date carries no zone of its own, but
            %                       pynwb rejects a timestamp without one
            %       Genotype      - genotype
            %       Species       - species
            %       Strain        - strain
            %
            %   Nothing is guessed: a record without an age produces
            %   metadata without an age, and the validation step reports
            %   it. That is deliberate — an invented value in a shared
            %   file is worse than a named gap.
            %
            %   See also nansen.module.nwb.session.NWBSessionConfigBuilder.buildConfig

            arguments
                subjectRecord (1,1)
            end

            metadata = struct();

            ageDays = readRecordField(subjectRecord, "AgeDays");
            if isnumeric(ageDays) && isscalar(ageDays) && isfinite(ageDays) && ageDays >= 0
                metadata.age = "P" + string(ageDays) + "D";
            end

            sex = readRecordField(subjectRecord, "BiologicalSex");
            if ~isempty(sex)
                metadata.sex = mapBiologicalSex(sex);
            end

            dateOfBirth = readRecordField(subjectRecord, "DateOfBirth");
            if isdatetime(dateOfBirth) && isscalar(dateOfBirth) && ~isnat(dateOfBirth)
                if dateOfBirth.TimeZone == ""
                    dateOfBirth.TimeZone = "local";
                end
                metadata.date_of_birth = string(dateOfBirth, "uuuu-MM-dd'T'HH:mm:ssZ");
            end

            textFields = ["Genotype", "genotype"; "Species", "species"; "Strain", "strain"];
            for i = 1:size(textFields, 1)
                value = readRecordField(subjectRecord, textFields(i, 1));
                if (ischar(value) || isstring(value)) && strlength(string(value)) > 0
                    metadata.(textFields(i, 2)) = string(value);
                end
            end
        end
    end

    methods (Static, Access = private)

        function value = resolveSessionPlaceholders(value, sessionObject)
            %resolveSessionPlaceholders - Fill "${session.<name>}" from the session
            %
            %   A text that holds such a placeholder comes back as a string
            %   with the session's property in its place; a struct, or each
            %   element of a struct array, is resolved field by field, and
            %   a cell or string array element by element, keeping its
            %   type. jsondecode reads a JSON list of strings as a cell
            %   array. Anything else, such as a number, is returned as it
            %   is.

            import nansen.module.nwb.session.NWBSessionConfigBuilder

            if isstruct(value)
                % A struct array, such as a JSON list of objects, is
                % resolved one element at a time: value.(name) on the
                % whole array is a comma-separated list, not one value.
                for elementIndex = 1:numel(value)
                    for fieldName = string(fieldnames(value))'
                        value(elementIndex).(fieldName) = NWBSessionConfigBuilder ...
                            .resolveSessionPlaceholders(value(elementIndex).(fieldName), sessionObject);
                    end
                end
            elseif iscell(value)
                for elementIndex = 1:numel(value)
                    value{elementIndex} = NWBSessionConfigBuilder ...
                        .resolveSessionPlaceholders(value{elementIndex}, sessionObject);
                end
            elseif isstring(value) && ~isscalar(value)
                for elementIndex = 1:numel(value)
                    value(elementIndex) = NWBSessionConfigBuilder ...
                        .resolveSessionPlaceholders(value(elementIndex), sessionObject);
                end
            elseif (ischar(value) || isstring(value)) && isscalar(string(value))
                text = string(value);
                if contains(text, "${session.")
                    value = substituteSessionPlaceholders(text, sessionObject);
                end
            end
        end

        function outputPath = resolveOutputPath(sessionObject, options)
            %resolveOutputPath - Decide where this session's file is written

            hasExplicitPath = strlength(options.OutputPath) > 0;
            hasPathFunction = ~isempty(options.OutputPathFcn);

            if hasExplicitPath && hasPathFunction
                error("nansen:nwb:ambiguousOutputPath", ...
                    ['Both OutputPath and OutputPathFcn were given, and ', ...
                     'they would disagree. Give one or the other.'])
            end

            if hasExplicitPath
                outputPath = options.OutputPath;
                return
            end

            if hasPathFunction
                outputPath = string(options.OutputPathFcn(sessionObject));
                if ~isscalar(outputPath) || strlength(strtrim(outputPath)) == 0
                    error("nansen:nwb:invalidOutputPath", ...
                        ['OutputPathFcn must return one non-empty path, ', ...
                         'but returned %s.'], class(outputPath))
                end
                return
            end

            outputPath = ...
                nansen.module.nwb.session.NWBSessionConfigBuilder.defaultOutputPath(sessionObject);
        end

        function outputPath = defaultOutputPath(sessionObject)
            %defaultOutputPath - The session folder, by the BIDS convention

            saveFolder = sessionObject.getSessionFolder('', 'create');

            % The filename follows the BIDS and DANDI convention. The IDs
            % are converted to text first because NANSEN does not type
            % them: sprintf would write a numeric ID as the character with
            % that code rather than as digits.
            fileName = sprintf("sub-%s_ses-%s.nwb", ...
                string(sessionObject.subjectID), string(sessionObject.sessionID));
            outputPath = string(fullfile(saveFolder, fileName));
        end

        function defaults = resolveMetadataDefaults(defaults)
            %resolveMetadataDefaults - Accept a struct, or load a JSON file

            if isstring(defaults) || ischar(defaults)
                defaults = nansen.module.nwb.config.loadMetadataDefaults(string(defaults));
            end

            if ~isstruct(defaults) || ~isscalar(defaults)
                error("nansen:nwb:invalidMetadataDefaults", ...
                    ['MetadataDefaults must be a struct of metadata ', ...
                     'sections or the path of a JSON file holding one, ', ...
                     'but was %s.'], class(defaults))
            end
        end

        function metadata = sessionMetadata(sessionObject, projectName, timeZone, explicitStartTime)
            %sessionMetadata - NWBFile-level metadata for the session

            import nansen.module.nwb.session.NWBSessionConfigBuilder

            metadata = struct();
            metadata.identifier = strjoin([projectName, ...
                string(sessionObject.subjectID), string(sessionObject.sessionID)], "_");
            metadata.session_description = string(sessionObject.Description);
            if isempty(explicitStartTime)
                metadata.session_start_time = ...
                    NWBSessionConfigBuilder.sessionStartTime(sessionObject, timeZone);
            else
                metadata.session_start_time = ...
                    NWBSessionConfigBuilder.zonedStartTime(explicitStartTime);
            end
            metadata.general_session_id = string(sessionObject.sessionID);
        end

        function startTime = zonedStartTime(startTime)
            %zonedStartTime - Require an explicit start time to carry a zone
            %
            %   A time read from a recording's header carries the offset
            %   the recording software wrote, or none; one without a zone
            %   cannot be placed on an absolute timeline and is refused
            %   here rather than written as if it were.

            if ~isscalar(startTime) || isnat(startTime)
                error("nansen:nwb:invalidSessionStartTime", ...
                    "SessionStartTime must be one datetime, not NaT.")
            end
            if startTime.TimeZone == ""
                error("nansen:nwb:missingTimeZone", ...
                    ['SessionStartTime has no time zone. Set one, for ', ...
                     'example datetime(t, TimeZone="local").'])
            end
        end

        function metadata = subjectMetadata(sessionObject)
            %subjectMetadata - Metadata describing the subject
            %
            %   Only the subject identifier is read from the session.
            %   Species, sex and age live on the subject record rather
            %   than the session; pass it as SubjectRecord to have them
            %   filled in. Guessing them here would put unverified values
            %   in the file.

            metadata = struct("subject_id", string(sessionObject.subjectID));
        end

        function metadata = generalMetadata(sessionObject)
            %generalMetadata - Institution, lab and experiment metadata

            metadata = struct();

            experiment = string(sessionObject.Experiment);
            if strlength(experiment) > 0
                metadata.experiment_description = experiment;
            end

            protocol = string(sessionObject.Protocol);
            if strlength(protocol) > 0
                metadata.protocol = protocol;
            end
        end

        function sessionStartTime = sessionStartTime(sessionObject, timeZone)
            %sessionStartTime - Combine the session date and time, with a zone
            %
            %   NWB records session_start_time as an ISO 8601 timestamp.
            %   matnwb writes the UTC offset only when the datetime
            %   carries a time zone, so an unzoned value produces a
            %   timestamp that cannot be placed on an absolute timeline.
            %   A session folder records neither zone, so one is attached.

            if isempty(sessionObject.Date) || isempty(sessionObject.Time)
                error("nansen:nwb:missingSessionStartTime", ...
                    ['Session ''%s'' has no date or time, so ', ...
                     'session_start_time cannot be determined. Set the Date ', ...
                     'and Time metadata for the session before writing an ', ...
                     'NWB file.'], sessionObject.sessionID)
            end

            % DataLocationModel.getDate parses a datetime only when the
            % "Experiment Date" metadata variable has a string format
            % configured. Without one it returns the raw substring, which
            % would fail later with an error that does not point here.
            if ~isdatetime(sessionObject.Date)
                error("nansen:nwb:unparsedSessionDate", ...
                    ['Session ''%s'' has a date of type %s rather than ', ...
                     'datetime, so session_start_time cannot be determined. ', ...
                     'Configure a string format for the "Experiment Date" ', ...
                     'metadata variable so that it is parsed as a date.'], ...
                    sessionObject.sessionID, class(sessionObject.Date))
            end

            sessionStartTime = sessionObject.Date + sessionTimeOfDay(sessionObject);
            sessionStartTime.TimeZone = timeZone;
        end

        function assertSessionIdentifiers(sessionObject)
            %assertSessionIdentifiers - Require a subject and session ID
            %
            %   Both the filename and the NWB identifier are built from
            %   these. strjoin drops a blank component silently, so a
            %   session with no subject ID would produce a filename and an
            %   identifier that collide with any other subject sharing
            %   that session ID. NWB identifiers must be globally unique.

            missingNames = string.empty;

            if isBlank(sessionObject.subjectID)
                missingNames(end+1) = "subjectID";
            end
            if isBlank(sessionObject.sessionID)
                missingNames(end+1) = "sessionID";
            end

            if ~isempty(missingNames)
                error("nansen:nwb:missingSessionIdentifier", ...
                    ['Session is missing a value for %s. These identify the ', ...
                     'NWB file and form its globally unique identifier. Set ', ...
                     'them for this session, or configure the data location ', ...
                     'so they can be detected from the session folder, ', ...
                     'before writing an NWB file.'], strjoin(missingNames, " and "))
            end
        end
    end
end

function sourceInfo = mergeSourceInfo(configuredInfo, sessionInfo)
%mergeSourceInfo - The session's source evidence, with configured values filling gaps
%
%   The variable model knows the file a variable comes from in this
%   session, so its values win. A file the model does not know about,
%   such as one a hand-written configuration points at, keeps its
%   configured path and format.

    sourceInfo = sessionInfo;
    for fieldName = string(fieldnames(sessionInfo))'
        % Path holds one or more paths, so a field is blank when it holds
        % no text at all.
        sessionValue = string(sourceInfo.(fieldName));
        isBlank = isempty(sessionValue) || all(strlength(sessionValue) == 0);
        if isBlank && isfield(configuredInfo, fieldName)
            sourceInfo.(fieldName) = configuredInfo.(fieldName);
        end
    end
end

function value = readField(S, fieldName)
%readField - Read one struct field as text, or "" when it is absent

    if isfield(S, fieldName) && ~isempty(S.(fieldName))
        value = string(S.(fieldName));
    else
        value = "";
    end
end

function value = readRecordField(record, fieldName)
%readRecordField - Read a field or property of a record, or [] without it
%
%   A subject record may be a struct or an object depending on how the
%   metatable hands it over, and either may lack any given field.

    value = [];
    try
        if isstruct(record)
            if isfield(record, fieldName)
                value = record.(fieldName);
            end
        elseif isprop(record, fieldName)
            value = record.(fieldName);
        end
    catch
        % A property whose get method fails carries no usable value.
        value = [];
    end
end

function isoDuration = ageTextToIso8601(ageText)
%ageTextToIso8601 - Express an age as an ISO 8601 duration
%
%   NWB records a subject's age as an ISO 8601 duration, "P90D", or a
%   range of two, "P6W/P8W". A session table records it the way the
%   source did: "6 month", "90 days", "6-8 weeks". Whole numbers only; a
%   fraction cannot be written in a duration without inventing precision.

    text = strtrim(ageText);

    if startsWith(text, "P")
        % A duration, or a range of two, each with at least one number
        % and its designator, such as "P90D", "P1Y6M" or "P6W/P8W".
        durationPattern = '^P(?=\d|T\d)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(?=\d)(\d+H)?(\d+M)?(\d+S)?)?$';
        parts = split(text, "/");
        isDuration = numel(parts) <= 2 && all(arrayfun( ...
            @(part) ~isempty(regexp(char(part), durationPattern, 'once')), parts));
        if ~isDuration
            error("nansen:nwb:invalidSubjectAge", ...
                ['''%s'' is not an ISO 8601 duration. Give one such as ', ...
                 '"P90D" or "P6W/P8W", or a value and unit such as ', ...
                 '"6 month".'], ageText)
        end
        isoDuration = text;
        return
    end

    % A range and a single value are matched by separate patterns: an
    % optional named group is absent from the result for string input,
    % which makes it awkward to test for.
    rangeMatch = regexp(text, '^(?<low>\d+)\s*-\s*(?<high>\d+)\s*(?<unit>[A-Za-z]+)$', ...
        'names', 'once');
    if ~isempty(rangeMatch)
        unitLetter = ageUnitLetter(lower(rangeMatch.unit), ageText);
        isoDuration = "P" + rangeMatch.low + unitLetter + "/P" + rangeMatch.high + unitLetter;
        return
    end

    singleMatch = regexp(text, '^(?<value>\d+)\s*(?<unit>[A-Za-z]+)$', 'names', 'once');
    if isempty(singleMatch)
        error("nansen:nwb:invalidSubjectAge", ...
            ['''%s'' is not an age this module can write. Give an ISO 8601 ', ...
             'duration such as "P90D", or a value and unit such as ', ...
             '"6 month", "90 days" or "6-8 weeks".'], ageText)
    end

    isoDuration = "P" + singleMatch.value + ageUnitLetter(lower(singleMatch.unit), ageText);
end

function letter = ageUnitLetter(unit, ageText)
%ageUnitLetter - The ISO 8601 designator for a unit word

    switch unit
        case {"day", "days", "d"}
            letter = "D";
        case {"week", "weeks", "wk", "wks", "w"}
            letter = "W";
        case {"month", "months", "mo", "mos"}
            letter = "M";
        case {"year", "years", "yr", "yrs", "y"}
            letter = "Y";
        otherwise
            error("nansen:nwb:invalidSubjectAge", ...
                ['''%s'' names the unit ''%s'', which is not days, weeks, ', ...
                 'months or years.'], ageText, unit)
    end
end

function tf = isBlank(value)
%isBlank - True if a value holds no usable text
%
%   A missing string counts: strlength of one is NaN, which no comparison
%   catches, and strjoin refuses it further down.

    text = strtrim(string(value));
    tf = isempty(text) || ~isscalar(text) || ismissing(text) || strlength(text) == 0;
end

function timeOfDay = sessionTimeOfDay(sessionObject)
%sessionTimeOfDay - The session's time of day as a duration
%
%   DataLocationModel.getTime returns NaT when the time could not be
%   parsed, and the raw substring when "Experiment Time" has no string
%   format configured. Neither is a time of day, and both are reported
%   here rather than by a parse error further down that does not name
%   the session.

    value = sessionObject.Time;

    if isdatetime(value)
        if ~isscalar(value) || isnat(value)
            throwUnparsedTime(sessionObject, "NaT")
        end
        timeOfDay = timeofday(value);
        return
    end

    if isduration(value)
        timeOfDay = value;
        return
    end

    try
        timeOfDay = duration(string(value));
    catch
        throwUnparsedTime(sessionObject, string(value))
    end
end

function throwUnparsedTime(sessionObject, shownValue)
%throwUnparsedTime - Report a session time that is not a time of day

    error("nansen:nwb:unparsedSessionTime", ...
        ['Session ''%s'' has a time of ''%s'', which is not a time of day, ', ...
         'so session_start_time cannot be determined. Configure a string ', ...
         'format for the "Experiment Time" metadata variable so that it ', ...
         'is parsed as a time.'], sessionObject.sessionID, shownValue)
end

function sex = mapBiologicalSex(value)
%mapBiologicalSex - Express a recorded sex the way NWB spells it
%
%   NWB uses the single letters M, F, O and U. Full words are mapped,
%   the letters pass through, and anything else is unknown rather than
%   guessed.

    value = upper(strtrim(string(value)));

    if value == "MALE"
        sex = "M";
    elseif value == "FEMALE"
        sex = "F";
    elseif ismember(value, ["M", "F", "O", "U"])
        sex = value;
    else
        sex = "U";
    end
end

function converterArgs = withPlaceholderDefaults(dataItem)
%withPlaceholderDefaults - An item's arguments over defaults that hold placeholders
%
%   The runner lays an item's ConverterArgs over its converter's
%   DefaultConverterArgs, after the session is gone. Defaults holding a
%   session placeholder are therefore merged in here, by the runner's rule
%   that an item's argument replaces the default of the same name, so the
%   placeholders are resolved with the item's own. Other defaults are left
%   to the runner.

    converterArgs = dataItem.ConverterArgs;
    try
        descriptor = nansen.module.nwb.conversion.ConverterRegistry.instance() ...
            .resolveForItem(dataItem);
    catch
        % An item no converter resolves is reported when it converts.
        return
    end

    defaultArgs = descriptor.DefaultConverterArgs;
    if ~holdsPlaceholder(defaultArgs)
        return
    end

    itemArgs = converterArgs;
    converterArgs = defaultArgs;
    for fieldName = string(fieldnames(itemArgs))'
        converterArgs.(fieldName) = itemArgs.(fieldName);
    end
end

function tf = holdsPlaceholder(value)
%holdsPlaceholder - Whether a value holds "${session.<name>}" anywhere

    if isstruct(value)
        tf = any(arrayfun(@(element) any(structfun(@holdsPlaceholder, element)), value));
    elseif iscell(value)
        tf = any(cellfun(@holdsPlaceholder, value));
    elseif ischar(value) || isstring(value)
        tf = any(contains(string(value), "${session."));
    else
        tf = false;
    end
end

function text = substituteSessionPlaceholders(text, sessionObject)
%substituteSessionPlaceholders - Replace every "${session.<name>}" in a text

    placeholders = regexp(text, '\$\{session\.(?<name>\w+)\}', 'names');

    for k = 1:numel(placeholders)
        name = placeholders(k).name;
        text = replace(text, "${session." + name + "}", ...
            sessionPropertyText(sessionObject, name));
    end
end

function text = sessionPropertyText(sessionObject, name)
%sessionPropertyText - A session property as one text, or an error
%
%   The session is a NANSEN session object, whose table columns are
%   properties, or a struct standing in for one. A property that is
%   missing or empty is an error rather than empty text: an argument
%   silently left blank would reach the file unnoticed. A property that
%   holds more than one value has no single text to put in its place.

    if isstruct(sessionObject)
        hasProperty = isfield(sessionObject, name);
    else
        hasProperty = isprop(sessionObject, name);
    end
    if ~hasProperty
        error("nansen:nwb:unknownSessionPlaceholder", ...
            ['The converter argument placeholder "${session.%s}" cannot be ', ...
             'filled: session ''%s'' has no property %s. Add the column to ', ...
             'the session table or remove the placeholder.'], ...
            name, string(sessionObject.sessionID), name)
    end

    value = sessionObject.(name);
    isSingleValue = (ischar(value) && isrow(value)) || (isscalar(value) && ...
        (isstring(value) || isnumeric(value) || islogical(value) ...
        || isdatetime(value) || iscategorical(value)));
    if ~isempty(value) && ~isSingleValue
        error("nansen:nwb:invalidSessionPlaceholder", ...
            ['The converter argument placeholder "${session.%s}" cannot be ', ...
             'filled: the property %s of session ''%s'' is a %s of size %s, ', ...
             'not one text or number.'], ...
            name, name, string(sessionObject.sessionID), class(value), mat2str(size(value)))
    end

    text = string.empty;
    if ~isempty(value)
        text = string(value);
    end
    if isempty(text) || ismissing(text) || strlength(text) == 0
        error("nansen:nwb:unknownSessionPlaceholder", ...
            ['The converter argument placeholder "${session.%s}" cannot be ', ...
             'filled: session ''%s'' has no value for %s. Fill in the column ', ...
             'for this session or remove the placeholder.'], ...
            name, string(sessionObject.sessionID), name)
    end
end
