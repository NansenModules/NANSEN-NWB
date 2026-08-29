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
            "metadata", matlabToPython(metadata)};

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
        nvPairs{2*i} = matlabToPython(S.(fieldNames{i}));
    end
end

function pyValue = matlabToPython(value)
%matlabToPython - Convert a MATLAB value to its Python counterpart

    if isa(value, "py.object")
        pyValue = value;
    elseif isstruct(value)
        pyValue = structToPyDict(value);
    elseif iscell(value)
        pyValue = cellToPyList(value);
    elseif isstring(value)
        pyValue = stringToPython(value);
    elseif ischar(value)
        pyValue = char(value);
    elseif isdatetime(value)
        pyValue = datetimeToPython(value);
    elseif isduration(value)
        pyValue = seconds(value);
    elseif islogical(value)
        pyValue = logicalToPython(value);
    elseif isnumeric(value)
        pyValue = numericToPython(value);
    else
        pyValue = value;
    end
end

function pyDict = structToPyDict(S)
%structToPyDict - Convert a struct to a dict, or an array to a list

    if ~isscalar(S)
        pyDict = py.list();
        for i = 1:numel(S)
            pyDict.append(structToPyDict(S(i)));
        end
        return
    end

    pyDict = py.dict();
    fieldNames = fieldnames(S);
    for i = 1:numel(fieldNames)
        pyDict{fieldNames{i}} = matlabToPython(S.(fieldNames{i}));
    end
end

function pyList = cellToPyList(C)
%cellToPyList - Convert a cell array to a list

    pyList = py.list();
    for i = 1:numel(C)
        pyList.append(matlabToPython(C{i}));
    end
end

function pyValue = stringToPython(value)
%stringToPython - Convert a string scalar to str, an array to a list

    if isscalar(value)
        pyValue = char(value);
        return
    end

    pyValue = py.list();
    for i = 1:numel(value)
        pyValue.append(char(value(i)));
    end
end

function pyValue = datetimeToPython(value)
%datetimeToPython - Convert a zoned datetime to datetime.datetime

    if ~isscalar(value)
        pyValue = py.list();
        for i = 1:numel(value)
            pyValue.append(datetimeToPython(value(i)));
        end
        return
    end

    % NWB requires session times to carry a timezone, and a naive Python
    % datetime would be written as if it were local to the reader.
    if string(value.TimeZone) == ""
        error("nansen:nwb:missingTimeZone", ...
            ['The datetime %s has no time zone. NWB timestamps must be ', ...
             'zoned; set the TimeZone property before converting.'], ...
            string(value))
    end

    [yearValue, monthValue, dayValue] = ymd(value);
    [hourValue, minuteValue, secondValue] = hms(value);
    wholeSecond = floor(secondValue);
    microsecond = round((secondValue - wholeSecond) * 1e6);

    pyValue = py.datetime.datetime( ...
        int32(yearValue), int32(monthValue), int32(dayValue), ...
        int32(hourValue), int32(minuteValue), int32(wholeSecond), ...
        int32(microsecond), pyargs("tzinfo", getPythonTimeZone(value.TimeZone)));
end

function timeZone = getPythonTimeZone(timeZoneName)
%getPythonTimeZone - Build a Python tzinfo for a MATLAB time zone name

    timeZoneName = string(timeZoneName);
    if timeZoneName == "UTC"
        timeZone = py.datetime.timezone(py.datetime.timedelta(int32(0)));
    else
        zoneinfo = py.importlib.import_module("zoneinfo");
        timeZone = zoneinfo.ZoneInfo(char(timeZoneName));
    end
end

function pyValue = logicalToPython(value)
%logicalToPython - Convert a logical scalar to bool, an array to a list

    if isscalar(value)
        pyValue = py.bool(value);
        return
    end

    pyValue = py.list();
    for i = 1:numel(value)
        pyValue.append(py.bool(value(i)));
    end
end

function pyValue = numericToPython(value)
%numericToPython - Pass a numeric scalar through, convert an array to a list

    if isscalar(value)
        pyValue = value;
        return
    end

    pyValue = py.list();
    for i = 1:numel(value)
        pyValue.append(value(i));
    end
end
