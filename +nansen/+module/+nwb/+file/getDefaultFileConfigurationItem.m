function item = getDefaultFileConfigurationItem()

    item = struct();
    item.VariableName = '';
    item.NWBVariableName = '';
    item.PrimaryGroupName = '';
    item.NwbModule = '';
    item.NeuroDataType = '';
    item.Converter = '';
    item.DefaultMetadata = struct.empty;
end