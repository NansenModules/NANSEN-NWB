function placement = resolvePlacement(basePlacement, result, descriptor)
%resolvePlacement - Apply a converter placement override when allowed
%   PLACEMENT = resolvePlacement(basePlacement,RESULT,DESCRIPTOR) returns
%   basePlacement, with any PlacementOverride from RESULT applied.
%
%   Placement is decided by the configuration. A converter may override
%   it only when its descriptor sets AllowsPlacementOverride, so a
%   converter cannot quietly move data somewhere the configuration did
%   not ask for. An override from a converter that does not declare the
%   behavior is ignored rather than obeyed.
%
%   Errors:
%     nansen:nwb:invalidPlacementOverride - the override is not a scalar
%                     struct, or names a field that is not part of
%                     placement.
%
%   See also nansen.module.nwb.conversion.placeNeurodata,
%   nansen.module.nwb.conversion.NWBConverterDescriptor

    arguments
        basePlacement (1,1) struct
        result
        descriptor (1,1) nansen.module.nwb.conversion.NWBConverterDescriptor
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
        error("nansen:nwb:invalidPlacementOverride", ...
            ['Converter ''%s'' returned a PlacementOverride that is not a ', ...
             'scalar struct.'], descriptor.Name)
    end

    allowedFields = ["Name", "PrimaryGroup", "NWBModule"];
    overrideFields = string(fieldnames(placementOverride));
    unknownFields = setdiff(overrideFields, allowedFields);
    if ~isempty(unknownFields)
        error("nansen:nwb:invalidPlacementOverride", ...
            ['Converter ''%s'' returned a PlacementOverride naming %s. Only ', ...
             '%s can be overridden.'], descriptor.Name, ...
            strjoin(unknownFields, ", "), strjoin(allowedFields, ", "))
    end

    for i = 1:numel(overrideFields)
        fieldName = overrideFields(i);
        if ~isempty(placementOverride.(fieldName))
            placement.(fieldName) = placementOverride.(fieldName);
        end
    end
end
