function qualifiedName = getMatNwbTypeName(namespace, typeName)
% getMatNwbTypeName - Get fully qualified NWB type name
%
%   qualifiedName = getMatNwbTypeName(namespace, typeName) returns the
%   fully qualified NWB type name for the given namespace and class name.
%
%   Example:
%       getMatNwbTypeName('core', 'TimeSeries')
%       returns 'types.core.TimeSeries'

    qualifiedName = sprintf('types.%s.%s', namespace, typeName);
end
