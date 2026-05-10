function S = initializeNwbFileConfiguration(currentProject)
%initializeNwbFileConfiguration Create a blank project-level NWB config.

    import nansen.module.nwb.file.getDefaultFileConfigurationItem

    if ~nargin
        currentProject = nansen.getCurrentProject();
    end

    variableItems = currentProject.VariableModel.Data;
    filteredVariableItems = variableItems(~[variableItems.IsInternal]);

    baseConfig = nansen.module.nwb.config.NwbFileConfiguration();
    S = baseConfig.toStruct();
    S.Name = "Processed";
    S.Description = "Processed Data for Sharing";
    S.AllVariableNames = {variableItems.VariableName};

    if isempty(filteredVariableItems)
        S.DataItems = struct.empty;
        return
    end

    defaultItem = getDefaultFileConfigurationItem();
    configItems = repmat(defaultItem, 1, numel(filteredVariableItems));

    [configItems(:).VariableName] = deal(filteredVariableItems.VariableName);
    [configItems(:).NWBVariableName] = deal(filteredVariableItems.VariableName);

    S.DataItems = configItems;
end
