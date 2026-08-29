classdef NWBFileConverter < handle
%NWBFileConverter - Write an NWB file from a conversion configuration
%   OBJ = NWBFileConverter(CONFIG) creates a converter for the
%   NWBFileConfiguration CONFIG. CONFIG names the output file, the
%   file-level metadata, and the data items to convert.
%
%   OBJ = NWBFileConverter(...,DataResolver=RESOLVER) also supplies the
%   data. RESOLVER is a function handle taking a variable name and
%   returning its data, a containers.Map, or a struct of variables. A
%   NANSEN session passes @(name) sessionObject.loadData(name); anyone
%   else passes their own. Converters that read their source file
%   directly need no resolver.
%
%   OBJ = NWBFileConverter(...,Registry=REGISTRY) also uses a specific
%   converter registry rather than the shared one.
%
%   OBJ = NWBFileConverter(...,OnItemError=MODE) also says what to do
%   when one item fails. MODE must be:
%       "stop"     - (default) Raise, leaving the file as it was
%       "continue" - Warn, convert the rest, and report at the end
%
%   The converter has no NANSEN dependency: it takes a configuration and
%   a way to get data, and produces an NWB file.
%
%   NWBFileConverter functions:
%       convert - Write the NWB file and return its path
%
%   NWBFileConverter properties:
%       Config       - The configuration being converted
%       Registry     - Registry the converters are looked up in
%       DataResolver - How the runner obtains data for a variable
%       OnItemError  - What to do when one data item fails
%
%   Example: Convert one timetable without a NANSEN session
%       config = nansen.module.nwb.config.NWBFileConfiguration( ...
%           OutputPath="/data/test.nwb", ...
%           SessionMetadata=struct("session_description", "demo", ...
%               "identifier", "demo-01", ...
%               "session_start_time", datetime("now", TimeZone="local")), ...
%           DataItems=nansen.module.nwb.config.NWBDataItemConfig( ...
%               VariableName="trials", ConverterName="TimetableTimeSeries"));
%       converter = nansen.module.nwb.conversion.NWBFileConverter( ...
%           config, DataResolver=@(name) myTrialsTimetable);
%       filePath = converter.convert();
%
%   See also nansen.module.nwb.config.NWBFileConfiguration,
%   nansen.module.nwb.conversion.ConverterRegistry

    properties (SetAccess = private)
        Config (1,1) nansen.module.nwb.config.NWBFileConfiguration % The configuration being converted
        Registry (1,1) nansen.module.nwb.conversion.ConverterRegistry % Registry the converters are looked up in
    end

    properties
        DataResolver = []                   % How the runner obtains data for a variable
        OnItemError (1,1) string ...
            {mustBeMember(OnItemError, ["stop", "continue"])} = "stop" % What to do when one data item fails
    end

    properties (Access = private)
        %WorkingNwbFile - In-memory file, empty when it must be read from disk
        WorkingNwbFile = []

        %HasUnexportedChanges - Whether memory is ahead of the file on disk
        HasUnexportedChanges (1,1) logical = false

        %FailedItems - Items that failed while OnItemError was "continue"
        FailedItems (1,:) string = strings(1, 0)
    end

    methods
        function obj = NWBFileConverter(config, options)
            arguments
                config
                options.DataResolver = []
                options.Registry (1,1) nansen.module.nwb.conversion.ConverterRegistry = ...
                    nansen.module.nwb.conversion.ConverterRegistry.instance()
                options.OnItemError (1,1) string ...
                    {mustBeMember(options.OnItemError, ["stop", "continue"])} = "stop"
            end

            obj.Config = nansen.module.nwb.config.NWBFileConfiguration.fromAny(config);
            obj.DataResolver = options.DataResolver;
            obj.Registry = options.Registry;
            obj.OnItemError = options.OnItemError;
        end

        function filePath = convert(obj)
            %convert - Write the NWB file and return its path
            %   filePath = convert(OBJ) creates the NWB file, converts
            %   every data item into it, and returns where it was written.
            %
            %   The file is created first, from the session, subject and
            %   general metadata, so every converter has a file to add to
            %   and only one of them writes the file-level metadata.
            %
            %   Items are ordered so that converters producing a type run
            %   before converters requiring it, whatever order the
            %   configuration lists them in.
            %
            %   Errors:
            %     nansen:nwb:converterFailed - a data item failed to
            %                     convert and OnItemError is "stop".
            %     nansen:nwb:itemsFailed - one or more items failed while
            %                     OnItemError was "continue".

            obj.validateConfig()

            obj.WorkingNwbFile = [];
            obj.HasUnexportedChanges = false;
            obj.FailedItems = strings(1, 0);

            obj.createOutputFile()

            dataItems = obj.orderDataItems(obj.Config.DataItems);
            for i = 1:numel(dataItems)
                obj.convertDataItem(dataItems(i))
            end

            obj.flushToDisk()

            if ~isempty(obj.FailedItems)
                error("nansen:nwb:itemsFailed", ...
                    ['%d of %d data items could not be converted: %s. The ', ...
                     'file ''%s'' holds everything that did convert.'], ...
                    numel(obj.FailedItems), numel(dataItems), ...
                    strjoin(obj.FailedItems, ", "), obj.Config.OutputPath)
            end

            filePath = obj.Config.OutputPath;
        end
    end

    methods (Access = private)
        function validateConfig(obj)
            %validateConfig - Reject a configuration nothing can be done with

            if strlength(strtrim(obj.Config.OutputPath)) == 0
                error("nansen:nwb:missingOutputPath", ...
                    ['The configuration names no output file. Set ', ...
                     'OutputPath on the configuration.'])
            end

            if isempty(obj.Config.DataItems)
                error("nansen:nwb:missingDataItems", ...
                    ['The configuration for ''%s'' holds no data items, so ', ...
                     'there is nothing to convert. Add items in the ', ...
                     'configurator.'], obj.Config.OutputPath)
            end
        end

        function createOutputFile(obj)
            %createOutputFile - Initialize the output NWB file in memory
            %
            %   The runner owns file creation. Converters that write the
            %   file themselves, NeuroConv-backed ones in particular,
            %   append to what this wrote, so the session and subject
            %   metadata is written exactly once and by one writer.
            %
            %   The file only reaches disk when something needs it there:
            %   before an external converter runs, or at the end. A run
            %   that fails before then leaves no half-written file behind.

            filePath = obj.Config.OutputPath;

            parentFolder = fileparts(filePath);
            if parentFolder ~= "" && ~isfolder(parentFolder)
                mkdir(parentFolder)
            end

            if obj.Config.WriteMode == "overwrite" && isfile(filePath)
                delete(filePath)
            end

            % In append mode the file already carries its own file-level
            % metadata, and the first converter that needs it reads it.
            if isfile(filePath)
                return
            end

            obj.WorkingNwbFile = obj.buildNwbFile();
            obj.HasUnexportedChanges = true;
        end

        function nwbFile = buildNwbFile(obj)
            %buildNwbFile - Build the NwbFile from the file-level metadata

            metadata = obj.Config.SessionMetadata;
            obj.assertRequiredSessionMetadata(metadata)
            metadata.session_start_time = ...
                obj.normalizeSessionStartTime(metadata.session_start_time);

            sessionArgs = obj.structToNameValuePairs(metadata);
            nwbFile = NwbFile(sessionArgs{:});

            if ~isempty(fieldnames(obj.Config.SubjectMetadata))
                subjectArgs = obj.structToNameValuePairs(obj.Config.SubjectMetadata);
                nwbFile.general_subject = types.core.Subject(subjectArgs{:});
            end

            obj.applyGeneralMetadata(nwbFile, obj.Config.GeneralMetadata)
        end

        function convertDataItem(obj, dataItem)
            %convertDataItem - Run one data item through its converter

            descriptor = obj.resolveDescriptor(dataItem);

            try
                obj.runConverter(dataItem, descriptor)
            catch cause
                if obj.OnItemError == "continue"
                    warning("nansen:nwb:converterFailed", ...
                        "Skipping ''%s'': %s", dataItem.VariableName, cause.message)
                    obj.FailedItems(end+1) = dataItem.VariableName;
                    return
                end

                exception = MException("nansen:nwb:converterFailed", ...
                    ['The converter ''%s'' failed on data item ''%s''. The ', ...
                     'underlying error is attached below.'], ...
                    descriptor.Name, dataItem.VariableName);
                throw(addCause(exception, cause))
            end
        end

        function runConverter(obj, dataItem, descriptor)
            %runConverter - Invoke one converter and take up its result

            converterArgs = obj.mergeConverterArgs( ...
                descriptor.DefaultConverterArgs, dataItem.ConverterArgs);

            data = [];
            if descriptor.NeedsData
                data = obj.resolveData(dataItem.VariableName);
            end

            isExternalWriter = descriptor.ExecutionMode == "external";

            if isExternalWriter
                % An external converter reads and writes the file on disk,
                % so anything still only in memory has to be written first
                % or it would be lost when the file is read back.
                obj.flushToDisk()
            else
                obj.ensureNwbFileLoaded()
            end

            context = struct( ...
                "Config", obj.Config, ...
                "DataItem", dataItem, ...
                "Descriptor", descriptor, ...
                "NwbFile", obj.WorkingNwbFile, ...
                "FilePath", obj.Config.OutputPath, ...
                "Data", data, ...
                "Metadata", dataItem.Metadata, ...
                "ConverterArgs", converterArgs, ...
                "Placement", obj.createPlacement(dataItem, descriptor));

            result = obj.callConverter(descriptor, context);

            if isExternalWriter
                obj.assertExternalConverterWroteFile(result, descriptor)
                % The file on disk moved on without us; read it again
                % before the next converter mutates it.
                obj.WorkingNwbFile = [];
                obj.HasUnexportedChanges = false;
            else
                obj.WorkingNwbFile = obj.takeReturnedNwbFile(result, context);
                obj.HasUnexportedChanges = true;
            end
        end

        function result = callConverter(~, descriptor, context)
            %callConverter - Invoke a converter, whether or not it returns
            %
            %   An NwbFile is a handle, so a converter can do its work by
            %   mutating the one in the context and return nothing.
            %   Demanding an output from such a converter would fail with
            %   an error about output arguments rather than anything its
            %   author could act on.

            try
                declaredOutputs = nargout(descriptor.Function);
            catch
                % An anonymous handle, or one whose function is not on the
                % path. Ask for an output and let the call report it.
                declaredOutputs = 1;
            end

            if declaredOutputs == 0
                descriptor.Function(context);
                result = [];
            else
                result = descriptor.Function(context);
            end
        end

        function ensureNwbFileLoaded(obj)
            %ensureNwbFileLoaded - Read the file when it is not in memory

            if ~isempty(obj.WorkingNwbFile)
                return
            end

            obj.WorkingNwbFile = nwbRead(obj.Config.OutputPath);
            obj.HasUnexportedChanges = false;
        end

        function flushToDisk(obj)
            %flushToDisk - Write pending changes, if there are any
            %
            %   NwbFile.export appends an entry to file_create_date every
            %   time it is called and rewrites the whole file, so the
            %   runner exports as rarely as correctness allows.

            if ~obj.HasUnexportedChanges || isempty(obj.WorkingNwbFile)
                return
            end

            nwbExport(obj.WorkingNwbFile, obj.Config.OutputPath)
            obj.HasUnexportedChanges = false;
        end

        function dataItems = orderDataItems(obj, dataItems)
            %orderDataItems - Put producers before the items requiring them

            descriptors = arrayfun(@(item) obj.resolveDescriptor(item), ...
                dataItems, "UniformOutput", false);
            producedTypes = cellfun(@(d) d.ProducesNWBType, descriptors);

            % Appending to a file that already exists may satisfy a
            % requirement no item in this run produces.
            isAppending = obj.Config.WriteMode == "append";

            ordered = false(numel(dataItems), 1);
            order = zeros(numel(dataItems), 1);

            for position = 1:numel(dataItems)
                nextIndex = 0;
                for i = 1:numel(dataItems)
                    if ordered(i)
                        continue
                    end
                    if obj.areRequirementsMet(descriptors{i}, producedTypes(ordered), ...
                            producedTypes, isAppending)
                        nextIndex = i;
                        break
                    end
                end

                if nextIndex == 0
                    obj.failOnUnmetRequirements(dataItems, descriptors, ordered)
                end

                ordered(nextIndex) = true;
                order(position) = nextIndex;
            end

            dataItems = dataItems(order);
        end

        function tf = areRequirementsMet(~, descriptor, satisfiedTypes, allProducedTypes, isAppending)
            %areRequirementsMet - Whether a converter can run at this point

            required = descriptor.RequiresNWBTypes;
            if isempty(required)
                tf = true;
                return
            end

            for i = 1:numel(required)
                if any(satisfiedTypes == required(i))
                    continue
                end

                % Nothing in this run produces it. When appending, the
                % file may already hold it, and the converter checks that
                % for itself; otherwise the requirement cannot be met.
                if isAppending && ~any(allProducedTypes == required(i))
                    continue
                end

                tf = false;
                return
            end

            tf = true;
        end

        function failOnUnmetRequirements(~, dataItems, descriptors, ordered)
            %failOnUnmetRequirements - Report what is missing and for whom

            blockedIndices = find(~ordered);
            firstBlocked = blockedIndices(1);
            descriptor = descriptors{firstBlocked};

            error("nansen:nwb:unmetRequirement", ...
                ['''%s'' needs %s to exist in the file before it can be ', ...
                 'converted, and no data item produces that. Add an item ', ...
                 'that produces it, or append to a file that already has ', ...
                 'it.'], dataItems(firstBlocked).VariableName, ...
                strjoin(descriptor.RequiresNWBTypes, " and "))
        end

        function descriptor = resolveDescriptor(obj, dataItem)
            %resolveDescriptor - Decide which converter handles an item

            converterName = dataItem.ConverterName;
            if strlength(converterName) > 0 && converterName ~= "Default"
                descriptor = obj.Registry.get(converterName);
                return
            end

            % Without a named converter, the source evidence has to
            % identify one on its own. Only an unambiguous match will do:
            % guessing between two plausible converters would silently
            % write the wrong thing.
            [candidates, ranks] = obj.Registry.findForSourceInfo(dataItem.SourceInfo);
            isSpecific = ranks > 1;
            candidates = candidates(isSpecific);

            if isscalar(candidates)
                descriptor = candidates;
                return
            end

            % A named target type is enough for the generic converter.
            if ~obj.isUnsetText(dataItem.TargetNWBType)
                descriptor = obj.Registry.get("GenericNeurodataType");
                return
            end

            if isempty(candidates)
                error("nansen:nwb:unresolvedConverter", ...
                    ['No converter matches ''%s''. Set ConverterName on the ', ...
                     'data item, or set TargetNWBType to build a neurodata ', ...
                     'type generically.'], dataItem.VariableName)
            end

            error("nansen:nwb:unresolvedConverter", ...
                ['Several converters match ''%s'': %s. Set ConverterName on ', ...
                 'the data item to choose one.'], dataItem.VariableName, ...
                strjoin([candidates.Name], ", "))
        end

        function placement = createPlacement(~, dataItem, descriptor)
            %createPlacement - Work out where this item's output belongs

            configuredName = dataItem.NWBVariableName;
            if strlength(configuredName) == 0
                configuredName = dataItem.VariableName;
            end

            % Placement is the configuration's to decide, except where the
            % converter declared that it owns placement.
            if descriptor.PlacementPolicy == "converter" && ~descriptor.AllowsPlacementOverride
                primaryGroup = descriptor.PrimaryGroup;
            else
                primaryGroup = dataItem.PrimaryGroup;
            end

            placement = struct( ...
                "Name", configuredName, ...
                "PrimaryGroup", primaryGroup, ...
                "NWBModule", dataItem.NWBModule);
        end

        function data = resolveData(obj, variableName)
            %resolveData - Obtain the data for one variable
            %
            %   What comes back is whatever the resolver returns, which
            %   for large data is a lazy object rather than an array. A
            %   converter must not force the whole thing into memory
            %   unless it declared that it does.

            if isempty(obj.DataResolver)
                error("nansen:nwb:missingDataResolver", ...
                    ['''%s'' needs its data loaded, but the converter was ', ...
                     'created without a DataResolver. Pass DataResolver as ', ...
                     'a function of the variable name.'], variableName)
            end

            if isa(obj.DataResolver, "function_handle")
                data = obj.DataResolver(variableName);
            elseif isa(obj.DataResolver, "containers.Map")
                data = obj.DataResolver(char(variableName));
            elseif isstruct(obj.DataResolver) && isfield(obj.DataResolver, variableName)
                data = obj.DataResolver.(variableName);
            else
                error("nansen:nwb:invalidDataResolver", ...
                    ['DataResolver must be a function handle, a ', ...
                     'containers.Map, or a struct with a field named after ', ...
                     'each variable. ''%s'' could not be resolved from a ', ...
                     '%s.'], variableName, class(obj.DataResolver))
            end
        end

        function converterArgs = mergeConverterArgs(~, defaultArgs, itemArgs)
            %mergeConverterArgs - Lay per-item arguments over the defaults

            converterArgs = defaultArgs;

            fieldNames = fieldnames(itemArgs);
            for i = 1:numel(fieldNames)
                converterArgs.(fieldNames{i}) = itemArgs.(fieldNames{i});
            end
        end

        function nwbFile = takeReturnedNwbFile(~, result, context)
            %takeReturnedNwbFile - Read the file back out of a result
            %
            %   A converter may return the mutated file, or hand back a
            %   neurodata object for the runner to place.

            import nansen.module.nwb.conversion.resolvePlacement
            import nansen.module.nwb.conversion.placeNeurodata

            if isa(result, "NwbFile")
                nwbFile = result;
                return
            end

            if ~isstruct(result)
                nwbFile = context.NwbFile;
                return
            end

            if isfield(result, "NwbFile") && isa(result.NwbFile, "NwbFile")
                nwbFile = result.NwbFile;
                return
            end

            if isfield(result, "NeuroData") && ~isempty(result.NeuroData)
                placement = resolvePlacement(context.Placement, result, context.Descriptor);
                nwbFile = placeNeurodata(context.NwbFile, result.NeuroData, ...
                    placement, context.Placement.Name);
                return
            end

            nwbFile = context.NwbFile;
        end

        function applyGeneralMetadata(obj, nwbFile, metadata)
            %applyGeneralMetadata - Set the general_ properties on the file

            fieldNames = string(fieldnames(metadata));
            for i = 1:numel(fieldNames)
                fieldName = fieldNames(i);

                if startsWith(fieldName, "general_")
                    propertyName = fieldName;
                else
                    propertyName = "general_" + fieldName;
                end

                if ~isprop(nwbFile, propertyName)
                    error("nansen:nwb:invalidGeneralMetadata", ...
                        ['An NWB file has no general metadata field named ', ...
                         '''%s''. Check the spelling in GeneralMetadata.'], ...
                        fieldName)
                end

                nwbFile.(propertyName) = obj.normalizeScalarString(metadata.(fieldName));
            end
        end
    end

    methods (Static, Access = private)
        function assertRequiredSessionMetadata(metadata)
            %assertRequiredSessionMetadata - Require what NWB requires

            requiredFields = ["session_description", "identifier", "session_start_time"];
            missingFields = requiredFields(arrayfun(@(name) ...
                ~isfield(metadata, name) || isempty(metadata.(name)), requiredFields));

            if ~isempty(missingFields)
                error("nansen:nwb:missingSessionMetadata", ...
                    ['An NWB file needs %s. Set SessionMetadata on the ', ...
                     'configuration, or export from a session that records ', ...
                     'them.'], strjoin(missingFields, ", "))
            end
        end

        function value = normalizeSessionStartTime(value)
            %normalizeSessionStartTime - Require a zoned session start time

            if isstring(value) || ischar(value)
                value = datetime(string(value));
            end

            if ~isdatetime(value) || ~isscalar(value)
                error("nansen:nwb:invalidSessionStartTime", ...
                    ['session_start_time must be a datetime, or text a ', ...
                     'datetime can be read from, but was %s.'], class(value))
            end

            % A time without a zone is ambiguous to every later reader of
            % the file, and NWB requires it to be resolvable.
            if value.TimeZone == ""
                error("nansen:nwb:missingTimeZone", ...
                    ['session_start_time has no time zone. Set one, for ', ...
                     'example datetime(t, TimeZone="local").'])
            end
        end

        function assertExternalConverterWroteFile(result, descriptor)
            %assertExternalConverterWroteFile - Hold an external converter to its contract

            didWrite = isstruct(result) && isfield(result, "DidWriteFile") && ...
                isscalar(result.DidWriteFile) && result.DidWriteFile;

            if ~didWrite
                error("nansen:nwb:externalConverterDidNotWrite", ...
                    ['The converter ''%s'' writes the NWB file itself, but ', ...
                     'did not report doing so. It must return a struct with ', ...
                     'DidWriteFile set to true.'], descriptor.Name)
            end
        end

        function nvPairs = structToNameValuePairs(S)
            %structToNameValuePairs - Flatten a struct for a constructor call

            import nansen.module.nwb.conversion.NWBFileConverter

            fieldNames = fieldnames(S);
            nvPairs = cell(1, 2*numel(fieldNames));
            for i = 1:numel(fieldNames)
                nvPairs{2*i - 1} = fieldNames{i};
                nvPairs{2*i} = NWBFileConverter.normalizeScalarString(S.(fieldNames{i}));
            end
        end

        function value = normalizeScalarString(value)
            %normalizeScalarString - Give matnwb the text shape it expects

            if isstring(value) && isscalar(value)
                value = char(value);
            elseif isstring(value)
                value = cellstr(value);
            end
        end

        function tf = isUnsetText(value)
            %isUnsetText - True for blank text or a configurator placeholder

            value = strtrim(string(value));
            tf = ismissing(value) || value == "" || startsWith(value, "<");
        end
    end
end
