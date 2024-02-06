function S = initializeNwbFileConfiguration(currentProject)

    import nansen.module.nwb.file.getDefaultFileConfigurationItem
    
    if ~nargin
        currentProject = nansen.getCurrentProject();
    end

    variableItems = currentProject.VariableModel.Data;
    filteredVariableItems = variableItems(~[variableItems.IsInternal]);
    filteredVariableItems = filteredVariableItems([filteredVariableItems.IsCustom]); % Todo: Remove as this is temporary

    defaultItem = getDefaultFileConfigurationItem();
    configItems = repmat(defaultItem, 1, numel(filteredVariableItems));

    [configItems(:).VariableName] = deal(filteredVariableItems.VariableName);
    [configItems(:).NWBVariableName] = deal(filteredVariableItems.VariableName);

    S = struct;
    S.Name = "Processed"; % Use for differentiating different NWB files, i.e raw data for internal use, processed data for sharing
    S.Description = "Processed Data for Sharing";

    S.DataItems = configItems;
    S.AllVariableNames = {variableItems.VariableName};
end