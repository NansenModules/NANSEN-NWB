function propertyNames = dataPropertyNamesForType(typeName)
%dataPropertyNamesForType - Data properties of a type and its superclasses
%
%   propertyNames = dataPropertyNamesForType(typeName) returns the
%   properties that carry data rather than metadata for the neurodata type
%   typeName, gathered from the type itself and from every class it
%   inherits from.
%
%   dataPropertyNames lists these per declaring class, so a subclass such
%   as RoiResponseSeries finds only "rois" under its own name and needs the
%   hierarchy walked to also pick up "data" and "timestamps" declared by
%   TimeSeries. getTypeMetadataStruct performs the same resolution through
%   each property's defining class.
%
%   Input Arguments:
%     typeName - Fully qualified NWB type name, e.g.
%                "types.core.TimeSeries". Type: string
%
%   Output Arguments:
%     propertyNames - Names of the data-carrying properties. Type: string
%
%   See also: nansen.module.nwb.internal.dataPropertyNames,
%             nansen.module.nwb.internal.getTypeMetadataStruct

    arguments
        typeName (1,1) string
    end

    dataProperties = nansen.module.nwb.internal.dataPropertyNames();

    classNames = [typeName; string(superclasses(typeName))];
    propertyNames = string.empty(1, 0);

    for i = 1:numel(classNames)
        shortName = utility.string.getSimpleClassName(char(classNames(i)));
        if isfield(dataProperties, shortName)
            propertyNames = [propertyNames, string(dataProperties.(shortName))]; %#ok<AGROW>
        end
    end

    propertyNames = unique(propertyNames);
end
