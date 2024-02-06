function [neuroDataTypes, descriptions] = getTypesForModule(moduleName)

    import nansen.module.nwb.internal.schemautil.convertCachedMapsToDictionary

    persistent D typeMap descriptionMap
    if isempty(D)
        D = convertCachedMapsToDictionary();
        typeMap = dictionary;
        descriptionMap = dictionary;
    end

    if ~strncmp(moduleName, 'nwb.', 4)
        moduleName = strcat('nwb.', moduleName);
    end
   
    if typeMap.isConfigured()
        if typeMap.isKey(moduleName)
            neuroDataTypes = typeMap{moduleName};
            if nargout == 2
                descriptions = descriptionMap{moduleName};
            end
            return
        end
    end

    groups = D{moduleName}{"groups"};

    numNeuroDataTypes = numel(groups);
    neuroDataTypes = repmat("", 1, numNeuroDataTypes);
    descriptions = repmat("", 1, numNeuroDataTypes);

    for i = 1:numNeuroDataTypes
        neuroDataTypes(i) = groups{i}{"neurodata_type_def"};
        descriptions(i) = groups{i}{"doc"};
    end

    % Filter out deprecated fields. Todo: Make option to allow deprecated?
    isDeprecated = startsWith(descriptions, 'DEPRECATED');
    neuroDataTypes(isDeprecated) = [];
    descriptions(isDeprecated) = [];

    typeMap(moduleName) = {neuroDataTypes};
    descriptionMap(moduleName) = {descriptions};

    if nargout == 1
        clear descriptions
    end
end
