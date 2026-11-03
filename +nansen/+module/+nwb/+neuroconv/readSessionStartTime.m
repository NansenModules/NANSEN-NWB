function sessionStartTime = readSessionStartTime(interfaceClassName, sourceArg, options)
%readSessionStartTime - Ask a NeuroConv interface when its recording started
%   T = readSessionStartTime(interfaceClassName,sourceArg) instantiates
%   the named NeuroConv data interface on sourceArg, as runConversion
%   does, and returns the session start time its get_metadata() reports
%   from the recording's header, as a datetime. The datetime carries the
%   UTC offset the header wrote, or no zone when the header wrote none.
%
%   T is empty when the interface reports no start time.
%
%   T = readSessionStartTime(...,PythonExecutable=EXE) loads Python from
%   EXE, when Python has not been loaded into this MATLAB session yet.
%
%   A session folder usually names a date but not a time of day, while
%   the recording software wrote both into the file. This is how the
%   session layer gets the time without the format being known to it.
%
%   Errors:
%     nansen:nwb:neuroconvFailed - the interface could not be created or
%                     asked. The Python error is attached as the cause.
%
%   Example: Read the start of an ABF session
%       t = nansen.module.nwb.neuroconv.readSessionStartTime( ...
%           "AbfInterface", struct("file_paths", {{"/data/170518_1a.ABF"}}));
%
%   See also nansen.module.nwb.neuroconv.runConversion,
%   nansen.module.nwb.neuroconv.fromPythonDatetime

    arguments
        interfaceClassName (1,1) string
        sourceArg (1,1) struct
        options.PythonExecutable (1,1) string = ""
        options.ExecutionMode (1,1) string ...
            {mustBeMember(options.ExecutionMode, ["InProcess", "OutOfProcess"])} = "OutOfProcess"
    end

    import nansen.module.nwb.neuroconv.internal.configurePython
    import nansen.module.nwb.neuroconv.internal.createInterface

    configurePython(options.PythonExecutable, options.ExecutionMode)

    try
        interface = createInterface(interfaceClassName, sourceArg);
        metadata = interface.get_metadata();

        sessionStartTime = datetime.empty;
        if isequal(metadata.get("NWBFile"), py.None)
            return
        end
        fileMetadata = metadata{"NWBFile"};
        if isequal(fileMetadata.get("session_start_time"), py.None)
            return
        end
        sessionStartTime = startTimeFromPython(fileMetadata{"session_start_time"});
    catch cause
        exception = MException("nansen:nwb:neuroconvFailed", ...
            ['The NeuroConv interface ''%s'' could not report when its ', ...
             'recording started. The Python error is attached below.'], ...
            interfaceClassName);
        throw(addCause(exception, cause))
    end
end

function value = startTimeFromPython(pythonValue)
%startTimeFromPython - Read the start time whether it is a datetime or text
%
%   NeuroConv's metadata dictionaries hold a datetime object or its ISO
%   8601 text, depending on the interface and on whether the value has
%   been through its JSON schema.

    if isa(pythonValue, "py.datetime.datetime")
        value = nansen.module.nwb.neuroconv.fromPythonDatetime(pythonValue);
        return
    end

    text = string(char(pythonValue));
    value = nansen.module.nwb.internal.iso8601ToDatetime(text);
    if isempty(value)
        value = datetime(text);
    end

    % An ABF 1 header holds the time of day but no date, and NeuroConv
    % then reports the time on 1900-01-01. That is not when the recording
    % started, so it is not returned as if it were.
    if ~isempty(value) && year(value) < 1970
        warning("nansen:nwb:undatedSessionStartTime", ...
            ['The recording''s header gives a time of day, %s, but no date. ', ...
             'Supply the session start time another way.'], string(value, "HH:mm:ss"))
        value = datetime.empty;
    end
end
