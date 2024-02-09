function S = appendDropdownOptions(S, propertyName, propertyType)

    import nansen.module.nwb.internal.getMetadataInstances
    import nansen.module.nwb.internal.createNewNwbInstance

    % Note: propertyType comes without namespace name, i.e types.core
    fullLinkedTypeName = nansen.module.nwb.internal.lookup.getFullTypeName(propertyType);
    
    % Load existing metadata instances for this neurodata type
    metadataInstances = nansen.module.nwb.internal.getMetadataInstances(fullLinkedTypeName);
    metadataInstances = cellstr(metadataInstances);
    
    % Specify custom configuration for a dropdown control.
    dropdownConfig = struct(...
        'AllowNoSelection', true, ...
        'CreateNewItemFcn', @(item, type) nansen.module.nwb.internal.createNewNwbInstance(item, fullLinkedTypeName), ...
        'ItemName', propertyType );

    % Prepend the dropdown configuration to the list of instances. 
    % The structeditor will expect this config as the first cell of the
    % cell array.
    metadataInstances = [{dropdownConfig}, metadataInstances]; %#ok<AGROW>

    if isfield(S, propertyName)
        % Add _ to the end of the link name to create the "config" name
        configName = sprintf('%s_', propertyName);
        S.(configName) = metadataInstances;
        if isempty(S.(propertyName))
            % Make sure empty value is a char
            S.(propertyName) = '';
        end
    else
        % I guess this should not happen so throw error if it does
        error('No field for linked type with name ''%s''', propertyName)
    end
end
