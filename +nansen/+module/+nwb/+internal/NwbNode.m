classdef NwbNode < handle
% NwbNode - Represent type information for a node in the NWB file/data hierarchy 
%
%   Note: This is a utility class which is used for convenience in the gui
%   components, and it is not an accurate re-representation of the NWB
%   datatypes / schemas

    properties (SetAccess = immutable)
        DefiningType (1,1) string = missing
        PropertyName (1,1) string
        PropertyType (1,1) string
        PropertyTypeFullName (1,1) string = missing
    end

    methods
        function obj = NwbNode(propertyName, propertyType, definingType)
            arguments
                propertyName (1,1) string
                propertyType (1,1) string
                definingType (1,1) string = missing
            end
            
            import nansen.module.nwb.internal.lookup.getFullTypeName

            propertyType = utility.string.getSimpleClassName(propertyType);

            obj.PropertyName = propertyName;
            obj.PropertyType = propertyType;
            obj.DefiningType = definingType;
                
            obj.PropertyTypeFullName = getFullTypeName(obj.PropertyType);
        end
    end
end
