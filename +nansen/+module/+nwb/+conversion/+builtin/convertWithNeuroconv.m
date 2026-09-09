function result = convertWithNeuroconv(context)
%convertWithNeuroconv - Run one configured NeuroConv data interface
%   RESULT = convertWithNeuroconv(CONTEXT) instantiates the NeuroConv data
%   interface named in the converter arguments, points it at the data
%   item's source path, and appends what it produces to the NWB file at
%   CONTEXT.FilePath.
%
%   The runner creates the NWB file and writes the session, subject and
%   general metadata into it before any converter runs, so this converter
%   always appends and passes only the item's own metadata. Appending
%   drops the fields NeuroConv would otherwise require inside its NWBFile
%   metadata section, which is what makes that split work; the section
%   itself is still required, so it is sent empty.
%
%   Converter arguments:
%       InterfaceClassName - NeuroConv interface to run, for example
%                            "ScanImageImagingInterface"
%       SourceArgumentName - Constructor argument the path is passed as
%       SourcePathMode     - How to derive that path from the data item
%       PythonExecutable   - Python interpreter to use, when not the default
%       RunConversionArgs  - Extra arguments forwarded to run_conversion
%       UseInterfaceMetadata - Whether to start from the metadata the
%                            interface reads out of its own files, with
%                            the item's metadata laid over it. Needed by
%                            interfaces that derive electrodes or tables
%                            from file headers, such as AbfInterface
%
%   Errors:
%     nansen:nwb:missingConverterArg - InterfaceClassName is not set.
%     nansen:nwb:missingOutputFile - the NWB file to append to is absent.
%
%   See also nansen.module.nwb.neuroconv.runConversion,
%   nansen.module.nwb.neuroconv.resolveSourceArg

    arguments
        context (1,1) struct
    end

    import nansen.module.nwb.conversion.getConverterArg

    args = context.ConverterArgs;

    interfaceClassName = string(getConverterArg(args, "InterfaceClassName", ""));
    if strlength(interfaceClassName) == 0
        error("nansen:nwb:missingConverterArg", ...
            ['''%s'' uses a NeuroConv converter but names no interface. ', ...
             'Set ConverterArgs.InterfaceClassName, for example to ', ...
             '"ScanImageImagingInterface".'], context.DataItem.VariableName)
    end

    % NeuroConv refuses to touch an existing file unless told whether to
    % append or overwrite, and refuses to append to a file that is not
    % there. The runner is responsible for creating it first.
    if ~isfile(context.FilePath)
        error("nansen:nwb:missingOutputFile", ...
            ['The NWB file ''%s'' does not exist, so there is nothing for ', ...
             'NeuroConv to append to. This is a conversion runner fault.'], ...
            context.FilePath)
    end

    sourceArg = nansen.module.nwb.neuroconv.resolveSourceArg(context.DataItem, args);

    runArguments = {"AppendOnDiskNwbFile", true, "ExecutionMode", "OutOfProcess"};

    pythonExecutable = getConverterArg(args, "PythonExecutable", "");
    if strlength(string(pythonExecutable)) > 0
        runArguments = [runArguments, {"PythonExecutable", string(pythonExecutable)}];
    end

    runConversionArgs = getConverterArg(args, "RunConversionArgs", struct());
    if isstruct(runConversionArgs)
        runArguments = [runArguments, {"RunConversionArgs", runConversionArgs}];
    end

    useInterfaceMetadata = getConverterArg(args, "UseInterfaceMetadata", false);
    runArguments = [runArguments, {"UseInterfaceMetadata", logical(useInterfaceMetadata)}];

    nansen.module.nwb.neuroconv.runConversion(interfaceClassName, sourceArg, ...
        context.FilePath, itemMetadata(context), runArguments{:});

    result = struct("DidWriteFile", true);
end

function metadata = itemMetadata(context)
%itemMetadata - Metadata for this item, with the session left to the runner
%
%   The runner already wrote NWBFile, Subject and the general metadata
%   into the file. Sending them again would describe the session twice,
%   and disagree with what the runner wrote if the two ever diverged.
%
%   NeuroConv still requires an NWBFile section to be present: appending
%   drops the fields required inside it, not the section itself. So it is
%   emptied rather than removed, and Subject, which is not required, is
%   dropped.

    metadata = context.Metadata;

    if isfield(metadata, "Subject")
        metadata = rmfield(metadata, "Subject");
    end

    metadata.NWBFile = struct();
end
