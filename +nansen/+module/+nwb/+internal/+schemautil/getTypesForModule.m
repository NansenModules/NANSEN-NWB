function [neuroDataTypes, descriptions] = getTypesForModule(moduleName)
% getTypesForModule - Retrieve neurodata types and descriptions for a given module.
%
% Syntax:
%   [neuroDataTypes, descriptions] = getTypesForModule(moduleName)
%   This function retrieves the neurodata types and their corresponding
%   descriptions for a specified module name. If the module name does not
%   start with 'nwb.', it is prefixed accordingly.
%
% Input Arguments: 
%   moduleName - A string representing the name of the module for which
%                neurodata types and descriptions are to be retrieved.
%
% Output Arguments:
%   neuroDataTypes - A cell array of strings containing the neurodata 
%                    types associated with the specified module.
%   descriptions - A cell array of strings containing the descriptions 
%                  of each neurodata type.

% Todo: Also detect dataset classes.

    import nansen.module.nwb.internal.schemautil.convertCachedMapsToDictionary

    persistent D typeMap descriptionMap
    if isempty(D)
        D = convertCachedMapsToDictionary();
        typeMap = dictionary;
        descriptionMap = dictionary;
    end

    if strcmp(moduleName, '<Select an NWB module>')
        neuroDataTypes = string.empty;
        descriptions = string.empty;
        return
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

    assert(isKey(D, moduleName), ...
        'NANSEN_NWB:Internal:InvalidModuleName', ...
        'Internal error: Please report.')
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

