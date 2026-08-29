function [neuroDataTypes, descriptions] = getTypesForModule(moduleName)
% getTypesForModule - Retrieve neurodata types and descriptions for a module
%
%   Syntax:
%     [neuroDataTypes, descriptions] = getTypesForModule(moduleName)
%
%   Input Arguments:
%     moduleName - Name of the NWB module to list types for. The "nwb."
%                  prefix is added when it is not already present.
%                  Type: string
%
%   Output Arguments:
%     neuroDataTypes - Neurodata types defined by the module.
%     descriptions   - Description of each type, in the same order.
%
%   The configuration table seeds its module column with a placeholder, so
%   that value is accepted and answered with empties rather than treated as
%   a module name.
%
%   See also: nansen.module.nwb.internal.schemautil.getNwbModules

    import nansen.module.nwb.internal.schemautil.convertCachedMapsToDictionary

    persistent D typeMap descriptionMap
    if isempty(D)
        D = convertCachedMapsToDictionary();
        typeMap = dictionary;
        descriptionMap = dictionary;
    end

    % The module column of the configuration table starts on a placeholder
    % rather than a real module, and the dropdown offers it as the first
    % entry. Answer with empties instead of looking it up.
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
        'Internal error: "%s" is not a known NWB module. Please report.', moduleName)

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
