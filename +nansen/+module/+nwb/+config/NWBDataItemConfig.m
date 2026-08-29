classdef NWBDataItemConfig
%NWBDataItemConfig - Configuration for one data item in an NWB file
%   OBJ = NWBDataItemConfig() creates a configuration item with default
%   values. A data item names one source variable, the converter that
%   turns it into neurodata, and where the result belongs in the file.
%
%   OBJ = NWBDataItemConfig(Name=VALUE) also sets properties by name.
%   Any subset of the properties below may be given.
%
%   NWBDataItemConfig functions:
%       toStruct   - Convert to a struct for serialization
%       fromStruct - Build items from a struct array
%       fromAny    - Accept either items or struct arrays
%
%   NWBDataItemConfig properties:
%       VariableName    - Name of the source data variable
%       NWBVariableName - Name the converted data gets in the NWB file
%       ConverterName   - Registry key of the converter to run
%       TargetNWBType   - Neurodata type for the generic conversion path
%       PrimaryGroup    - NWB group the result is placed in
%       NWBModule       - Processing module, when PrimaryGroup is Processing
%       Metadata        - Metadata written into the NWB file
%       ConverterArgs   - Options the converter needs, not written to file
%       SourceInfo      - Evidence about the source, used to match converters
%
%   See also nansen.module.nwb.config.NWBFileConfiguration,
%   nansen.module.nwb.conversion.ConverterRegistry

    properties
        VariableName (1,1) string = ""      % Name of the source data variable
        NWBVariableName (1,1) string = ""   % Name the converted data gets in the NWB file
        ConverterName (1,1) string = ""     % Registry key of the converter to run
        TargetNWBType (1,1) string = ""     % Neurodata type for the generic conversion path
        PrimaryGroup (1,1) string = "Acquisition" % NWB group the result is placed in
        NWBModule (1,1) string = ""         % Processing module, when PrimaryGroup is Processing
        Metadata (1,1) struct = struct()    % Metadata written into the NWB file
        ConverterArgs (1,1) struct = struct() % Options the converter needs, not written to file
        SourceInfo (1,1) struct = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo() % Evidence about the source, used to match converters
    end

    methods
        function obj = NWBDataItemConfig(options)
            arguments
                options.VariableName (1,1) string = ""
                options.NWBVariableName (1,1) string = ""
                options.ConverterName (1,1) string = ""
                options.TargetNWBType (1,1) string = ""
                options.PrimaryGroup (1,1) string = "Acquisition"
                options.NWBModule (1,1) string = ""
                options.Metadata (1,1) struct = struct()
                options.ConverterArgs (1,1) struct = struct()
                options.SourceInfo (1,1) struct = ...
                    nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo()
            end

            obj.VariableName = options.VariableName;
            obj.NWBVariableName = options.NWBVariableName;
            obj.ConverterName = options.ConverterName;
            obj.TargetNWBType = options.TargetNWBType;
            obj.PrimaryGroup = options.PrimaryGroup;
            obj.NWBModule = options.NWBModule;
            obj.Metadata = options.Metadata;
            obj.ConverterArgs = options.ConverterArgs;
            obj.SourceInfo = nansen.module.nwb.config.NWBDataItemConfig...
                .normalizeSourceInfo(options.SourceInfo);
        end

        function S = toStruct(obj)
            %toStruct - Convert to a struct for serialization
            %   S = toStruct(OBJ) returns a scalar struct holding the
            %   properties of OBJ, ready for JSONENCODE.

            S = struct();
            S.VariableName = obj.VariableName;
            S.NWBVariableName = obj.NWBVariableName;
            S.ConverterName = obj.ConverterName;
            S.TargetNWBType = obj.TargetNWBType;
            S.PrimaryGroup = obj.PrimaryGroup;
            S.NWBModule = obj.NWBModule;
            S.Metadata = obj.Metadata;
            S.ConverterArgs = obj.ConverterArgs;
            S.SourceInfo = obj.SourceInfo;
        end
    end

    methods (Static)
        function obj = fromStruct(S)
            %fromStruct - Build items from a struct array
            %   OBJ = fromStruct(S) returns one configuration item per
            %   element of the struct array S. Missing fields take their
            %   default values, so a struct written by an older version
            %   still loads.

            arguments
                S struct
            end

            import nansen.module.nwb.config.NWBDataItemConfig

            obj = NWBDataItemConfig.empty(0, 1);
            if isempty(S)
                return
            end

            for i = 1:numel(S)
                thisStruct = NWBDataItemConfig.fillMissingFields(S(i));
                thisStruct = NWBDataItemConfig.unwrapScalarCells(thisStruct);
                obj(i, 1) = NWBDataItemConfig( ...
                    "VariableName", string(thisStruct.VariableName), ...
                    "NWBVariableName", string(thisStruct.NWBVariableName), ...
                    "ConverterName", string(thisStruct.ConverterName), ...
                    "TargetNWBType", string(thisStruct.TargetNWBType), ...
                    "PrimaryGroup", string(thisStruct.PrimaryGroup), ...
                    "NWBModule", string(thisStruct.NWBModule), ...
                    "Metadata", thisStruct.Metadata, ...
                    "ConverterArgs", thisStruct.ConverterArgs, ...
                    "SourceInfo", thisStruct.SourceInfo);
            end
        end

        function obj = fromAny(value)
            %fromAny - Accept either items or struct arrays
            %   OBJ = fromAny(VALUE) returns VALUE unchanged when it is
            %   already an item array, converts a struct array, and
            %   returns an empty item array for empty input.
            %
            %   Errors:
            %     nansen:nwb:invalidDataItemConfig - VALUE is neither an
            %                     item array nor a struct array.

            import nansen.module.nwb.config.NWBDataItemConfig

            if isa(value, "nansen.module.nwb.config.NWBDataItemConfig")
                obj = value(:);
            elseif isstruct(value)
                obj = NWBDataItemConfig.fromStruct(value);
            elseif isempty(value)
                obj = NWBDataItemConfig.empty(0, 1);
            else
                error("nansen:nwb:invalidDataItemConfig", ...
                    ['Data items must be given as an NWBDataItemConfig ', ...
                     'array or a struct array, but were %s. Build them ', ...
                     'with NWBDataItemConfig or load them from a saved ', ...
                     'configuration.'], class(value))
            end
        end

        function S = emptySourceInfo()
            %emptySourceInfo - Source evidence struct with no evidence set

            S = struct( ...
                "MatlabClass", "", ...
                "Format", "", ...
                "Modality", "", ...
                "Path", string.empty(1, 0));
        end
    end

    methods (Static, Access = private)
        function S = normalizeSourceInfo(S)
            %normalizeSourceInfo - Fill missing evidence fields with defaults

            import nansen.module.nwb.config.NWBDataItemConfig

            defaults = NWBDataItemConfig.emptySourceInfo();
            fieldNames = fieldnames(defaults);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if ~isfield(S, fieldName)
                    S.(fieldName) = defaults.(fieldName);
                elseif fieldName == "Path"
                    S.(fieldName) = reshape(string(S.(fieldName)), 1, []);
                else
                    S.(fieldName) = string(S.(fieldName));
                end
            end
        end

        function S = fillMissingFields(S)
            %fillMissingFields - Replace absent or empty fields with defaults

            defaults = nansen.module.nwb.config.NWBDataItemConfig().toStruct();
            fieldNames = fieldnames(defaults);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if ~isfield(S, fieldName) || isempty(S.(fieldName))
                    S.(fieldName) = defaults.(fieldName);
                end
            end
        end

        function S = unwrapScalarCells(S)
            %unwrapScalarCells - Undo the cell wrapping JSONDECODE adds

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
