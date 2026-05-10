function runConversion(interfaceClassName, sourceArg, nwbFilePath, metadata, options)
% runConversion - Run a NeuroConv DataInterface through MATLAB py.*.
%
%   runConversion(interfaceClassName, sourceArg, nwbFilePath, metadata)
%   imports a NeuroConv DataInterface from neuroconv.datainterfaces,
%   instantiates it with sourceArg name-value pairs, and calls
%   run_conversion with metadata.
%
%   sourceArg is a scalar struct with constructor arguments, for example:
%       struct("folder_path", "/path/to/images")
%
%   metadata is a MATLAB struct that mirrors NeuroConv's metadata dict.

    arguments
        interfaceClassName (1,1) string
        sourceArg (1,1) struct
        nwbFilePath (1,1) string
        metadata (1,1) struct = struct()
        options.PythonExecutable (1,1) string = ""
        options.ExecutionMode (1,1) string {mustBeMember(options.ExecutionMode, ["InProcess", "OutOfProcess"])} = "OutOfProcess"
        options.Overwrite (1,1) logical = false
        options.AppendOnDiskNwbFile (1,1) logical = false
        options.RunConversionArgs (1,1) struct = struct()
    end

    if options.Overwrite && options.AppendOnDiskNwbFile
        error("NansenNwb:InvalidNeuroconvWriteMode", ...
            "NeuroConv run_conversion can overwrite or append to an NWB file, but not both.")
    end

    configurePython(options.PythonExecutable, options.ExecutionMode)

    try
        dataInterfaces = py.importlib.import_module("neuroconv.datainterfaces");
        interfaceClass = py.getattr(dataInterfaces, char(interfaceClassName));

        sourceNvPairs = structToPyargs(sourceArg);
        interface = interfaceClass(pyargs(sourceNvPairs{:}));

        pyMetadata = matlabToPython(metadata);
        runConversionNvPairs = { ...
            "nwbfile_path", char(nwbFilePath), ...
            "metadata", pyMetadata};

        if options.Overwrite
            runConversionNvPairs = [runConversionNvPairs, {"overwrite", py.bool(true)}]; %#ok<AGROW>
        elseif options.AppendOnDiskNwbFile
            runConversionNvPairs = [runConversionNvPairs, {"append_on_disk_nwbfile", py.bool(true)}]; %#ok<AGROW>
        end

        extraRunConversionNvPairs = structToPyargs(options.RunConversionArgs);
        runConversionNvPairs = [runConversionNvPairs, extraRunConversionNvPairs];
        interface.run_conversion(pyargs(runConversionNvPairs{:}));
    catch exception
        error("NansenNwb:NeuroconvConversionFailed", ...
            "NeuroConv conversion failed for %s:\n%s", ...
            interfaceClassName, exception.message)
    end
end

function configurePython(pythonExecutable, executionMode)
    if strlength(pythonExecutable) == 0
        return
    end

    env = pyenv();
    if string(env.Status) == "NotLoaded"
        pyenv("Version", pythonExecutable, "ExecutionMode", executionMode);
        return
    end

    if string(env.Executable) ~= pythonExecutable
        error("NansenNwb:PythonAlreadyLoaded", ...
            "Python is already loaded from %s. Restart MATLAB to use %s.", ...
            string(env.Executable), pythonExecutable)
    end
end

function nvPairs = structToPyargs(S)
    names = fieldnames(S);
    nvPairs = cell(1, 2*numel(names));

    for i = 1:numel(names)
        nvPairs{2*i - 1} = names{i};
        nvPairs{2*i} = matlabToPython(S.(names{i}));
    end
end

function pyValue = matlabToPython(value)
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
    if ~isscalar(S)
        pyDict = py.list();
        for i = 1:numel(S)
            pyDict.append(structToPyDict(S(i)));
        end
        return
    end

    pyDict = py.dict();
    names = fieldnames(S);
    for i = 1:numel(names)
        pyDict{names{i}} = matlabToPython(S.(names{i}));
    end
end

function pyList = cellToPyList(C)
    pyList = py.list();
    for i = 1:numel(C)
        pyList.append(matlabToPython(C{i}));
    end
end

function pyValue = stringToPython(value)
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
    if ~isscalar(value)
        pyValue = py.list();
        for i = 1:numel(value)
            pyValue.append(datetimeToPython(value(i)));
        end
        return
    end

    if string(value.TimeZone) == ""
        error("NansenNwb:TimezoneRequired", ...
            "Datetime metadata passed to NeuroConv must include a timezone.")
    end

    [yearValue, monthValue, dayValue] = ymd(value);
    [hourValue, minuteValue, secondValue] = hms(value);
    integerSecond = floor(secondValue);
    microSecond = round((secondValue - integerSecond) * 1e6);

    timezone = getPythonTimezone(value.TimeZone);
    pyValue = py.datetime.datetime( ...
        int32(yearValue), int32(monthValue), int32(dayValue), ...
        int32(hourValue), int32(minuteValue), int32(integerSecond), ...
        int32(microSecond), pyargs("tzinfo", timezone));
end

function timezone = getPythonTimezone(timezoneName)
    timezoneName = string(timezoneName);
    if timezoneName == "UTC"
        timezone = py.datetime.timezone(py.datetime.timedelta(int32(0)));
    else
        zoneinfo = py.importlib.import_module("zoneinfo");
        timezone = zoneinfo.ZoneInfo(char(timezoneName));
    end
end

function pyValue = logicalToPython(value)
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
    if isscalar(value)
        pyValue = value;
        return
    end

    pyValue = py.list();
    for i = 1:numel(value)
        pyValue.append(value(i));
    end
end
