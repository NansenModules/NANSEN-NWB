function runConversion(interfaceClassName, sourceArg, nwbFilePath, metadata, options)
%runConversion - Run a NeuroConv data interface from MATLAB
%   runConversion(interfaceClassName,sourceArg,nwbFilePath) imports the
%   named interface from neuroconv.datainterfaces, instantiates it with
%   the fields of sourceArg as constructor arguments, and runs its
%   conversion into nwbFilePath.
%
%   runConversion(...,METADATA) also passes a metadata struct, converted
%   to the nested dictionary NeuroConv expects.
%
%   runConversion(...,AppendOnDiskNwbFile=true) appends to the file at
%   nwbFilePath instead of creating it. NeuroConv refuses to touch a file
%   that already exists unless this or Overwrite is set.
%
%   runConversion(...,Overwrite=true) replaces the file instead.
%
%   runConversion(...,PythonExecutable=EXE) loads Python from EXE, when
%   Python has not been loaded into this MATLAB session yet.
%
%   runConversion(...,RunConversionArgs=ARGS) forwards the fields of the
%   struct ARGS to run_conversion as further arguments.
%
%   This is the only place in the module that calls Python. Everything
%   else, including the registry and the configurator, works whether or
%   not Python is available.
%
%   Errors:
%     nansen:nwb:neuroconvFailed - the conversion raised a Python error.
%                     The Python traceback is attached as the cause.
%     nansen:nwb:invalidWriteMode - both Overwrite and
%                     AppendOnDiskNwbFile were requested.
%
%   Example: Append a ScanImage recording to an existing file
%       nansen.module.nwb.neuroconv.runConversion( ...
%           "ScanImageImagingInterface", struct("file_path", "/data/rec.tif"), ...
%           "/data/sub-01_ses-01.nwb", struct(), AppendOnDiskNwbFile=true)
%
%   See also nansen.module.nwb.neuroconv.hasNeuroconv,
%   nansen.module.nwb.neuroconv.resolveSourceArg, pyenv

    arguments
        interfaceClassName (1,1) string
        sourceArg (1,1) struct
        nwbFilePath (1,1) string
        metadata (1,1) struct = struct()
        options.PythonExecutable (1,1) string = ""
        options.ExecutionMode (1,1) string ...
            {mustBeMember(options.ExecutionMode, ["InProcess", "OutOfProcess"])} = "OutOfProcess"
        options.Overwrite (1,1) logical = false
        options.AppendOnDiskNwbFile (1,1) logical = false
        options.RunConversionArgs (1,1) struct = struct()
    end

    if options.Overwrite && options.AppendOnDiskNwbFile
        error("nansen:nwb:invalidWriteMode", ...
            ['NeuroConv can either overwrite the NWB file or append to it, ', ...
             'not both. Set only one of Overwrite and AppendOnDiskNwbFile.'])
    end

    configurePython(options.PythonExecutable, options.ExecutionMode)

    try
        dataInterfaces = py.importlib.import_module("neuroconv.datainterfaces");
        interfaceClass = py.getattr(dataInterfaces, char(interfaceClassName));

        sourceNvPairs = structToPyargs(sourceArg);
        interface = interfaceClass(pyargs(sourceNvPairs{:}));

        runConversionNvPairs = { ...
            "nwbfile_path", char(nwbFilePath), ...
            "metadata", nansen.module.nwb.neuroconv.toPythonValue(metadata)};

        if options.Overwrite
            runConversionNvPairs = [runConversionNvPairs, {"overwrite", py.bool(true)}];
        elseif options.AppendOnDiskNwbFile
            runConversionNvPairs = [runConversionNvPairs, ...
                {"append_on_disk_nwbfile", py.bool(true)}];
        end

        runConversionNvPairs = [runConversionNvPairs, ...
            structToPyargs(options.RunConversionArgs)];

        interface.run_conversion(pyargs(runConversionNvPairs{:}));
    catch cause
        % The Python traceback is the useful part, so it is kept as the
        % cause rather than flattened into the message.
        exception = MException("nansen:nwb:neuroconvFailed", ...
            ['The NeuroConv interface ''%s'' failed while converting into ', ...
             '''%s''. The Python error is attached below.'], ...
            interfaceClassName, nwbFilePath);
        throw(addCause(exception, cause))
    end
end

function configurePython(pythonExecutable, executionMode)
%configurePython - Point MATLAB at the requested Python, if it can

    if strlength(pythonExecutable) == 0
        return
    end

    environment = pyenv();

    if string(environment.Status) == "NotLoaded"
        pyenv("Version", pythonExecutable, "ExecutionMode", executionMode);
        return
    end

    % MATLAB loads one Python per session, so a second, different
    % interpreter cannot be honored without a restart.
    if string(environment.Executable) ~= pythonExecutable
        error("nansen:nwb:pythonAlreadyLoaded", ...
            ['Python is already loaded in this MATLAB session from ''%s'', ', ...
             'so ''%s'' cannot be used. Restart MATLAB to switch ', ...
             'interpreters.'], string(environment.Executable), pythonExecutable)
    end
end

function nvPairs = structToPyargs(S)
%structToPyargs - Flatten a struct into name-value pairs for pyargs

    fieldNames = fieldnames(S);
    nvPairs = cell(1, 2*numel(fieldNames));

    for i = 1:numel(fieldNames)
        nvPairs{2*i - 1} = fieldNames{i};
        nvPairs{2*i} = nansen.module.nwb.neuroconv.toPythonValue(S.(fieldNames{i}));
    end
end
