function nwbFile = convertTimetableToTimeSeries(context)
%convertTimetableToTimeSeries - Convert timetable variables to TimeSeries
%   nwbFile = convertTimetableToTimeSeries(CONTEXT) converts each variable
%   of the timetable in CONTEXT.Data to a TimeSeries and places it in the
%   configured group.
%
%   The data item may name a different neurodata type in TargetNWBType,
%   in which case that type is built instead, provided it takes the same
%   data and timestamps.
%
%   When the timetable holds a single variable, the object takes the data
%   item's NWBVariableName. With several variables each object takes its
%   own timetable variable name, since one configured name cannot
%   distinguish them.
%
%   Errors:
%     nansen:nwb:invalidConverterInput - CONTEXT.Data is not a timetable.
%
%   See also nansen.module.nwb.conversion.general.convertTimetable,
%   nansen.module.nwb.conversion.ConverterRegistry

    arguments
        context (1,1) struct
    end

    data = context.Data;
    if ~istimetable(data)
        error("nansen:nwb:invalidConverterInput", ...
            ['The Timetable to TimeSeries converter needs a timetable, but ', ...
             '''%s'' is %s. Choose a converter that accepts %s, or store ', ...
             'the variable as a timetable.'], ...
            context.DataItem.VariableName, class(data), class(data))
    end

    neurodataType = @types.core.TimeSeries;
    targetType = context.DataItem.TargetNWBType;
    if ~isUnsetText(targetType) && targetType ~= "TimeSeries"
        fullTypeName = nansen.module.nwb.internal.lookup.getFullTypeName(targetType);
        neurodataType = str2func(fullTypeName);
    end

    converted = nansen.module.nwb.conversion.general.convertTimetable( ...
        data, ...
        "NeurodataType", neurodataType, ...
        "Metadata", context.Metadata);

    variableNames = string(converted.keys());
    for i = 1:numel(variableNames)
        placement = context.Placement;

        % One configured name cannot name several objects, so it applies
        % only when the timetable produced exactly one.
        if isscalar(variableNames) && strlength(context.DataItem.NWBVariableName) > 0
            placement.Name = context.DataItem.NWBVariableName;
        else
            placement.Name = variableNames(i);
        end

        context.NwbFile = nansen.module.nwb.conversion.placeNeurodata( ...
            context.NwbFile, converted.get(char(variableNames(i))), ...
            placement, variableNames(i));
    end

    nwbFile = context.NwbFile;
end

function tf = isUnsetText(value)
%isUnsetText - True for blank text or a configurator placeholder

    value = strtrim(string(value));
    tf = ismissing(value) || value == "" || startsWith(value, "<");
end
