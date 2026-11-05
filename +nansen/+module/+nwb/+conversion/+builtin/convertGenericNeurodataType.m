function nwbFile = convertGenericNeurodataType(context)
%convertGenericNeurodataType - Build and place a configured neurodata type
%   nwbFile = convertGenericNeurodataType(CONTEXT) creates the neurodata
%   type named by the data item's TargetNWBType from CONTEXT.Data and
%   CONTEXT.Metadata, and places it in the configured group.
%
%   This is the generic path, for data whose conversion is little more
%   than filling in a neurodata type. Data that needs real work should
%   have a converter of its own.
%
%   Errors:
%     nansen:nwb:missingTargetType - the data item names no neurodata
%                     type to build.
%
%   See also nansen.module.nwb.file.convertToNeuroDataType,
%   nansen.module.nwb.conversion.placeNeurodata

    arguments
        context (1,1) struct
    end

    targetType = strtrim(context.DataItem.TargetNWBType);

    % The configurator writes placeholder text such as <select type> into
    % an unset cell, which is not a type name either.
    if ismissing(targetType) || targetType == "" || startsWith(targetType, "<")
        error("nansen:nwb:missingTargetType", ...
            ['''%s'' uses the generic converter but names no neurodata ', ...
             'type. Set TargetNWBType on the data item, or choose a ', ...
             'converter that produces a specific type.'], ...
            context.DataItem.VariableName)
    end

    neuroData = nansen.module.nwb.file.convertToNeuroDataType( ...
        context.Metadata, context.Data, targetType);

    defaultName = context.DataItem.NWBVariableName;
    if strlength(defaultName) == 0
        defaultName = context.DataItem.VariableName;
    end

    nwbFile = nansen.module.nwb.conversion.placeNeurodata( ...
        context.NwbFile, neuroData, context.Placement, defaultName);
end
