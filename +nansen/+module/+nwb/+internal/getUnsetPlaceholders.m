function placeholders = getUnsetPlaceholders()
%getUnsetPlaceholders - Placeholder labels for unset configuration columns
%
%   placeholders = getUnsetPlaceholders() returns a struct whose fields name
%   the columns of the NWB data variable configuration table that require a
%   selection, and whose values are the labels shown while no selection has
%   been made.
%
%   getDefaultFileConfigurationItem seeds these labels, DataVariableConfigTable
%   offers them as the first dropdown entry, getTypesForModule declines to
%   look one up as a module name, and checkNWBConfiguration compares against
%   them to detect columns the user has not filled in. All of them need the
%   same strings, so they are defined here.
%
%   Output Arguments:
%     placeholders - Scalar struct of placeholder labels. Type: struct
%
%   See also: nansen.module.nwb.file.getDefaultFileConfigurationItem,
%             nansen.module.nwb.file.checkNWBConfiguration

    placeholders = struct( ...
        'PrimaryGroupName', "<Select a group>", ...
        'NwbModule', "<Select an NWB module>", ...
        'NeuroDataType', "<Select a neurodata type>");
end
