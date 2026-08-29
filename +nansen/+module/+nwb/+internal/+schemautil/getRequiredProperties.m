function requiredProps = getRequiredProperties(typeName)
%getRequiredProperties - Get required property names for an NWB type
%
%   requiredProps = getRequiredProperties(typeName) returns a cell array of
%   required property names for the given NWB type, based on the NWB schema
%   specification.
%
%   Input Arguments:
%     typeName - Short or fully qualified NWB type name.
%                E.g. 'TimeSeries' or 'types.core.TimeSeries'. Type: string
%
%   Output Arguments:
%     requiredProps - Cell array of required property name strings. Empty
%                     if the type has no required properties.
%
%   Errors:
%     nansen:nwb:unknownNeurodataType - typeName does not name a type in
%                     the loaded NWB namespaces.
%
%   Example:
%     props = nansen.module.nwb.internal.schemautil.getRequiredProperties('TimeSeries')
%     % returns {'data', 'data_unit'}
%
%   See also: schemes.internal.getRequiredPropsForClass

    import nansen.module.nwb.internal.lookup.getFullTypeName

    persistent requiredPropsCache
    if isempty(requiredPropsCache)
        requiredPropsCache = dictionary;
    end

    typeName = string(typeName);
    shortName = string( utility.string.getSimpleClassName(char(typeName)) );

    if ~requiredPropsCache.isConfigured() || ~isKey(requiredPropsCache, shortName)
        % The type lookup is a dictionary, so an unrecognized name surfaces
        % as a missing-key error. Convert only that case, so a genuine
        % failure to build the lookup is not reported as an unknown type.
        try
            fullClassName = string( getFullTypeName(shortName) );
        catch ME
            if strcmp(ME.identifier, 'MATLAB:dictionary:ScalarKeyNotFound')
                error('nansen:nwb:unknownNeurodataType', ...
                    ['Neurodata type "%s" was not found in the NWB schema. ', ...
                     'Provide the name of a type from the loaded NWB namespaces, ', ...
                     'for example "TimeSeries" or "types.core.TimeSeries".'], shortName)
            else
                rethrow(ME)
            end
        end

        requiredProps = schemes.internal.getRequiredPropsForClass(fullClassName);
        requiredPropsCache(shortName) = {requiredProps};
    else
        requiredProps = requiredPropsCache{shortName};
    end
end
