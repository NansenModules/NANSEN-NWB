function qualifiedName = getMatNwbTypeName(namespace, typeName)
% getMatNwbTypeName - Get fully qualified matnwb type name
%
%   qualifiedName = getMatNwbTypeName(namespace, typeName) returns the
%   fully qualified matnwb type name for the given namespace and class name.
%
%   Example:
%       getMatNwbTypeName('core', 'TimeSeries')
%       returns 'matnwb.types.core.TimeSeries'

    qualifiedName = sprintf('matnwb.types.%s.%s', namespace, typeName);
end
