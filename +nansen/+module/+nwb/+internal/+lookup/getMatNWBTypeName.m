function qualifiedName = getMatNWBTypeName(namespace, typeName)
%getMatNWBTypeName - Get a fully qualified matnwb namespace or type name
%
%   This is the single place where matnwb's type package prefix is spelled
%   out, so that a change to matnwb's packaging only has to be made here.
%
%   Syntax:
%     qualifiedName = getMatNWBTypeName(namespace) returns the fully
%       qualified name of a matnwb type namespace, which is also the prefix
%       shared by every type it contains.
%
%     qualifiedName = getMatNWBTypeName(namespace, typeName) returns the
%       fully qualified name of a single type within that namespace.
%
%   Input Arguments:
%     namespace - NWB namespace, e.g. "core" or "hdmf_common". Type: string
%     typeName  - Name of a type within the namespace. Type: string
%
%   Output Arguments:
%     qualifiedName - Fully qualified name. Type: char
%
%   Example:
%     getMatNWBTypeName('core', 'TimeSeries')  % 'types.core.TimeSeries'
%     getMatNWBTypeName('core')                % 'types.core'

    arguments
        namespace (1,1) string
        typeName (1,1) string = missing
    end

    if ismissing(typeName)
        qualifiedName = sprintf('types.%s', namespace);
    else
        qualifiedName = sprintf('types.%s.%s', namespace, typeName);
    end
end
