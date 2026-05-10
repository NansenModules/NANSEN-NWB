classdef NwbDataItemConfig
%NwbDataItemConfig Configuration for one data item in an NWB file.

    properties
        VariableName (1,1) string = ""
        NWBVariableName (1,1) string = ""
        ConverterName (1,1) string = ""
        TargetNwbType (1,1) string = ""
        PrimaryGroup (1,1) string = "Acquisition"
        NwbModule (1,1) string = ""
        Metadata (1,1) struct = struct()
        ConverterArgs (1,1) struct = struct()
        SourceInfo (1,1) struct = struct()
    end

    methods
        function obj = NwbDataItemConfig(options)
            arguments
                options.VariableName (1,1) string = ""
                options.NWBVariableName (1,1) string = ""
                options.ConverterName (1,1) string = ""
                options.TargetNwbType (1,1) string = ""
                options.PrimaryGroup (1,1) string = "Acquisition"
                options.NwbModule (1,1) string = ""
                options.Metadata (1,1) struct = struct()
                options.ConverterArgs (1,1) struct = struct()
                options.SourceInfo (1,1) struct = struct()
            end

            obj.VariableName = options.VariableName;
            obj.NWBVariableName = options.NWBVariableName;
            obj.ConverterName = options.ConverterName;
            obj.TargetNwbType = options.TargetNwbType;
            obj.PrimaryGroup = options.PrimaryGroup;
            obj.NwbModule = options.NwbModule;
            obj.Metadata = options.Metadata;
            obj.ConverterArgs = options.ConverterArgs;
            obj.SourceInfo = options.SourceInfo;
        end

        function S = toStruct(obj)
            S = struct();
            S.VariableName = obj.VariableName;
            S.NWBVariableName = obj.NWBVariableName;
            S.ConverterName = obj.ConverterName;
            S.TargetNwbType = obj.TargetNwbType;
            S.PrimaryGroup = obj.PrimaryGroup;
            S.NwbModule = obj.NwbModule;
            S.Metadata = obj.Metadata;
            S.ConverterArgs = obj.ConverterArgs;
            S.SourceInfo = obj.SourceInfo;
        end
    end

    methods (Static)
        function obj = fromStruct(S)
            arguments
                S struct
            end

            obj = nansen.module.nwb.config.NwbDataItemConfig.empty(0, 1);
            if isempty(S)
                return
            end

            for i = 1:numel(S)
                thisStruct = nansen.module.nwb.config.NwbDataItemConfig.fillMissingFields(S(i));
                thisStruct = nansen.module.nwb.config.NwbDataItemConfig.unwrapScalarCells(thisStruct);
                obj(i, 1) = nansen.module.nwb.config.NwbDataItemConfig( ...
                    "VariableName", string(thisStruct.VariableName), ...
                    "NWBVariableName", string(thisStruct.NWBVariableName), ...
                    "ConverterName", string(thisStruct.ConverterName), ...
                    "TargetNwbType", string(thisStruct.TargetNwbType), ...
                    "PrimaryGroup", string(thisStruct.PrimaryGroup), ...
                    "NwbModule", string(thisStruct.NwbModule), ...
                    "Metadata", thisStruct.Metadata, ...
                    "ConverterArgs", thisStruct.ConverterArgs, ...
                    "SourceInfo", thisStruct.SourceInfo);
            end
        end

        function obj = fromAny(value)
            if isa(value, "nansen.module.nwb.config.NwbDataItemConfig")
                obj = value(:);
            elseif isstruct(value)
                obj = nansen.module.nwb.config.NwbDataItemConfig.fromStruct(value);
            elseif isempty(value)
                obj = nansen.module.nwb.config.NwbDataItemConfig.empty(0, 1);
            else
                error("NansenNwb:InvalidDataItemConfiguration", ...
                    "Expected NwbDataItemConfig array or struct array.")
            end
        end
    end

    methods (Static, Access = private)
        function S = fillMissingFields(S)
            defaults = nansen.module.nwb.config.NwbDataItemConfig().toStruct();
            fieldNames = fieldnames(defaults);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if ~isfield(S, fieldName) || isempty(S.(fieldName))
                    S.(fieldName) = defaults.(fieldName);
                end
            end
        end

        function S = unwrapScalarCells(S)
            fieldNames = fieldnames(S);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if iscell(S.(fieldName)) && isscalar(S.(fieldName))
                    S.(fieldName) = S.(fieldName){1};
                end
            end
        end
    end
end
