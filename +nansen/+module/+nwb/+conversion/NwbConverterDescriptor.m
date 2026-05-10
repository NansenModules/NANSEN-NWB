classdef NwbConverterDescriptor
%NwbConverterDescriptor Metadata for one NWB converter.

    properties
        Name (1,1) string
        Source (1,1) string {mustBeMember(Source, ["builtin", "custom", "neuroconv"])} = "builtin"
        Description (1,1) string = ""
        AcceptedTypes (1,:) string = strings(1, 0)
        ProducesNwbType (1,1) string = ""
        PrimaryGroup (1,1) string = "Acquisition"
        ExecutionMode (1,1) string {mustBeMember(ExecutionMode, ["mutate", "external"])} = "mutate"
        PlacementPolicy (1,1) string {mustBeMember(PlacementPolicy, ["config", "converter"])} = "config"
        AllowsPlacementOverride (1,1) logical = false
        RequiresPython (1,1) logical = false
        MetadataSchema = struct()
        Function
        NeedsData (1,1) logical = true
    end

    methods
        function obj = NwbConverterDescriptor(options)
            arguments
                options.Name (1,1) string
                options.Source (1,1) string {mustBeMember(options.Source, ["builtin", "custom", "neuroconv"])} = "builtin"
                options.Description (1,1) string = ""
                options.AcceptedTypes (1,:) string = strings(1, 0)
                options.ProducesNwbType (1,1) string = ""
                options.PrimaryGroup (1,1) string = "Acquisition"
                options.ExecutionMode (1,1) string {mustBeMember(options.ExecutionMode, ["mutate", "external"])} = "mutate"
                options.PlacementPolicy (1,1) string {mustBeMember(options.PlacementPolicy, ["config", "converter"])} = "config"
                options.AllowsPlacementOverride (1,1) logical = false
                options.RequiresPython (1,1) logical = false
                options.MetadataSchema = struct()
                options.Function (1,1) function_handle
                options.NeedsData (1,1) logical = true
            end

            obj.Name = options.Name;
            obj.Source = options.Source;
            obj.Description = options.Description;
            obj.AcceptedTypes = options.AcceptedTypes;
            obj.ProducesNwbType = options.ProducesNwbType;
            obj.PrimaryGroup = options.PrimaryGroup;
            obj.ExecutionMode = options.ExecutionMode;
            obj.PlacementPolicy = options.PlacementPolicy;
            obj.AllowsPlacementOverride = options.AllowsPlacementOverride;
            obj.RequiresPython = options.RequiresPython;
            obj.MetadataSchema = options.MetadataSchema;
            obj.Function = options.Function;
            obj.NeedsData = options.NeedsData;

            obj.validate()
        end

        function validate(obj)
            if strlength(obj.Name) == 0
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Converter descriptor Name must be non-empty.")
            end

            if isempty(obj.AcceptedTypes)
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Converter descriptor %s must declare at least one AcceptedTypes value.", obj.Name)
            end

            if obj.ExecutionMode == "external" && obj.PlacementPolicy ~= "converter"
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "External converter %s must use PlacementPolicy='converter'.", obj.Name)
            end
        end

        function S = toStruct(obj)
            S = struct();
            S.Name = obj.Name;
            S.Source = obj.Source;
            S.Description = obj.Description;
            S.AcceptedTypes = obj.AcceptedTypes;
            S.ProducesNwbType = obj.ProducesNwbType;
            S.PrimaryGroup = obj.PrimaryGroup;
            S.ExecutionMode = obj.ExecutionMode;
            S.PlacementPolicy = obj.PlacementPolicy;
            S.AllowsPlacementOverride = obj.AllowsPlacementOverride;
            S.RequiresPython = obj.RequiresPython;
            S.MetadataSchema = obj.MetadataSchema;
            S.Function = func2str(obj.Function);
            S.NeedsData = obj.NeedsData;
        end
    end

    methods (Static)
        function obj = fromAny(value)
            if isa(value, "nansen.module.nwb.conversion.NwbConverterDescriptor")
                obj = value;
            elseif isstruct(value)
                obj = nansen.module.nwb.conversion.NwbConverterDescriptor.fromStruct(value);
            else
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Expected NwbConverterDescriptor or scalar struct.")
            end
        end

        function obj = fromStruct(S)
            S = nansen.module.nwb.conversion.NwbConverterDescriptor.fillMissingFields(S);
            if isa(S.Function, "function_handle")
                functionHandle = S.Function;
            else
                functionHandle = str2func(char(S.Function));
            end

            obj = nansen.module.nwb.conversion.NwbConverterDescriptor( ...
                "Name", string(S.Name), ...
                "Source", string(S.Source), ...
                "Description", string(S.Description), ...
                "AcceptedTypes", string(S.AcceptedTypes), ...
                "ProducesNwbType", string(S.ProducesNwbType), ...
                "PrimaryGroup", string(S.PrimaryGroup), ...
                "ExecutionMode", string(S.ExecutionMode), ...
                "PlacementPolicy", string(S.PlacementPolicy), ...
                "AllowsPlacementOverride", logical(S.AllowsPlacementOverride), ...
                "RequiresPython", logical(S.RequiresPython), ...
                "MetadataSchema", S.MetadataSchema, ...
                "Function", functionHandle, ...
                "NeedsData", logical(S.NeedsData));
        end
    end

    methods (Static, Access = private)
        function S = fillMissingFields(S)
            defaults = struct( ...
                "Source", "builtin", ...
                "Description", "", ...
                "AcceptedTypes", "*", ...
                "ProducesNwbType", "", ...
                "PrimaryGroup", "Acquisition", ...
                "ExecutionMode", "mutate", ...
                "PlacementPolicy", "config", ...
                "AllowsPlacementOverride", false, ...
                "RequiresPython", false, ...
                "MetadataSchema", struct(), ...
                "NeedsData", true);

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
