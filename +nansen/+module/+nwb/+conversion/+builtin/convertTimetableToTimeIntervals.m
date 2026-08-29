function nwbFile = convertTimetableToTimeIntervals(context)
%convertTimetableToTimeIntervals - Convert a timetable to trials or epochs
%   nwbFile = convertTimetableToTimeIntervals(CONTEXT) converts the
%   timetable in CONTEXT.Data to a TimeIntervals table, one row per
%   interval, and places it in the configured group.
%
%   The row times give each interval's start. The stop times come from a
%   variable holding either stop times or durations, named in the
%   converter arguments; without one the intervals run to the next row's
%   start, and the last row is dropped because nothing bounds it.
%
%   Every remaining timetable variable becomes a column of the table, so
%   trial type, outcome and the rest travel with the intervals.
%
%   Converter arguments:
%       StopTimeVariable - Variable holding interval stop times
%       DurationVariable - Variable holding interval durations
%       Description      - Description stored on the table
%
%   Errors:
%     nansen:nwb:invalidConverterInput - CONTEXT.Data is not a timetable.
%     nansen:nwb:invalidConverterArg - a named variable is not in the
%                     timetable, or both stop and duration were named.
%
%   See also nansen.module.nwb.conversion.builtin.convertTimetableToTimeSeries,
%   nansen.module.nwb.conversion.placeNeurodata

    arguments
        context (1,1) struct
    end

    import nansen.module.nwb.conversion.getConverterArg

    data = context.Data;
    if ~istimetable(data)
        error("nansen:nwb:invalidConverterInput", ...
            ['The trials converter needs a timetable with one row per ', ...
             'interval, but ''%s'' is %s.'], ...
            context.DataItem.VariableName, class(data))
    end

    args = context.ConverterArgs;
    stopTimeVariable = string(getConverterArg(args, "StopTimeVariable", ""));
    durationVariable = string(getConverterArg(args, "DurationVariable", ""));

    if strlength(stopTimeVariable) > 0 && strlength(durationVariable) > 0
        error("nansen:nwb:invalidConverterArg", ...
            ['Set either StopTimeVariable or DurationVariable for ''%s'', ', ...
             'not both.'], context.DataItem.VariableName)
    end

    [startTimes, stopTimes, data] = intervalBounds( ...
        data, stopTimeVariable, durationVariable, context.DataItem.VariableName);

    description = string(getConverterArg(args, "Description", ...
        "Intervals converted from " + context.DataItem.VariableName));

    columnArguments = remainingColumns(data);

    % A dynamic table checks on construction that every name in colnames
    % has data, so the remaining columns go in the same call rather than
    % being added afterwards.
    timeIntervals = types.core.TimeIntervals( ...
        'description', char(description), ...
        'colnames', cellstr(["start_time", "stop_time", ...
            string(data.Properties.VariableNames)]), ...
        'id', types.hdmf_common.ElementIdentifiers('data', (0:numel(startTimes)-1)'), ...
        'start_time', types.hdmf_common.VectorData( ...
            'data', startTimes, 'description', 'Start time of the interval, in seconds.'), ...
        'stop_time', types.hdmf_common.VectorData( ...
            'data', stopTimes, 'description', 'Stop time of the interval, in seconds.'), ...
        columnArguments{:});

    defaultName = context.DataItem.NWBVariableName;
    if strlength(defaultName) == 0
        defaultName = context.DataItem.VariableName;
    end

    nwbFile = nansen.module.nwb.conversion.placeNeurodata( ...
        context.NwbFile, timeIntervals, context.Placement, defaultName);
end

function [startTimes, stopTimes, data] = intervalBounds(data, stopTimeVariable, durationVariable, variableName)
%intervalBounds - Work out where each interval starts and stops

    startTimes = toSeconds(data.Properties.RowTimes);

    if strlength(stopTimeVariable) > 0
        assertHasVariable(data, stopTimeVariable, variableName)
        stopTimes = toSeconds(data.(stopTimeVariable));
        data = removevars(data, stopTimeVariable);
        return
    end

    if strlength(durationVariable) > 0
        assertHasVariable(data, durationVariable, variableName)
        stopTimes = startTimes + toSeconds(data.(durationVariable));
        data = removevars(data, durationVariable);
        return
    end

    % Without either, one interval runs until the next one starts. The
    % last row has no successor, so nothing says when it ends.
    stopTimes = startTimes(2:end);
    startTimes = startTimes(1:end-1);
    data = data(1:end-1, :);
end

function columnArguments = remainingColumns(data)
%remainingColumns - Carry the other timetable variables into table columns

    variableNames = string(data.Properties.VariableNames);
    columnArguments = cell(1, 2*numel(variableNames));

    for i = 1:numel(variableNames)
        columnData = data.(variableNames(i));

        % A dynamic table column holds one value per row, so text has to
        % be a cell array of char rather than a string array.
        if isstring(columnData) || iscategorical(columnData)
            columnData = cellstr(columnData);
        elseif isduration(columnData)
            columnData = seconds(columnData);
        end

        columnArguments{2*i - 1} = char(variableNames(i));
        columnArguments{2*i} = types.hdmf_common.VectorData( ...
            'data', columnData, ...
            'description', char("Column " + variableNames(i)));
    end
end

function assertHasVariable(data, variableName, itemName)
%assertHasVariable - Require a named variable to exist in the timetable

    if ~any(string(data.Properties.VariableNames) == variableName)
        error("nansen:nwb:invalidConverterArg", ...
            ['''%s'' has no variable named ''%s''. Its variables are: %s.'], ...
            itemName, variableName, ...
            strjoin(string(data.Properties.VariableNames), ", "))
    end
end

function seconds_ = toSeconds(values)
%toSeconds - Express times as seconds, whatever they arrive as

    if isduration(values)
        seconds_ = seconds(values);
    elseif isdatetime(values)
        seconds_ = seconds(values - values(1));
    else
        seconds_ = double(values);
    end

    seconds_ = seconds_(:);
end
