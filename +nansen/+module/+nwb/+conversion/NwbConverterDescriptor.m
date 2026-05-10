classdef NwbConverterDescriptor
%NwbConverterDescriptor Metadata for one NWB converter.

    properties
        Name (1,1) string
        DisplayName (1,1) string = ""
        Source (1,1) string {mustBeMember(Source, ["builtin", "custom", "neuroconv"])} = "builtin"
        Description (1,1) string = ""
        AcceptedTypes (1,:) string = strings(1, 0)
        ProducesNwbType (1,1) string = ""
        PrimaryGroup (1,1) string = "Acquisition"
        NwbModuleTags (1,:) string = strings(1, 0)
        ExecutionMode (1,1) string {mustBeMember(ExecutionMode, ["mutate", "external"])} = "mutate"
        PlacementPolicy (1,1) string {mustBeMember(PlacementPolicy, ["config", "converter"])} = "config"
        AllowsPlacementOverride (1,1) logical = false
        RequiresPython (1,1) logical = false
        MetadataSchema = struct()
        DefaultConverterArgs (1,1) struct = struct()
        Function
        NeedsData (1,1) logical = true
    end

    methods
        function obj = NwbConverterDescriptor(options)
            arguments
                options.Name (1,1) string
                options.DisplayName (1,1) string = ""
                options.Source (1,1) string {mustBeMember(options.Source, ["builtin", "custom", "neuroconv"])} = "builtin"
                options.Description (1,1) string = ""
                options.AcceptedTypes (1,:) string = strings(1, 0)
                options.ProducesNwbType (1,1) string = ""
                options.PrimaryGroup (1,1) string = "Acquisition"
                options.NwbModuleTags (1,:) string = strings(1, 0)
                options.ExecutionMode (1,1) string {mustBeMember(options.ExecutionMode, ["mutate", "external"])} = "mutate"
                options.PlacementPolicy (1,1) string {mustBeMember(options.PlacementPolicy, ["config", "converter"])} = "config"
                options.AllowsPlacementOverride (1,1) logical = false
                options.RequiresPython (1,1) logical = false
                options.MetadataSchema = struct()
                options.DefaultConverterArgs (1,1) struct = struct()
                options.Function (1,1) function_handle
                options.NeedsData (1,1) logical = true
            end

            obj.Name = options.Name;
            obj.DisplayName = options.DisplayName;
            if strlength(obj.DisplayName) == 0
                obj.DisplayName = obj.Name;
            end
            obj.Source = options.Source;
            obj.Description = options.Description;
            obj.AcceptedTypes = options.AcceptedTypes;
            obj.ProducesNwbType = options.ProducesNwbType;
            obj.PrimaryGroup = options.PrimaryGroup;
            obj.NwbModuleTags = options.NwbModuleTags;
            obj.ExecutionMode = options.ExecutionMode;
            obj.PlacementPolicy = options.PlacementPolicy;
            obj.AllowsPlacementOverride = options.AllowsPlacementOverride;
            obj.RequiresPython = options.RequiresPython;
            obj.MetadataSchema = options.MetadataSchema;
            obj.DefaultConverterArgs = options.DefaultConverterArgs;
            obj.Function = options.Function;
            obj.NeedsData = options.NeedsData;

            obj.validate()
        end

        function validate(obj)
            if strlength(obj.Name) == 0
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Converter descriptor Name must be non-empty.")
            end

            obj.assertNonEmptyTextVector(obj.AcceptedTypes, "AcceptedTypes")
            obj.assertNonEmptyTextVector(obj.ProducesNwbType, "ProducesNwbType")
            obj.assertNonEmptyTextVector(obj.PrimaryGroup, "PrimaryGroup")
            obj.assertValidPrimaryGroup()

            if ~isempty(obj.NwbModuleTags)
                obj.assertNonEmptyTextVector(obj.NwbModuleTags, "NwbModuleTags")
            end

            if ~(isstruct(obj.MetadataSchema) || isa(obj.MetadataSchema, "function_handle"))
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Converter descriptor %s MetadataSchema must be a struct or function handle.", obj.Name)
            end

            if obj.ExecutionMode == "external" && obj.PlacementPolicy ~= "converter"
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "External converter %s must use PlacementPolicy='converter'.", obj.Name)
            end

            obj.assertValidFunctionSignature()
            obj.assertValidNeuroconvDefaults()
        end

        function S = toStruct(obj)
            S = struct();
            S.Name = obj.Name;
            S.DisplayName = obj.DisplayName;
            S.Source = obj.Source;
            S.Description = obj.Description;
            S.AcceptedTypes = obj.AcceptedTypes;
            S.ProducesNwbType = obj.ProducesNwbType;
            S.PrimaryGroup = obj.PrimaryGroup;
            S.NwbModuleTags = obj.NwbModuleTags;
            S.ExecutionMode = obj.ExecutionMode;
            S.PlacementPolicy = obj.PlacementPolicy;
            S.AllowsPlacementOverride = obj.AllowsPlacementOverride;
            S.RequiresPython = obj.RequiresPython;
            S.MetadataSchema = obj.MetadataSchema;
            S.DefaultConverterArgs = obj.DefaultConverterArgs;
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
                "DisplayName", string(S.DisplayName), ...
                "Source", string(S.Source), ...
                "Description", string(S.Description), ...
                "AcceptedTypes", string(S.AcceptedTypes), ...
                "ProducesNwbType", string(S.ProducesNwbType), ...
                "PrimaryGroup", string(S.PrimaryGroup), ...
                "NwbModuleTags", string(S.NwbModuleTags), ...
                "ExecutionMode", string(S.ExecutionMode), ...
                "PlacementPolicy", string(S.PlacementPolicy), ...
                "AllowsPlacementOverride", logical(S.AllowsPlacementOverride), ...
                "RequiresPython", logical(S.RequiresPython), ...
                "MetadataSchema", S.MetadataSchema, ...
                "DefaultConverterArgs", S.DefaultConverterArgs, ...
                "Function", functionHandle, ...
                "NeedsData", logical(S.NeedsData));
        end
    end

    methods (Static, Access = private)
        function S = fillMissingFields(S)
            defaults = struct( ...
                "DisplayName", "", ...
                "Source", "builtin", ...
                "Description", "", ...
                "AcceptedTypes", "*", ...
                "ProducesNwbType", "", ...
                "PrimaryGroup", "Acquisition", ...
                "NwbModuleTags", strings(1, 0), ...
                "ExecutionMode", "mutate", ...
                "PlacementPolicy", "config", ...
                "AllowsPlacementOverride", false, ...
                "RequiresPython", false, ...
                "MetadataSchema", struct(), ...
                "DefaultConverterArgs", struct(), ...
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

    methods (Access = private)
        function assertValidPrimaryGroup(obj)
            validGroups = ["Acquisition", "Processing", "Analysis", "Intervals", "Stimulus"];
            if ~any(string(obj.PrimaryGroup) == validGroups)
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Converter descriptor %s PrimaryGroup must be one of: %s.", ...
                    obj.Name, strjoin(validGroups, ", "))
            end
        end

        function assertValidFunctionSignature(obj)
            try
                numInputs = nargin(obj.Function);
            catch
                numInputs = -1;
            end

            if ~(numInputs == 1 || numInputs < 0)
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Converter descriptor %s Function must accept one context argument or varargin.", ...
                    obj.Name)
            end
        end

        function assertValidNeuroconvDefaults(obj)
            if obj.Source ~= "neuroconv"
                return
            end

            if ~obj.RequiresPython
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "NeuroConv converter %s must set RequiresPython=true.", obj.Name)
            end

            if obj.ExecutionMode ~= "external" || obj.PlacementPolicy ~= "converter" || obj.NeedsData
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "NeuroConv converter %s must be an external, converter-owned, path-based converter.", ...
                    obj.Name)
            end

            args = obj.DefaultConverterArgs;
            if isempty(fieldnames(args))
                return
            end

            requiredFields = ["InterfaceClassName", "SourceArgumentName", "SourcePathMode"];
            for i = 1:numel(requiredFields)
                fieldName = char(requiredFields(i));
                if ~isfield(args, fieldName) || strlength(strtrim(string(args.(fieldName)))) == 0
                    error("NansenNwb:InvalidConverterDescriptor", ...
                        "NeuroConv converter %s DefaultConverterArgs.%s must be non-empty.", ...
                        obj.Name, fieldName)
                end
            end

            validPathModes = ["file", "path", "folder", "parentFolder", "fileList"];
            if ~any(string(args.SourcePathMode) == validPathModes)
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "NeuroConv converter %s SourcePathMode must be one of: %s.", ...
                    obj.Name, strjoin(validPathModes, ", "))
            end
        end
    end

    methods (Static, Access = private)
        function assertNonEmptyTextVector(value, propertyName)
            value = strtrim(string(value));
            if isempty(value) || any(value == "" | ismissing(value))
                error("NansenNwb:InvalidConverterDescriptor", ...
                    "Converter descriptor %s must contain non-empty text.", propertyName)
            end
        end
    end
end
