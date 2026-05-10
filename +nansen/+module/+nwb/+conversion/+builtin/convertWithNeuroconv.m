function result = convertWithNeuroconv(context)
%convertWithNeuroconv Run one configured NeuroConv data interface.

    arguments
        context (1,1) struct
    end

    args = context.ConverterArgs;
    if ~isfield(args, 'InterfaceClassName') || strlength(string(args.InterfaceClassName)) == 0
        error("NansenNwb:MissingNeuroconvInterface", ...
            "NeuroConvDataInterface requires ConverterArgs.InterfaceClassName.")
    end

    sourceArg = resolveSourceArg(context, args);

    runArgs = {"ExecutionMode", "OutOfProcess"};
    if isfield(args, 'PythonExecutable') && ~isempty(args.PythonExecutable)
        runArgs = [runArgs, {"PythonExecutable", string(args.PythonExecutable)}];
    end
    runArgs = addWriteModeArguments(runArgs, args, context.FilePath);
    if isfield(args, 'RunConversionArgs') && isstruct(args.RunConversionArgs)
        runArgs = [runArgs, {"RunConversionArgs", args.RunConversionArgs}];
    end

    metadata = context.Metadata;
    if isempty(fieldnames(metadata))
        metadata = createNeuroconvMetadata(context.Config);
    end

    nansen.module.nwb.neuroconv.runConversion( ...
        string(args.InterfaceClassName), sourceArg, context.FilePath, metadata, runArgs{:});

    result = struct("DidWriteFile", true);
end

function sourceArg = resolveSourceArg(context, args)
    if isfield(args, 'SourceArg') && ~isempty(args.SourceArg)
        if ~isstruct(args.SourceArg)
            error("NansenNwb:InvalidNeuroconvSource", ...
                "ConverterArgs.SourceArg must be a struct of NeuroConv DataInterface constructor arguments.")
        end
        sourceArg = args.SourceArg;
        return
    end

    if isfield(args, 'SourceArgumentName') && ...
            isfield(context.DataItem.SourceInfo, 'Path') && ~isempty(context.DataItem.SourceInfo.Path)
        sourceArg = struct();
        sourceArg.(char(args.SourceArgumentName)) = string(context.DataItem.SourceInfo.Path);
        return
    end

    error("NansenNwb:MissingNeuroconvSource", ...
        "NeuroConvDataInterface requires ConverterArgs.SourceArg, or ConverterArgs.SourceArgumentName plus SourceInfo.Path.")
end

function runArgs = addWriteModeArguments(runArgs, args, filePath)
    hasOverwrite = isfield(args, 'Overwrite') && parseLogicalScalar(args.Overwrite);
    hasAppend = isfield(args, 'AppendOnDiskNwbFile') && parseLogicalScalar(args.AppendOnDiskNwbFile);

    if hasOverwrite && hasAppend
        error("NansenNwb:InvalidNeuroconvWriteMode", ...
            "Set either ConverterArgs.Overwrite or ConverterArgs.AppendOnDiskNwbFile, not both.")
    end

    if hasOverwrite
        runArgs = [runArgs, {"Overwrite", true}];
    elseif hasAppend || isfile(filePath)
        runArgs = [runArgs, {"AppendOnDiskNwbFile", true}];
    end
end

function value = parseLogicalScalar(value)
    if islogical(value)
        value = value(1);
    elseif isnumeric(value)
        value = logical(value(1));
    elseif isstring(value) || ischar(value)
        value = strcmpi(string(value), "true") || strcmp(string(value), "1");
    else
        error("NansenNwb:InvalidLogicalConfigValue", ...
            "Expected a logical scalar configuration value.")
    end
end

function metadata = createNeuroconvMetadata(config)
    metadata = struct();
    metadata.NWBFile = config.SessionMetadata;
    if ~isempty(fieldnames(config.SubjectMetadata))
        metadata.Subject = config.SubjectMetadata;
    end
end
