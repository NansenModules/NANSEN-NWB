function result = convertWithNeuroconv(context)
%convertWithNeuroconv - Run one configured NeuroConv data interface
%   RESULT = convertWithNeuroconv(CONTEXT) instantiates the NeuroConv data
%   interface named in the converter arguments, points it at the data
%   item's source path, and appends what it produces to the NWB file at
%   CONTEXT.FilePath.
%
%   The runner creates the NWB file and writes the session, subject and
%   general metadata into it before any converter runs, so this converter
%   always appends and passes only the item's own metadata. NeuroConv
%   drops the required-field constraints on its NWBFile metadata section
%   when appending, which is what makes that split work.
%
%   Converter arguments:
%       InterfaceClassName - NeuroConv interface to run, for example
%                            "ScanImageImagingInterface"
%       SourceArgumentName - Constructor argument the path is passed as
%       SourcePathMode     - How to derive that path from the data item
%       PythonExecutable   - Python interpreter to use, when not the default
%       RunConversionArgs  - Extra arguments forwarded to run_conversion
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

    nansen.module.nwb.neuroconv.runConversion(interfaceClassName, sourceArg, ...
        context.FilePath, itemMetadata(context), runArguments{:});

    result = struct("DidWriteFile", true);
end

function metadata = itemMetadata(context)
%itemMetadata - Metadata for this item, without the file-level sections
%
%   The runner already wrote NWBFile, Subject and the general metadata
%   into the file. Sending them again would either be ignored or, if the
%   values disagreed with what the runner wrote, describe the session
%   twice.

    metadata = context.Metadata;

    fileLevelSections = ["NWBFile", "Subject"];
    metadata = rmfield(metadata, ...
        intersect(fileLevelSections, string(fieldnames(metadata))));
end
