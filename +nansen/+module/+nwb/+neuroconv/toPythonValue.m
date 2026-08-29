function pythonValue = toPythonValue(value)
%toPythonValue - Convert a MATLAB value to its Python counterpart
%   pythonValue = toPythonValue(VALUE) converts VALUE to the Python
%   object NeuroConv expects in a metadata dictionary. Structs become
%   dicts, cell arrays and non-scalar arrays become lists, and scalars
%   become the matching Python scalar.
%
%   A datetime must carry a time zone. NWB timestamps are absolute, and
%   a naive Python datetime would be read as local to whoever opens the
%   file rather than to the recording.
%
%   Errors:
%     nansen:nwb:missingTimeZone - a datetime has no time zone.
%
%   Example: Convert session metadata for NeuroConv
%       metadata = struct("NWBFile", struct("session_id", "ses-01"));
%       pythonMetadata = nansen.module.nwb.neuroconv.toPythonValue(metadata);
%
%   See also nansen.module.nwb.neuroconv.runConversion, pyargs

    if isa(value, "py.object")
        pythonValue = value;
    elseif isstruct(value)
        pythonValue = structToDict(value);
    elseif iscell(value)
        pythonValue = cellToList(value);
    elseif isstring(value)
        pythonValue = stringToPython(value);
    elseif ischar(value)
        pythonValue = char(value);
    elseif isdatetime(value)
        pythonValue = datetimeToPython(value);
    elseif isduration(value)
        pythonValue = seconds(value);
    elseif islogical(value)
        pythonValue = logicalToPython(value);
    elseif isnumeric(value)
        pythonValue = numericToPython(value);
    else
        pythonValue = value;
    end
end

function pythonDict = structToDict(S)
%structToDict - Convert a struct to a dict, or a struct array to a list

    if ~isscalar(S)
        pythonDict = py.list();
        for i = 1:numel(S)
            pythonDict.append(structToDict(S(i)));
        end
        return
    end

    pythonDict = py.dict();
    fieldNames = fieldnames(S);
    for i = 1:numel(fieldNames)
        pythonDict{fieldNames{i}} = ...
            nansen.module.nwb.neuroconv.toPythonValue(S.(fieldNames{i}));
    end
end

function pythonList = cellToList(C)
%cellToList - Convert a cell array to a list

    pythonList = py.list();
    for i = 1:numel(C)
        pythonList.append(nansen.module.nwb.neuroconv.toPythonValue(C{i}));
    end
end

function pythonValue = stringToPython(value)
%stringToPython - Convert a string scalar to str, an array to a list

    if isscalar(value)
        pythonValue = char(value);
        return
    end

    pythonValue = py.list();
    for i = 1:numel(value)
        pythonValue.append(char(value(i)));
    end
end

function pythonValue = datetimeToPython(value)
%datetimeToPython - Convert a zoned datetime to datetime.datetime

    if ~isscalar(value)
        pythonValue = py.list();
        for i = 1:numel(value)
            pythonValue.append(datetimeToPython(value(i)));
        end
        return
    end

    if value.TimeZone == ""
        error("nansen:nwb:missingTimeZone", ...
            ['The datetime %s has no time zone. NWB timestamps are ', ...
             'absolute, so a time without a zone would be read as local ', ...
             'to whoever opens the file. Set the TimeZone property before ', ...
             'converting.'], string(value))
    end

    [yearValue, monthValue, dayValue] = ymd(value);
    [hourValue, minuteValue, secondValue] = hms(value);
    wholeSecond = floor(secondValue);
    microsecond = round((secondValue - wholeSecond) * 1e6);

    pythonValue = py.datetime.datetime( ...
        int32(yearValue), int32(monthValue), int32(dayValue), ...
        int32(hourValue), int32(minuteValue), int32(wholeSecond), ...
        int32(microsecond), pyargs("tzinfo", toPythonTimeZone(value.TimeZone)));
end

function pythonTimeZone = toPythonTimeZone(timeZoneName)
%toPythonTimeZone - Build a Python tzinfo for a MATLAB time zone name

    timeZoneName = string(timeZoneName);
    if timeZoneName == "UTC"
        pythonTimeZone = py.datetime.timezone(py.datetime.timedelta(int32(0)));
    else
        zoneinfo = py.importlib.import_module("zoneinfo");
        pythonTimeZone = zoneinfo.ZoneInfo(char(timeZoneName));
    end
end

function pythonValue = logicalToPython(value)
%logicalToPython - Convert a logical scalar to bool, an array to a list

    if isscalar(value)
        pythonValue = py.bool(value);
        return
    end

    pythonValue = py.list();
    for i = 1:numel(value)
        pythonValue.append(py.bool(value(i)));
    end
end

function pythonValue = numericToPython(value)
%numericToPython - Pass a numeric scalar through, convert an array to a list

    if isscalar(value)
        pythonValue = value;
        return
    end

    pythonValue = py.list();
    for i = 1:numel(value)
        pythonValue.append(value(i));
    end
end
