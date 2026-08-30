classdef NWBConverterDescriptor
%NWBConverterDescriptor - What a converter accepts, produces and requires
%   OBJ = NWBConverterDescriptor(Name=NAME,Function=FCN) describes one
%   converter for the registry. NAME is the key callers look it up by and
%   FCN is a handle taking a single conversion context.
%
%   OBJ = NWBConverterDescriptor(...,Name=VALUE) also sets any of the
%   properties below. The constructor validates the descriptor, so an
%   inconsistent one fails where it is declared rather than mid-conversion.
%
%   A converter is matched to a data item on two independent kinds of
%   evidence. AcceptedClasses holds MATLAB classes the converter takes;
%   AcceptedFormats holds source formats it reads. Keeping them apart
%   matters because most path-based converters accept any file, so a
%   converter that declared a path type as its accepted type would match
%   every file-backed variable in the session.
%
%   NWBConverterDescriptor functions:
%       validate - Check the descriptor for internal consistency
%       toStruct - Convert to a struct for serialization
%       fromAny  - Accept either a descriptor or a struct
%
%   NWBConverterDescriptor properties:
%       Name                    - Registry key for this converter
%       DisplayName             - Label shown in the configurator
%       Source                  - Where the converter comes from
%       Description             - One-line summary shown to the user
%       AcceptedClasses         - MATLAB classes the converter accepts
%       AcceptedFormats         - Source formats the converter reads
%       ProducesNWBType         - Neurodata type the converter creates
%       RequiresNWBTypes        - Types that must exist before it runs
%       PrimaryGroup            - Default NWB group for the result
%       NWBModuleTags           - Processing modules this converter suits
%       ExecutionMode           - Whether it mutates memory or writes itself
%       PlacementPolicy         - Whether config or converter places output
%       AllowsPlacementOverride - Whether a result may override placement
%       RequiresPython          - Whether the converter needs Python
%       NeedsData               - Whether the runner resolves the data
%       MetadataSchema          - Fields and defaults for the metadata form
%       DefaultConverterArgs    - Arguments merged under per-item arguments
%       Function                - Handle taking one conversion context
%
%   See also nansen.module.nwb.conversion.ConverterRegistry,
%   nansen.module.nwb.conversion.NWBFileConverter

    properties (Constant)
        %VALID_PRIMARY_GROUPS - NWB groups a converter may target
        VALID_PRIMARY_GROUPS = ["Acquisition", "Processing", "Analysis", ...
            "Intervals", "Stimulus"]
    end

    properties
        Name (1,1) string                   % Registry key for this converter
        DisplayName (1,1) string = ""       % Label shown in the configurator
        Source (1,1) string {mustBeMember(Source, ["builtin", "custom", "neuroconv"])} = "builtin" % Where the converter comes from
        Description (1,1) string = ""       % One-line summary shown to the user
        AcceptedClasses (1,:) string = strings(1, 0) % MATLAB classes the converter accepts
        AcceptedFormats (1,:) string = strings(1, 0) % Source formats the converter reads
        ProducesNWBType (1,1) string = ""   % Neurodata type the converter creates
        RequiresNWBTypes (1,:) string = strings(1, 0) % Types that must exist before it runs
        PrimaryGroup (1,1) string = "Acquisition" % Default NWB group for the result
        NWBModuleTags (1,:) string = strings(1, 0) % Processing modules this converter suits
        ExecutionMode (1,1) string {mustBeMember(ExecutionMode, ["mutate", "external"])} = "mutate" % Whether it mutates memory or writes itself
        PlacementPolicy (1,1) string {mustBeMember(PlacementPolicy, ["config", "converter"])} = "config" % Whether config or converter places output
        AllowsPlacementOverride (1,1) logical = false % Whether a result may override placement
        RequiresPython (1,1) logical = false % Whether the converter needs Python
        NeedsData (1,1) logical = true      % Whether the runner resolves the data
        MetadataSchema = struct()           % Fields and defaults for the metadata form
        DefaultConverterArgs (1,1) struct = struct() % Arguments merged under per-item arguments
        Function                            % Handle taking one conversion context
    end

    methods
        function obj = NWBConverterDescriptor(options)
            arguments
                options.Name (1,1) string
                options.DisplayName (1,1) string = ""
                options.Source (1,1) string ...
                    {mustBeMember(options.Source, ["builtin", "custom", "neuroconv"])} = "builtin"
                options.Description (1,1) string = ""
                options.AcceptedClasses (1,:) string = strings(1, 0)
                options.AcceptedFormats (1,:) string = strings(1, 0)
                options.ProducesNWBType (1,1) string = ""
                options.RequiresNWBTypes (1,:) string = strings(1, 0)
                options.PrimaryGroup (1,1) string = "Acquisition"
                options.NWBModuleTags (1,:) string = strings(1, 0)
                options.ExecutionMode (1,1) string ...
                    {mustBeMember(options.ExecutionMode, ["mutate", "external"])} = "mutate"
                options.PlacementPolicy (1,1) string ...
                    {mustBeMember(options.PlacementPolicy, ["config", "converter"])} = "config"
                options.AllowsPlacementOverride (1,1) logical = false
                options.RequiresPython (1,1) logical = false
                options.NeedsData (1,1) logical = true
                options.MetadataSchema = struct()
                options.DefaultConverterArgs (1,1) struct = struct()
                options.Function (1,1) function_handle
            end

            obj.Name = options.Name;
            obj.DisplayName = options.DisplayName;
            if strlength(obj.DisplayName) == 0
                obj.DisplayName = obj.Name;
            end
            obj.Source = options.Source;
            obj.Description = options.Description;
            obj.AcceptedClasses = options.AcceptedClasses;
            obj.AcceptedFormats = options.AcceptedFormats;
            obj.ProducesNWBType = options.ProducesNWBType;
            obj.RequiresNWBTypes = options.RequiresNWBTypes;
            obj.PrimaryGroup = options.PrimaryGroup;
            obj.NWBModuleTags = options.NWBModuleTags;
            obj.ExecutionMode = options.ExecutionMode;
            obj.PlacementPolicy = options.PlacementPolicy;
            obj.AllowsPlacementOverride = options.AllowsPlacementOverride;
            obj.RequiresPython = options.RequiresPython;
            obj.NeedsData = options.NeedsData;
            obj.MetadataSchema = options.MetadataSchema;
            obj.DefaultConverterArgs = options.DefaultConverterArgs;
            obj.Function = options.Function;

            obj.validate()
        end

        function validate(obj)
            %validate - Check the descriptor for internal consistency
            %   validate(OBJ) errors when OBJ declares a combination the
            %   runner cannot honor, such as an external converter whose
            %   placement is config-owned.
            %
            %   Errors:
            %     nansen:nwb:invalidConverterDescriptor - OBJ is
            %                     inconsistent. The message names the field.

            if strlength(strtrim(obj.Name)) == 0
                obj.fail("Name must be non-empty.")
            end

            if isempty(obj.AcceptedClasses) && isempty(obj.AcceptedFormats)
                obj.fail(['must accept at least one class or format. Use ', ...
                    'AcceptedClasses="*" for a converter that accepts any data.'])
            end

            obj.assertNonEmptyText(obj.AcceptedClasses, "AcceptedClasses")
            obj.assertNonEmptyText(obj.AcceptedFormats, "AcceptedFormats")
            obj.assertNonEmptyText(obj.ProducesNWBType, "ProducesNWBType")
            obj.assertNonEmptyText(obj.NWBModuleTags, "NWBModuleTags")
            obj.assertNonEmptyText(obj.RequiresNWBTypes, "RequiresNWBTypes")

            if ~any(obj.PrimaryGroup == obj.VALID_PRIMARY_GROUPS)
                obj.fail("PrimaryGroup must be one of: %s.", ...
                    strjoin(obj.VALID_PRIMARY_GROUPS, ", "))
            end

            if ~(isstruct(obj.MetadataSchema) || isa(obj.MetadataSchema, "function_handle"))
                obj.fail("MetadataSchema must be a struct or a function handle.")
            end

            % An external converter writes the file itself, so the runner
            % cannot place its output afterwards.
            if obj.ExecutionMode == "external" && obj.PlacementPolicy ~= "converter"
                obj.fail(['writes the file itself, so it must declare ', ...
                    'PlacementPolicy="converter".'])
            end

            obj.assertValidFunctionSignature()
            obj.assertValidNeuroconvContract()
        end

        function S = toStruct(obj)
            %toStruct - Convert to a struct for serialization
            %   S = toStruct(OBJ) returns a scalar struct holding the
            %   properties of OBJ, with Function as its text form.

            S = struct();
            S.Name = obj.Name;
            S.DisplayName = obj.DisplayName;
            S.Source = obj.Source;
            S.Description = obj.Description;
            S.AcceptedClasses = obj.AcceptedClasses;
            S.AcceptedFormats = obj.AcceptedFormats;
            S.ProducesNWBType = obj.ProducesNWBType;
            S.RequiresNWBTypes = obj.RequiresNWBTypes;
            S.PrimaryGroup = obj.PrimaryGroup;
            S.NWBModuleTags = obj.NWBModuleTags;
            S.ExecutionMode = obj.ExecutionMode;
            S.PlacementPolicy = obj.PlacementPolicy;
            S.AllowsPlacementOverride = obj.AllowsPlacementOverride;
            S.RequiresPython = obj.RequiresPython;
            S.NeedsData = obj.NeedsData;
            S.MetadataSchema = obj.MetadataSchema;
            S.DefaultConverterArgs = obj.DefaultConverterArgs;
            S.Function = func2str(obj.Function);
        end
    end

    methods (Static)
        function obj = fromAny(value)
            %fromAny - Accept either a descriptor or a struct
            %   OBJ = fromAny(VALUE) returns VALUE unchanged when it is
            %   already a descriptor, and converts a scalar struct.
            %
            %   Errors:
            %     nansen:nwb:invalidConverterDescriptor - VALUE is neither.

            import nansen.module.nwb.conversion.NWBConverterDescriptor

            if isa(value, "nansen.module.nwb.conversion.NWBConverterDescriptor")
                obj = value;
            elseif isstruct(value)
                obj = NWBConverterDescriptor.fromStruct(value);
            else
                error("nansen:nwb:invalidConverterDescriptor", ...
                    ['A converter descriptor must be an ', ...
                     'NWBConverterDescriptor or a scalar struct, but was ', ...
                     '%s.'], class(value))
            end
        end
    end

    methods (Static, Access = private)
        function obj = fromStruct(S)
            %fromStruct - Build a descriptor from a struct

            import nansen.module.nwb.conversion.NWBConverterDescriptor

            S = NWBConverterDescriptor.fillMissingFields(S);
            if isa(S.Function, "function_handle")
                functionHandle = S.Function;
            else
                functionHandle = str2func(char(S.Function));
            end

            obj = NWBConverterDescriptor( ...
                "Name", string(S.Name), ...
                "DisplayName", string(S.DisplayName), ...
                "Source", string(S.Source), ...
                "Description", string(S.Description), ...
                "AcceptedClasses", string(S.AcceptedClasses), ...
                "AcceptedFormats", string(S.AcceptedFormats), ...
                "ProducesNWBType", string(S.ProducesNWBType), ...
                "RequiresNWBTypes", string(S.RequiresNWBTypes), ...
                "PrimaryGroup", string(S.PrimaryGroup), ...
                "NWBModuleTags", string(S.NWBModuleTags), ...
                "ExecutionMode", string(S.ExecutionMode), ...
                "PlacementPolicy", string(S.PlacementPolicy), ...
                "AllowsPlacementOverride", logical(S.AllowsPlacementOverride), ...
                "RequiresPython", logical(S.RequiresPython), ...
                "NeedsData", logical(S.NeedsData), ...
                "MetadataSchema", S.MetadataSchema, ...
                "DefaultConverterArgs", S.DefaultConverterArgs, ...
                "Function", functionHandle);
        end

        function S = fillMissingFields(S)
            %fillMissingFields - Replace absent or empty fields with defaults

            defaults = struct( ...
                "DisplayName", "", ...
                "Source", "builtin", ...
                "Description", "", ...
                "AcceptedClasses", "*", ...
                "AcceptedFormats", strings(1, 0), ...
                "ProducesNWBType", "", ...
                "RequiresNWBTypes", strings(1, 0), ...
                "PrimaryGroup", "Acquisition", ...
                "NWBModuleTags", strings(1, 0), ...
                "ExecutionMode", "mutate", ...
                "PlacementPolicy", "config", ...
                "AllowsPlacementOverride", false, ...
                "RequiresPython", false, ...
                "NeedsData", true, ...
                "MetadataSchema", struct(), ...
                "DefaultConverterArgs", struct());

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
        function fail(obj, messageFormat, varargin)
            %fail - Raise a descriptor error naming the converter

            error("nansen:nwb:invalidConverterDescriptor", ...
                "Converter descriptor ''%s'' %s", obj.Name, ...
                sprintf(messageFormat, varargin{:}))
        end

        function assertNonEmptyText(obj, value, propertyName)
            %assertNonEmptyText - Reject blank entries in a text property

            if isempty(value)
                return
            end
            value = strtrim(string(value));
            if any(ismissing(value) | value == "")
                obj.fail("%s must not contain blank entries.", propertyName)
            end
        end

        function assertValidFunctionSignature(obj)
            %assertValidFunctionSignature - Require a one-context signature

            try
                numInputs = nargin(obj.Function);
            catch
                % nargin throws for a handle to a function that is not on
                % the path. The registry reports that when the converter
                % runs; here it only means the arity is unknown.
                numInputs = -1;
            end

            % A negative count means varargin, which accepts one argument.
            if numInputs ~= 1 && numInputs >= 0
                obj.fail(['Function must accept one conversion context ', ...
                    'argument, but takes %d.'], numInputs)
            end
        end

        function assertValidNeuroconvContract(obj)
            %assertValidNeuroconvContract - Check NeuroConv-specific fields

            if obj.Source ~= "neuroconv"
                return
            end

            if ~obj.RequiresPython
                obj.fail("is NeuroConv-backed, so it must set RequiresPython=true.")
            end

            % NeuroConv reads the source file itself and owns placement
            % inside the file it writes.
            if obj.ExecutionMode ~= "external" || obj.PlacementPolicy ~= "converter" ...
                    || obj.NeedsData
                obj.fail(['is NeuroConv-backed, so it must be external, ', ...
                    'converter-placed, and take a path rather than loaded data.'])
            end

            args = obj.DefaultConverterArgs;
            if isempty(fieldnames(args))
                return
            end

            requiredFields = ["InterfaceClassName", "SourceArgumentName", "SourcePathMode"];
            for i = 1:numel(requiredFields)
                fieldName = requiredFields(i);
                if ~isfield(args, fieldName) || strlength(strtrim(string(args.(fieldName)))) == 0
                    obj.fail("DefaultConverterArgs.%s must be non-empty.", fieldName)
                end
            end

            validPathModes = ["file", "path", "folder", "parentFolder", "fileList"];
            if ~any(string(args.SourcePathMode) == validPathModes)
                obj.fail("SourcePathMode must be one of: %s.", strjoin(validPathModes, ", "))
            end
        end
    end
end
