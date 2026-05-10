function nwbFile = convertTimetableToTimeSeries(context)
%convertTimetableToTimeSeries Convert timetable variables to TimeSeries.

    arguments
        context (1,1) struct
    end

    data = context.Data;
    if ~istimetable(data)
        error("NansenNwb:InvalidTimetableInput", ...
            "TimetableTimeSeries expects MATLAB timetable data.")
    end

    neurodataType = @types.core.TimeSeries;
    targetType = string(context.DataItem.TargetNwbType);
    if ~isUnsetText(targetType) && targetType ~= "TimeSeries"
        fullTypeName = nansen.module.nwb.internal.lookup.getFullTypeName(targetType);
        neurodataType = str2func(fullTypeName);
    end

    converted = nansen.module.nwb.conversion.general.convertTimetable( ...
        data, ...
        "NeurodataType", neurodataType, ...
        "Metadata", context.Metadata);

    names = string(converted.keys());
    for i = 1:numel(names)
        placement = context.Placement;
        if numel(names) == 1 && strlength(string(context.DataItem.NWBVariableName)) > 0
            placement.Name = string(context.DataItem.NWBVariableName);
        else
            placement.Name = names(i);
        end

        context.NwbFile = nansen.module.nwb.conversion.placeNeurodata( ...
            context.NwbFile, converted.get(char(names(i))), placement, names(i));
    end

    nwbFile = context.NwbFile;
end

function tf = isUnsetText(value)
    value = strtrim(string(value));
    tf = value == "" || ismissing(value) || startsWith(value, "<");
end
