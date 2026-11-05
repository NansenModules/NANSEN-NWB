function item = getDefaultFileConfigurationItem()
%getDefaultFileConfigurationItem - Get a blank NWB configuration item
%   ITEM = getDefaultFileConfigurationItem() returns the struct that one
%   row of the NWB configuration table is built from, with its columns
%   set to the placeholders the table shows until a user picks a value.
%
%   The field names are written into saved configuration files, so they
%   are part of the on-disk format rather than an internal detail.
%
%   See also nansen.module.nwb.file.initializeNWBFileConfiguration

    placeholders = nansen.module.nwb.internal.getUnsetPlaceholders();

    item = struct();
    item.VariableName = '';
    item.NWBVariableName = '';
    item.PrimaryGroupName = char(placeholders.PrimaryGroupName);
    item.NwbModule = char(placeholders.NwbModule);
    item.NeuroDataType = char(placeholders.NeuroDataType);
    item.Converter = 'Default';
    item.DefaultMetadata = struct.empty;
end
