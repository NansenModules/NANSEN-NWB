function offsetSeconds = alignToStartTime(interface, fileStartTime)
%alignToStartTime - Shift a NeuroConv interface's times to count from a file's start
%   offsetSeconds = alignToStartTime(interface,fileStartTime) reads the
%   start of the recording that the NeuroConv data interface reports as
%   NWBFile.session_start_time in get_metadata, and shifts the
%   interface's data by the seconds from fileStartTime to it with
%   set_aligned_starting_time. It returns the shift, or 0 when it made
%   none.
%
%   An interface times its data from the start of its own recording, and
%   appending drops that start in favour of the file's, so without the
%   shift its data would sit early on the file's timeline.
%
%   The two starts are compared in one time zone. A start written without
%   a UTC offset is wall-clock time and is taken in the other start's
%   zone; a start with one is converted to the file's zone. A start with
%   no date, as an ABF 1 header gives and NeuroConv reports on
%   1900-01-01, is taken as that time of day on the file's date.
%
%   Warnings:
%     nansen:nwb:unalignedRecording - the start could not be read, or the
%                     interface cannot shift its data; it is left as is.
%
%   Errors:
%     nansen:nwb:recordingBeforeSessionStart - the recording started
%                     before fileStartTime.
%
%   See also nansen.module.nwb.neuroconv.runConversion

    arguments
        interface
        fileStartTime (1,1) datetime
    end

    offsetSeconds = 0;

    nwbFileSection = interface.get_metadata().get("NWBFile");
    if isequal(nwbFileSection, py.None)
        return
    end
    pythonStart = nwbFileSection.get("session_start_time");
    if isequal(pythonStart, py.None)
        return
    end

    if isa(pythonStart, "py.str")
        startText = string(pythonStart);
    else
        startText = string(pythonStart.isoformat());
    end
    interfaceStart = nansen.module.nwb.internal.iso8601ToDatetime(startText);
    if isempty(interfaceStart)
        warning("nansen:nwb:unalignedRecording", ...
            ['The interface reports its start as ''%s'', which could not be ', ...
             'read, so its data are not aligned to the file''s start.'], startText)
        return
    end

    % An undated start is the time of day it was written in, put on the
    % file's date before any zone conversion, which on 1900-01-01 would
    % use that year's rules.
    if year(interfaceStart) < 1970
        writtenZone = interfaceStart.TimeZone;
        fileDate = datetime(year(fileStartTime), month(fileStartTime), day(fileStartTime));
        interfaceStart = fileDate + timeofday(interfaceStart);
        interfaceStart.TimeZone = writtenZone;
    end

    if fileStartTime.TimeZone == ""
        interfaceStart.TimeZone = "";
    else
        interfaceStart.TimeZone = fileStartTime.TimeZone;
    end

    offsetSeconds = seconds(interfaceStart - fileStartTime);
    if offsetSeconds == 0
        return
    end
    if offsetSeconds < 0
        error("nansen:nwb:recordingBeforeSessionStart", ...
            ['The recording started at %s, before the file''s ', ...
             'session_start_time %s. Set the session''s date and time to ', ...
             'when the recording started, or earlier.'], ...
            string(interfaceStart), string(fileStartTime))
    end
    if ~py.hasattr(interface, "set_aligned_starting_time")
        warning("nansen:nwb:unalignedRecording", ...
            ['The interface cannot shift its timestamps, so its data start ', ...
             '%g s early on the file''s timeline.'], offsetSeconds)
        offsetSeconds = 0;
        return
    end

    interface.set_aligned_starting_time(offsetSeconds);
end
