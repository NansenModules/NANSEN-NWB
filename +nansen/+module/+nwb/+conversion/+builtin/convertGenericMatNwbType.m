function nwbFile = convertGenericMatNwbType(context)
%convertGenericMatNwbType Create and place a configured MatNWB type.

    arguments
        context (1,1) struct
    end

    targetType = string(context.DataItem.TargetNwbType);
    if targetType == "" || ismissing(targetType) || startsWith(strtrim(targetType), "<")
        error("NansenNwb:MissingTargetNwbType", ...
            "GenericMatNwbType requires DataItem.TargetNwbType.")
    end

    neuroData = nansen.module.nwb.file.convertToDataType( ...
        context.Metadata, context.Data, targetType);

    defaultName = context.DataItem.NWBVariableName;
    if strlength(defaultName) == 0
        defaultName = context.DataItem.VariableName;
    end

    nwbFile = nansen.module.nwb.conversion.placeNeurodata( ...
        context.NwbFile, neuroData, context.Placement, defaultName);
end
