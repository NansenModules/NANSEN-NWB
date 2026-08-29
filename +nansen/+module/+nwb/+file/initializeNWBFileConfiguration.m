function S = initializeNWBFileConfiguration(currentProject)
%initializeNWBFileConfiguration - Build a configuration from a project
%   S = initializeNWBFileConfiguration() creates a configuration for the
%   current project, with one item per custom data variable and an empty
%   electrodes table. It returns an empty struct if the project defines
%   no such variables.
%
%   S = initializeNWBFileConfiguration(currentProject) uses the given
%   project instead of the current one.
%
%   See also nansen.module.nwb.file.getDefaultFileConfigurationItem,
%   nansen.module.nwb.gui.NWBConfigurator

    import nansen.module.nwb.file.getDefaultFileConfigurationItem
    
    if ~nargin
        currentProject = nansen.getCurrentProject();
    end

    variableItems = currentProject.VariableModel.Data;
    filteredVariableItems = variableItems(~[variableItems.IsInternal]);
    filteredVariableItems = filteredVariableItems([filteredVariableItems.IsCustom]); % Todo: Remove as this is temporary

    if isempty(filteredVariableItems)
        S = struct.empty; return
    end

    defaultItem = getDefaultFileConfigurationItem();
    configItems = repmat(defaultItem, 1, numel(filteredVariableItems));

    [configItems(:).VariableName] = deal(filteredVariableItems.VariableName);
    [configItems(:).NWBVariableName] = deal(filteredVariableItems.VariableName);

    S = struct;
    S.Name = "Processed"; % Use for differentiating different NWB files, i.e raw data for internal use, processed data for sharing
    S.Description = "Processed Data for Sharing";

    S.DataItems = configItems;
    S.General.ExtracellularEphys.Electrodes = ...
        nansen.module.nwb.internal.dtable.initializeElectrodesTable();
    S.AllVariableNames = {variableItems.VariableName};
end
