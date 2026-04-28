function requiredProps = getRequiredProperties(typeName)
% getRequiredProperties - Get required property names for an NWB type
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
%     requiredProps - Cell array of required property name strings.
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
        fullClassName = string( getFullTypeName(shortName) );
        requiredProps = schemes.internal.getRequiredPropsForClass(fullClassName);
        requiredPropsCache(shortName) = {requiredProps};
    else
        requiredProps = requiredPropsCache{shortName};
    end
end
