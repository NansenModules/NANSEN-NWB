function placeholders = getUnsetPlaceholders()
%getUnsetPlaceholders - Placeholder labels for unset configuration columns
%
%   placeholders = getUnsetPlaceholders() returns a struct whose fields name
%   the columns of the NWB data variable configuration table that require a
%   selection, and whose values are the labels shown while no selection has
%   been made.
%
%   A configuration saved by the legacy table carries these labels in the
%   columns the user never filled: convertLegacyConfiguration treats them
%   as unset, and getTypesForModule declines to look one up as a module
%   name. Both need the same strings, so they are defined here.
%
%   Output Arguments:
%     placeholders - Scalar struct of placeholder labels. Type: struct
%
%   See also: nansen.module.nwb.config.convertLegacyConfiguration,
%             nansen.module.nwb.internal.schemautil.getTypesForModule

    placeholders = struct( ...
        "PrimaryGroupName", "<Select a group>", ...
        "NwbModule", "<Select an NWB module>", ...
        "NeuroDataType", "<Select a neurodata type>");
end
