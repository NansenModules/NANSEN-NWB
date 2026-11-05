function startTime = readFileSessionStartTime(filePath)
%readFileSessionStartTime - The session_start_time of an NWB file on disk
%   startTime = readFileSessionStartTime(filePath) returns the
%   session_start_time stored in the NWB file at filePath, as a datetime
%   with the file's UTC offset as its time zone.
%
%   It returns an empty datetime and warns when the file holds no start
%   time it can read. Data NeuroConv then appends keep the times their
%   interface gave them, which can put them at the wrong place on the
%   file's timeline.
%
%   Warnings:
%     nansen:nwb:unalignedRecording - the start time could not be read.
%
%   See also nansen.module.nwb.neuroconv.internal.alignToStartTime

    arguments
        filePath (1,1) string
    end

    startTime = datetime.empty;
    try
        text = string(h5read(filePath, "/session_start_time"));
    catch cause
        warning("nansen:nwb:unalignedRecording", ...
            ['The session_start_time of ''%s'' could not be read, so the ', ...
             'data appended to it are not aligned to it: %s'], filePath, cause.message)
        return
    end

    startTime = nansen.module.nwb.internal.iso8601ToDatetime(text(1));
    if isempty(startTime)
        warning("nansen:nwb:unalignedRecording", ...
            ['The session_start_time of ''%s'' is ''%s'', which could not be ', ...
             'read, so the data appended to it are not aligned to it.'], filePath, text(1))
    end
end
