function [nwbType, name] = structToNwbType(metadataStruct, nwbClassName)

    name = metadataStruct.name;
    metadataStruct = rmfield(metadataStruct, 'name');

    nvPairs = namedargs2cell(metadataStruct);
    nwbType = feval(nwbClassName, nvPairs{:});
    if nargout == 1
        clear name
    end
end