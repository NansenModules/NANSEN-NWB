classdef NWBFileConfiguration
%NWBFileConfiguration - Configuration for writing one NWB file
%   OBJ = NWBFileConfiguration() creates a configuration with default
%   values. The configuration holds the file-level metadata and the list
%   of data items that make up one NWB file.
%
%   OBJ = NWBFileConfiguration(Name=VALUE) also sets properties by name.
%   Any subset of the properties below may be given.
%
%   NWBFileConfiguration functions:
%       toStruct      - Convert to a struct for serialization
%       fromStruct    - Build a configuration from a struct
%       fromAny       - Accept either a configuration or a struct
%       applyDefaults - Fill metadata gaps from project-wide defaults
%
%   NWBFileConfiguration properties:
%       Version         - Schema version of this configuration
%       OutputPath      - Path of the NWB file to write
%       SessionMetadata - NWBFile-level metadata for the session
%       SubjectMetadata - Metadata describing the subject
%       GeneralMetadata - Institution, lab, experimenter and the like
%       DataItems       - Items to convert into the file
%       WriteMode       - Whether to overwrite or append to OutputPath
%
%   See also nansen.module.nwb.config.NWBDataItemConfig,
%   nansen.module.nwb.config.saveConfiguration,
%   nansen.module.nwb.config.loadConfiguration

    properties (Constant, Access = private)
        SCHEMA_VERSION = uint32(2) % Version stamped on new configurations
    end

    properties
        Version (1,1) uint32 = 2            % Schema version of this configuration
        OutputPath (1,1) string = ""        % Path of the NWB file to write
        SessionMetadata (1,1) struct = struct() % NWBFile-level metadata for the session
        SubjectMetadata (1,1) struct = struct() % Metadata describing the subject
        GeneralMetadata (1,1) struct = struct() % Institution, lab, experimenter and the like
        DataItems (:,1) nansen.module.nwb.config.NWBDataItemConfig = ...
            nansen.module.nwb.config.NWBDataItemConfig.empty(0, 1) % Items to convert into the file
        WriteMode (1,1) string {mustBeMember(WriteMode, ["overwrite", "append"])} = "overwrite" % Whether to overwrite or append to OutputPath
    end

    methods
        function obj = NWBFileConfiguration(options)
            arguments
                options.Version (1,1) uint32 = ...
                    nansen.module.nwb.config.NWBFileConfiguration.SCHEMA_VERSION
                options.OutputPath (1,1) string = ""
                options.SessionMetadata (1,1) struct = struct()
                options.SubjectMetadata (1,1) struct = struct()
                options.GeneralMetadata (1,1) struct = struct()
                options.DataItems = ...
                    nansen.module.nwb.config.NWBDataItemConfig.empty(0, 1)
                options.WriteMode (1,1) string ...
                    {mustBeMember(options.WriteMode, ["overwrite", "append"])} = "overwrite"
            end

            obj.Version = options.Version;
            obj.OutputPath = options.OutputPath;
            obj.SessionMetadata = options.SessionMetadata;
            obj.SubjectMetadata = options.SubjectMetadata;
            obj.GeneralMetadata = options.GeneralMetadata;
            obj.DataItems = ...
                nansen.module.nwb.config.NWBDataItemConfig.fromAny(options.DataItems);
            obj.WriteMode = options.WriteMode;
        end

        function obj = applyDefaults(obj, defaults)
            %applyDefaults - Fill metadata gaps from project-wide defaults
            %   OBJ = applyDefaults(OBJ,DEFAULTS) lays the configuration's
            %   metadata over DEFAULTS, so values already in the
            %   configuration win and the defaults supply what is missing.
            %
            %   DEFAULTS is a struct with any subset of the fields
            %   SessionMetadata, SubjectMetadata and GeneralMetadata,
            %   holding the values a whole project shares: institution,
            %   lab, experimenter, keywords, species, and the like. They
            %   belong in one place rather than repeated in every
            %   configuration, both to save the typing and so a correction
            %   lands everywhere at once.
            %
            %   Errors:
            %     nansen:nwb:invalidMetadataDefaults - DEFAULTS carries a
            %                     field that is not a metadata section.
            %
            %   See also nansen.module.nwb.config.loadMetadataDefaults,
            %   nansen.module.nwb.internal.deepMerge

            arguments
                obj
                defaults (1,1) struct
            end

            sectionNames = ["SessionMetadata", "SubjectMetadata", "GeneralMetadata"];

            unknownFields = setdiff(string(fieldnames(defaults)), sectionNames);
            if ~isempty(unknownFields)
                error("nansen:nwb:invalidMetadataDefaults", ...
                    ['Metadata defaults may only carry the sections %s, ', ...
                     'but ''%s'' was given. Check the spelling in the ', ...
                     'defaults file.'], strjoin(sectionNames, ", "), ...
                    unknownFields(1))
            end

            for i = 1:numel(sectionNames)
                sectionName = sectionNames(i);
                if isfield(defaults, sectionName)
                    obj.(sectionName) = nansen.module.nwb.internal.deepMerge( ...
                        defaults.(sectionName), obj.(sectionName));
                end
            end
        end

        function S = toStruct(obj)
            %toStruct - Convert to a struct for serialization
            %   S = toStruct(OBJ) returns a scalar struct holding the
            %   properties of OBJ, with DataItems as a struct array,
            %   ready for JSONENCODE.

            S = struct();
            S.Version = obj.Version;
            S.OutputPath = obj.OutputPath;
            S.SessionMetadata = obj.SessionMetadata;
            S.SubjectMetadata = obj.SubjectMetadata;
            S.GeneralMetadata = obj.GeneralMetadata;
            S.WriteMode = obj.WriteMode;

            if isempty(obj.DataItems)
                dataItems = struct.empty(0, 1);
            else
                dataItems = repmat(obj.DataItems(1).toStruct(), numel(obj.DataItems), 1);
                for i = 2:numel(obj.DataItems)
                    dataItems(i) = obj.DataItems(i).toStruct();
                end
            end
            S.DataItems = dataItems;
        end
    end

    methods (Static)
        function obj = fromStruct(S)
            %fromStruct - Build a configuration from a struct
            %   OBJ = fromStruct(S) returns the configuration described by
            %   the scalar struct S. Missing fields take their default
            %   values.
            %
            %   Errors:
            %     nansen:nwb:unsupportedConfigVersion - S was written by a
            %                     newer schema than this release reads.

            arguments
                S (1,1) struct
            end

            import nansen.module.nwb.config.NWBFileConfiguration
            import nansen.module.nwb.config.NWBDataItemConfig

            S = NWBFileConfiguration.fillMissingFields(S);

            % A configuration from a newer release may use fields or
            % semantics this one does not implement. Reading it as if it
            % were current would silently drop them.
            if uint32(S.Version) > NWBFileConfiguration.SCHEMA_VERSION
                error("nansen:nwb:unsupportedConfigVersion", ...
                    ['This configuration uses schema version %d, but this ', ...
                     'release reads version %d. Update the NWB module, or ', ...
                     'rebuild the configuration with the configurator.'], ...
                    S.Version, NWBFileConfiguration.SCHEMA_VERSION)
            end

            obj = NWBFileConfiguration( ...
                "Version", uint32(S.Version), ...
                "OutputPath", string(S.OutputPath), ...
                "SessionMetadata", S.SessionMetadata, ...
                "SubjectMetadata", S.SubjectMetadata, ...
                "GeneralMetadata", S.GeneralMetadata, ...
                "DataItems", NWBDataItemConfig.fromAny(S.DataItems), ...
                "WriteMode", string(S.WriteMode));
        end

        function obj = fromAny(value)
            %fromAny - Accept either a configuration or a struct
            %   OBJ = fromAny(VALUE) returns VALUE unchanged when it is
            %   already a configuration, and converts a scalar struct.
            %
            %   Errors:
            %     nansen:nwb:invalidConfiguration - VALUE is neither a
            %                     configuration nor a scalar struct.

            if isa(value, "nansen.module.nwb.config.NWBFileConfiguration")
                obj = value;
            elseif isstruct(value)
                obj = nansen.module.nwb.config.NWBFileConfiguration.fromStruct(value);
            else
                error("nansen:nwb:invalidConfiguration", ...
                    ['A configuration must be an NWBFileConfiguration or a ', ...
                     'scalar struct, but was %s. Build one with ', ...
                     'NWBFileConfiguration or load it with loadConfiguration.'], ...
                    class(value))
            end
        end
    end

    methods (Static, Access = private)
        function S = fillMissingFields(S)
            %fillMissingFields - Replace absent or empty fields with defaults

            defaults = nansen.module.nwb.config.NWBFileConfiguration().toStruct();
            fieldNames = fieldnames(defaults);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if ~isfield(S, fieldName) || isempty(S.(fieldName))
                    S.(fieldName) = defaults.(fieldName);
                end
            end
        end
    end
end
