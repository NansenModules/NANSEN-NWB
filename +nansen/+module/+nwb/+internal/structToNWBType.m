function [nwbType, name] = structToNWBType(metadataStruct, nwbClassName)
%structToNWBType - Build a neurodata type instance from a metadata struct
%   nwbType = structToNWBType(metadataStruct,nwbClassName) constructs the
%   named neurodata type, passing the fields of the struct as its
%   name-value arguments.
%
%   [nwbType,NAME] = structToNWBType(...) also returns the instance name.
%   The name field is taken out of the struct before construction, since
%   it names the instance rather than setting a property.
%
%   See also nansen.module.nwb.internal.getMetadataInstance

    name = metadataStruct.name;
    metadataStruct = rmfield(metadataStruct, 'name');

    nvPairs = namedargs2cell(metadataStruct);
    nwbType = feval(nwbClassName, nvPairs{:});
    if nargout == 1
        clear name
    end
end
