function timeArguments = resolveTimeArguments(sampleTimes, metadata)
%resolveTimeArguments - Say when a series' samples were taken
%   timeArguments = resolveTimeArguments(sampleTimes) returns the
%   name-value arguments that tell a TimeSeries when its samples were
%   taken, given the sample times in seconds.
%
%   A regularly sampled series is described by its start time and rate,
%   which is both far smaller than one timestamp per sample and what a
%   reader of the file expects. NWB Inspector reports a regular series
%   carrying timestamps as a best-practice violation. An irregular
%   series keeps its timestamps.
%
%   timeArguments = resolveTimeArguments(sampleTimes,METADATA) also takes
%   the item's metadata into account. When it already says when the
%   samples were taken, no arguments are returned and the metadata is
%   left to speak for itself.
%
%   Example: Build a TimeSeries from a timetable
%       sampleTimes = seconds(data.Properties.RowTimes);
%       timeArguments = nansen.module.nwb.internal.resolveTimeArguments(sampleTimes);
%       series = types.core.TimeSeries('data', values, timeArguments{:});
%
%   See also nansen.module.nwb.file.convertToNeuroDataType,
%   nansen.module.nwb.conversion.general.convertTimetable

    arguments
        sampleTimes (:,1) double
        metadata (1,1) struct = struct()
    end

    % Metadata that already says when the samples were taken wins: the
    % user knows something about the recording the sample times do not
    % carry.
    if hasTimeReference(metadata)
        timeArguments = {};
        return
    end

    if isRegularlySampled(sampleTimes)
        timeArguments = {'starting_time', sampleTimes(1), ...
                         'starting_time_rate', 1 / mean(diff(sampleTimes))};
    else
        timeArguments = {'timestamps', sampleTimes};
    end
end

function tf = isRegularlySampled(sampleTimes)
%isRegularlySampled - True when the samples are evenly spaced
%
%   Sample times carry rounding, so the intervals are compared against
%   their mean rather than to each other exactly. Two samples describe
%   one interval, which is not enough to call a rate.

    if numel(sampleTimes) < 3
        tf = false;
        return
    end

    intervals = diff(sampleTimes);
    meanInterval = mean(intervals);

    if meanInterval <= 0
        tf = false;
        return
    end

    tf = max(abs(intervals - meanInterval)) <= 1e-9 * meanInterval;
end

function tf = hasTimeReference(metadata)
%hasTimeReference - True if the metadata says when the samples were taken

    hasTimestamps = isfield(metadata, 'timestamps') && ~isempty(metadata.timestamps);
    hasStartingTime = isfield(metadata, 'starting_time') && ...
        isfield(metadata, 'starting_time_rate');

    tf = hasTimestamps || hasStartingTime;
end
