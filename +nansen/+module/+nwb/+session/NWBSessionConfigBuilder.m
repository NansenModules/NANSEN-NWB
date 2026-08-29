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
%       buildConfig       - Build a configuration for one session
%       sourceInfoForItem - Describe one variable's source
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
            %   project's variable model.
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
            %   Errors:
            %     nansen:nwb:missingSessionIdentifier - the session has no
            %                     subject or session ID.

            arguments
                sessionObject (1,1)
                dataItems = nansen.module.nwb.config.NWBDataItemConfig.empty(0, 1)
                options.TimeZone (1,1) string = "local"
                options.WriteMode (1,1) string ...
                    {mustBeMember(options.WriteMode, ["overwrite", "append"])} = "overwrite"
                options.ProjectName (1,1) string = ""
            end

            import nansen.module.nwb.session.NWBSessionConfigBuilder

            NWBSessionConfigBuilder.assertSessionIdentifiers(sessionObject)

            projectName = options.ProjectName;
            if strlength(projectName) == 0
                projectName = string(nansen.getCurrentProject().Name);
            end

            dataItems = nansen.module.nwb.config.NWBDataItemConfig.fromAny(dataItems);
            for i = 1:numel(dataItems)
                dataItems(i).SourceInfo = ...
                    NWBSessionConfigBuilder.sourceInfoForItem(sessionObject, dataItems(i));
            end

            config = nansen.module.nwb.config.NWBFileConfiguration( ...
                OutputPath=NWBSessionConfigBuilder.outputPathFor(sessionObject), ...
                SessionMetadata=NWBSessionConfigBuilder.sessionMetadata( ...
                    sessionObject, projectName, options.TimeZone), ...
                SubjectMetadata=NWBSessionConfigBuilder.subjectMetadata(sessionObject), ...
                GeneralMetadata=NWBSessionConfigBuilder.generalMetadata(sessionObject), ...
                DataItems=dataItems, ...
                WriteMode=options.WriteMode);
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
                sourceInfo.MatlabClass = readField(variableInfo, "DataType");

                % A named file adapter identifies the source format: a
                % Suite2p adapter means Suite2p output whatever the file
                % is called. The default adapter says nothing.
                fileAdapter = readField(variableInfo, "FileAdapter");
                if fileAdapter ~= "Default"
                    sourceInfo.Format = fileAdapter;
                end
            end
        end
    end

    methods (Static, Access = private)

        function outputPath = outputPathFor(sessionObject)
            %outputPathFor - Where this session's NWB file is written

            saveFolder = sessionObject.getSessionFolder('', 'create');

            % The filename follows the BIDS and DANDI convention.
            fileName = sprintf("sub-%s_ses-%s.nwb", ...
                sessionObject.subjectID, sessionObject.sessionID);
            outputPath = string(fullfile(saveFolder, fileName));
        end

        function metadata = sessionMetadata(sessionObject, projectName, timeZone)
            %sessionMetadata - NWBFile-level metadata for the session

            import nansen.module.nwb.session.NWBSessionConfigBuilder

            metadata = struct();
            metadata.identifier = strjoin([projectName, ...
                string(sessionObject.subjectID), string(sessionObject.sessionID)], "_");
            metadata.session_description = string(sessionObject.Description);
            metadata.session_start_time = ...
                NWBSessionConfigBuilder.sessionStartTime(sessionObject, timeZone);
            metadata.general_session_id = string(sessionObject.sessionID);

            % NWB requires a session description, and an empty one fails
            % validation later with less to go on than this.
            if strlength(metadata.session_description) == 0
                metadata.session_description = "no description";
            end
        end

        function metadata = subjectMetadata(sessionObject)
            %subjectMetadata - Metadata describing the subject
            %
            %   Only the subject identifier is read from the session.
            %   Species, sex and age live on the animal record rather than
            %   the session, and are added by the configurator; guessing
            %   them here would put unverified values in the file.

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

            sessionStartTime = sessionObject.Date + duration(char(sessionObject.Time));
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

function value = readField(S, fieldName)
%readField - Read one field as text, or "" when it is absent

    if isfield(S, fieldName) && ~isempty(S.(fieldName))
        value = string(S.(fieldName));
    else
        value = "";
    end
end

function tf = isBlank(value)
%isBlank - True if a value holds no usable text

    text = strtrim(string(value));
    tf = isempty(text) || ~isscalar(text) || strlength(text) == 0;
end
