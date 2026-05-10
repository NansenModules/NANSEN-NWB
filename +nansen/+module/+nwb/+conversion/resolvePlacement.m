function placement = resolvePlacement(basePlacement, result, descriptor)
%resolvePlacement Apply a converter PlacementOverride when policy allows it.

    arguments
        basePlacement (1,1) struct
        result
        descriptor (1,1) nansen.module.nwb.conversion.NwbConverterDescriptor
    end

    placement = basePlacement;
    if ~isstruct(result) || ~isfield(result, "PlacementOverride") || ...
            isempty(result.PlacementOverride)
        return
    end

    if ~descriptor.AllowsPlacementOverride
        return
    end

    placementOverride = result.PlacementOverride;
    if ~isstruct(placementOverride) || ~isscalar(placementOverride)
        error("NansenNwb:InvalidPlacementOverride", ...
            "PlacementOverride must be a scalar struct.")
    end

    allowedFields = ["Name", "PrimaryGroup", "NwbModule"];
    overrideFields = string(fieldnames(placementOverride));
    unknownFields = setdiff(overrideFields, allowedFields);
    if ~isempty(unknownFields)
        error("NansenNwb:InvalidPlacementOverride", ...
            "Unsupported PlacementOverride fields: %s.", ...
            strjoin(unknownFields, ", "))
    end

    for i = 1:numel(overrideFields)
        fieldName = char(overrideFields(i));
        if ~isempty(placementOverride.(fieldName))
            placement.(fieldName) = placementOverride.(fieldName);
        end
    end
end
