function [neuroDataTypes, descriptions] = getTypesForModule(moduleName)
%getTypesForModule - Retrieve neurodata types and descriptions for a module
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
%   See also: nansen.module.nwb.internal.schemautil.getNWBModules

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
    if strcmp(moduleName, nansen.module.nwb.internal.getUnsetPlaceholders().NwbModule)
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

    % A module defines types under both keys. The image module, for one,
    % defines ImageSeries as a group and GrayscaleImage as a dataset, and
    % reading only the groups would leave every dataset type out of the
    % listing without saying so.
    moduleSchema = D{moduleName};
    [groupTypes, groupDescriptions] = readDefinedTypes(moduleSchema, "groups");
    [datasetTypes, datasetDescriptions] = readDefinedTypes(moduleSchema, "datasets");

    neuroDataTypes = [groupTypes, datasetTypes];
    descriptions = [groupDescriptions, datasetDescriptions];

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

function [typeNames, descriptions] = readDefinedTypes(moduleSchema, schemaKey)
%readDefinedTypes - Read the types one schema key defines
%
%   An entry without a neurodata_type_def extends or includes another
%   type rather than defining one, so it names no type to list.

    typeNames = strings(1, 0);
    descriptions = strings(1, 0);

    if ~isKey(moduleSchema, schemaKey)
        return
    end

    definitions = moduleSchema{schemaKey};
    for i = 1:numel(definitions)
        definition = definitions{i};
        if ~isKey(definition, "neurodata_type_def")
            continue
        end

        typeNames(end+1) = definition{"neurodata_type_def"}; %#ok<AGROW>

        if isKey(definition, "doc")
            descriptions(end+1) = definition{"doc"}; %#ok<AGROW>
        else
            descriptions(end+1) = ""; %#ok<AGROW>
        end
    end
end
