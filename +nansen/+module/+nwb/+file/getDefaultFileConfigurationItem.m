function item = getDefaultFileConfigurationItem()

    item = struct();
    item.VariableName = '';
    item.NWBVariableName = '';
    item.PrimaryGroupName = '<Select a group>';
    item.NwbModule = '<Select an NWB module>';
    item.NeuroDataType = '<Select a neurodata type>';
    item.Converter = 'Default';
    item.DefaultMetadata = struct.empty;
end