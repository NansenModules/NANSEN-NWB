classdef NwbFileConverter < handle
%NwbFileConverter File-centric runner for configured NWB conversions.

    properties (SetAccess = private)
        Config (1,1) nansen.module.nwb.config.NwbFileConfiguration
        Registry (1,1) nansen.module.nwb.conversion.ConverterRegistry
    end

    properties
        DataResolver = []
    end

    methods
        function obj = NwbFileConverter(config, options)
            arguments
                config
                options.DataResolver = []
                options.Registry = nansen.module.nwb.conversion.ConverterRegistry.instance()
            end

            obj.Config = nansen.module.nwb.config.NwbFileConfiguration.fromAny(config);
            obj.DataResolver = options.DataResolver;
            obj.Registry = options.Registry;
        end

        function filePath = convert(obj)
            obj.validateConfig()
            obj.prepareOutputFile()

            for i = 1:numel(obj.Config.DataItems)
                obj.convertDataItem(obj.Config.DataItems(i))
            end

            filePath = obj.Config.OutputPath;
        end
    end

    methods (Access = private)
        function validateConfig(obj)
            if strlength(obj.Config.OutputPath) == 0
                error("NansenNwb:MissingOutputPath", ...
                    "NwbFileConfiguration.OutputPath must be specified.")
            end

            if isempty(obj.Config.DataItems)
                error("NansenNwb:MissingDataItems", ...
                    "NwbFileConfiguration.DataItems must contain at least one item.")
            end
        end

        function prepareOutputFile(obj)
            filePath = obj.Config.OutputPath;
            parentFolder = fileparts(filePath);
            if parentFolder ~= "" && ~isfolder(parentFolder)
                mkdir(parentFolder)
            end

            shouldInitialize = obj.Config.WriteMode == "overwrite" || ~isfile(filePath);
            if obj.Config.WriteMode == "overwrite" && isfile(filePath)
                delete(filePath)
            end

            if shouldInitialize && obj.shouldInitializeFileBeforeFirstItem()
                nwbFile = obj.createNwbFile();
                nwbExport(nwbFile, filePath)
            end
        end

        function convertDataItem(obj, dataItem)
            descriptor = obj.resolveDescriptor(dataItem);
            nwbFile = obj.readNwbFileForConverter(descriptor);
            converterArgs = obj.mergeConverterArgs(descriptor.DefaultConverterArgs, ...
                dataItem.ConverterArgs);

            data = [];
            if descriptor.NeedsData
                data = obj.resolveData(dataItem.VariableName);
            end

            context = struct( ...
                "Config", obj.Config, ...
                "DataItem", dataItem, ...
                "Descriptor", descriptor, ...
                "NwbFile", nwbFile, ...
                "FilePath", obj.Config.OutputPath, ...
                "Data", data, ...
                "Metadata", dataItem.Metadata, ...
                "ConverterArgs", converterArgs, ...
                "Placement", obj.createPlacement(dataItem, descriptor));

            try
                result = descriptor.Function(context);
            catch exception
                error("NansenNwb:ConverterFailed", ...
                    "Converter '%s' failed for data item '%s': %s", ...
                    descriptor.Name, dataItem.VariableName, exception.message)
            end

            if descriptor.ExecutionMode == "mutate"
                nwbFile = obj.getReturnedNwbFile(result, context.NwbFile);
                nwbExport(nwbFile, obj.Config.OutputPath)
            else
                obj.assertExternalConverterWroteFile(result, descriptor)
            end
        end

        function descriptor = resolveDescriptor(obj, dataItem)
            converterName = string(dataItem.ConverterName);
            if converterName ~= "" && converterName ~= "Default"
                descriptor = obj.Registry.get(converterName);
                return
            end

            sourceInfo = dataItem.SourceInfo;
            if isfield(sourceInfo, 'DataType') && string(sourceInfo.DataType) == "timetable"
                descriptor = obj.Registry.get("TimetableTimeSeries");
                return
            end

            sourceDescriptors = obj.Registry.findForSourceInfo(sourceInfo);
            sourceDescriptors = sourceDescriptors(string({sourceDescriptors.Name}) ~= "GenericMatNwbType");
            if isscalar(sourceDescriptors)
                descriptor = sourceDescriptors;
                return
            end

            if ~obj.isUnsetText(dataItem.TargetNwbType)
                descriptor = obj.Registry.get("GenericMatNwbType");
                return
            end

            error("NansenNwb:UnresolvedConverter", ...
                "Could not resolve a converter for data item '%s'.", dataItem.VariableName)
        end

        function placement = createPlacement(~, dataItem, descriptor)
            configuredName = string(dataItem.NWBVariableName);
            if configuredName == ""
                configuredName = string(dataItem.VariableName);
            end

            if descriptor.PlacementPolicy == "converter" && ~descriptor.AllowsPlacementOverride
                primaryGroup = descriptor.PrimaryGroup;
            else
                primaryGroup = dataItem.PrimaryGroup;
            end

            placement = struct( ...
                "Name", configuredName, ...
                "PrimaryGroup", primaryGroup, ...
                "NwbModule", dataItem.NwbModule);
        end

        function data = resolveData(obj, variableName)
            if isempty(obj.DataResolver)
                error("NansenNwb:MissingDataResolver", ...
                    "A DataResolver is required to load data item '%s'.", variableName)
            end

            if isa(obj.DataResolver, "function_handle")
                data = obj.DataResolver(variableName);
            elseif isa(obj.DataResolver, "containers.Map")
                data = obj.DataResolver(char(variableName));
            elseif isstruct(obj.DataResolver) && isfield(obj.DataResolver, char(variableName))
                data = obj.DataResolver.(char(variableName));
            else
                error("NansenNwb:InvalidDataResolver", ...
                    "DataResolver must be a function handle, containers.Map, or struct.")
            end
        end

        function converterArgs = mergeConverterArgs(~, defaultArgs, itemArgs)
            converterArgs = defaultArgs;
            if isempty(itemArgs)
                return
            end

            fieldNames = fieldnames(itemArgs);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                converterArgs.(fieldName) = itemArgs.(fieldName);
            end
        end

        function nwbFile = createNwbFile(obj)
            metadata = obj.Config.SessionMetadata;
            obj.assertRequiredSessionMetadata(metadata)
            metadata.session_start_time = obj.normalizeSessionStartTime(metadata.session_start_time);

            nwbFileArgs = obj.structToNameValuePairs(metadata);
            nwbFile = NwbFile(nwbFileArgs{:});

            if ~isempty(fieldnames(obj.Config.SubjectMetadata))
                subjectArgs = obj.structToNameValuePairs(obj.Config.SubjectMetadata);
                subject = types.core.Subject(subjectArgs{:});
                nwbFile.general_subject = subject;
            end

            obj.applyGeneralMetadata(nwbFile, obj.Config.GeneralMetadata)
        end

        function tf = shouldInitializeFileBeforeFirstItem(obj)
            firstDescriptor = obj.resolveDescriptor(obj.Config.DataItems(1));
            tf = firstDescriptor.ExecutionMode ~= "external" || ...
                firstDescriptor.PlacementPolicy ~= "converter";
        end

        function nwbFile = readNwbFileForConverter(obj, descriptor)
            if isfile(obj.Config.OutputPath)
                nwbFile = nwbRead(obj.Config.OutputPath);
                return
            end

            if descriptor.ExecutionMode == "mutate"
                error("NansenNwb:MissingNwbFile", ...
                    "Converter '%s' needs an existing NWB file before it can run.", ...
                    descriptor.Name)
            end

            nwbFile = [];
        end

        function applyGeneralMetadata(obj, nwbFile, metadata)
            fieldNames = fieldnames(metadata);
            for i = 1:numel(fieldNames)
                fieldName = string(fieldNames{i});
                if startsWith(fieldName, "general_")
                    propertyName = fieldName;
                else
                    propertyName = "general_" + fieldName;
                end

                if ~isprop(nwbFile, propertyName)
                    error("NansenNwb:InvalidGeneralMetadata", ...
                        "NwbFile has no general metadata property named '%s'.", propertyName)
                end
                nwbFile.(propertyName) = obj.normalizeScalarString(metadata.(fieldNames{i}));
            end
        end
    end

    methods (Static, Access = private)
        function assertRequiredSessionMetadata(metadata)
            requiredFields = ["session_description", "identifier", "session_start_time"];
            for i = 1:numel(requiredFields)
                fieldName = requiredFields(i);
                if ~isfield(metadata, fieldName) || isempty(metadata.(fieldName))
                    error("NansenNwb:MissingSessionMetadata", ...
                        "SessionMetadata.%s is required to initialize an NWB file.", fieldName)
                end
            end
        end

        function value = normalizeSessionStartTime(value)
            if isstring(value) || ischar(value)
                value = datetime(string(value));
            end

            if ~isdatetime(value)
                error("NansenNwb:InvalidSessionStartTime", ...
                    "SessionMetadata.session_start_time must be a datetime or parseable text.")
            end

            if value.TimeZone == ""
                error("NansenNwb:TimezoneRequired", ...
                    "SessionMetadata.session_start_time must include a timezone.")
            end
        end

        function nwbFile = getReturnedNwbFile(result, currentNwbFile)
            if isa(result, "NwbFile")
                nwbFile = result;
            elseif isstruct(result) && isfield(result, "NwbFile") && isa(result.NwbFile, "NwbFile")
                nwbFile = result.NwbFile;
            else
                nwbFile = currentNwbFile;
            end
        end

        function assertExternalConverterWroteFile(result, descriptor)
            if isstruct(result) && isfield(result, "DidWriteFile") && result.DidWriteFile && ...
                    isfield(result, "FilePath") && isfile(result.FilePath)
                return
            end

            if isstruct(result) && isfield(result, "DidWriteFile") && result.DidWriteFile
                return
            end

            error("NansenNwb:ExternalConverterDidNotWriteFile", ...
                "External converter '%s' must write the NWB file and return DidWriteFile=true.", ...
                descriptor.Name)
        end

        function nvPairs = structToNameValuePairs(S)
            fieldNames = fieldnames(S);
            nvPairs = cell(1, 2*numel(fieldNames));
            for i = 1:numel(fieldNames)
                nvPairs{2*i-1} = fieldNames{i};
                nvPairs{2*i} = nansen.module.nwb.conversion.NwbFileConverter.normalizeScalarString( ...
                    S.(fieldNames{i}));
            end
        end

        function value = normalizeScalarString(value)
            if isstring(value) && isscalar(value)
                value = char(value);
            elseif isstring(value)
                value = cellstr(value);
            end
        end

        function tf = isUnsetText(value)
            value = strtrim(string(value));
            tf = value == "" || ismissing(value) || startsWith(value, "<");
        end
    end
end
