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
        sessionStartTime = nansen.module.nwb.neuroconv.internal.startTimeFromPython( ...
            fileMetadata{"session_start_time"});
    catch cause
        exception = MException("nansen:nwb:neuroconvFailed", ...
            ['The NeuroConv interface ''%s'' could not report when its ', ...
             'recording started. The Python error is attached below.'], ...
            interfaceClassName);
        throw(addCause(exception, cause))
    end
end
