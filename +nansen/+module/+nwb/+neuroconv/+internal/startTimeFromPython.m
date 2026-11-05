function value = startTimeFromPython(pythonValue)
%startTimeFromPython - Read a session start time NeuroConv reported
%   VALUE = startTimeFromPython(pythonValue) returns the session start
%   time in a NeuroConv metadata dictionary as a MATLAB datetime.
%   pythonValue is a Python datetime or its ISO 8601 text: which one
%   depends on the interface and on whether the value has been through
%   NeuroConv's JSON schema. Text that is not ISO 8601 is read by
%   datetime.
%
%   VALUE is empty, with a warning, when the start has no date. An ABF 1
%   header holds the time of day but no date, and NeuroConv reports such
%   a time on 1900-01-01, which is not when the recording started.
%
%   Warnings:
%     nansen:nwb:undatedSessionStartTime - the start time has no date.
%
%   See also nansen.module.nwb.neuroconv.readSessionStartTime,
%   nansen.module.nwb.neuroconv.fromPythonDatetime

    arguments
        pythonValue
    end

    if isa(pythonValue, "py.datetime.datetime")
        value = nansen.module.nwb.neuroconv.fromPythonDatetime(pythonValue);
    else
        text = string(char(pythonValue));
        value = nansen.module.nwb.internal.iso8601ToDatetime(text);
        if isempty(value)
            value = datetime(text);
        end
    end

    if ~isempty(value) && year(value) < 1970
        warning("nansen:nwb:undatedSessionStartTime", ...
            ['The recording''s header gives a time of day, %s, but no date. ', ...
             'Supply the session start time another way.'], string(value, "HH:mm:ss"))
        value = datetime.empty;
    end
end
