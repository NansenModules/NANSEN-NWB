classdef NwbFileConfiguration
%NwbFileConfiguration Configuration for writing one NWB file.

    properties
        Version (1,1) uint32 = 2
        OutputPath (1,1) string = ""
        SessionMetadata (1,1) struct = struct()
        SubjectMetadata (1,1) struct = struct()
        GeneralMetadata (1,1) struct = struct()
        DataItems (:,1) nansen.module.nwb.config.NwbDataItemConfig = ...
            nansen.module.nwb.config.NwbDataItemConfig.empty(0, 1)
        WriteMode (1,1) string {mustBeMember(WriteMode, ["overwrite", "append"])} = "overwrite"
    end

    methods
        function obj = NwbFileConfiguration(options)
            arguments
                options.Version (1,1) uint32 = uint32(2)
                options.OutputPath (1,1) string = ""
                options.SessionMetadata (1,1) struct = struct()
                options.SubjectMetadata (1,1) struct = struct()
                options.GeneralMetadata (1,1) struct = struct()
                options.DataItems = nansen.module.nwb.config.NwbDataItemConfig.empty(0, 1)
                options.WriteMode (1,1) string {mustBeMember(options.WriteMode, ["overwrite", "append"])} = "overwrite"
            end

            obj.Version = options.Version;
            obj.OutputPath = options.OutputPath;
            obj.SessionMetadata = options.SessionMetadata;
            obj.SubjectMetadata = options.SubjectMetadata;
            obj.GeneralMetadata = options.GeneralMetadata;
            obj.DataItems = nansen.module.nwb.config.NwbDataItemConfig.fromAny(options.DataItems);
            obj.WriteMode = options.WriteMode;
        end

        function S = toStruct(obj)
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
            arguments
                S (1,1) struct
            end

            S = nansen.module.nwb.config.NwbFileConfiguration.fillMissingFields(S);
            obj = nansen.module.nwb.config.NwbFileConfiguration( ...
                "Version", uint32(S.Version), ...
                "OutputPath", string(S.OutputPath), ...
                "SessionMetadata", S.SessionMetadata, ...
                "SubjectMetadata", S.SubjectMetadata, ...
                "GeneralMetadata", S.GeneralMetadata, ...
                "DataItems", nansen.module.nwb.config.NwbDataItemConfig.fromAny(S.DataItems), ...
                "WriteMode", string(S.WriteMode));
        end

        function obj = fromAny(value)
            if isa(value, "nansen.module.nwb.config.NwbFileConfiguration")
                obj = value;
            elseif isstruct(value)
                obj = nansen.module.nwb.config.NwbFileConfiguration.fromStruct(value);
            else
                error("NansenNwb:InvalidConfiguration", ...
                    "Expected NwbFileConfiguration or scalar struct.")
            end
        end
    end

    methods (Static, Access = private)
        function S = fillMissingFields(S)
            defaults = nansen.module.nwb.config.NwbFileConfiguration().toStruct();
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
