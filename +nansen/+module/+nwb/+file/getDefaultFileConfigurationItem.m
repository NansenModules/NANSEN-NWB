function item = getDefaultFileConfigurationItem()
%getDefaultFileConfigurationItem Create a blank data-item configuration.

    item = nansen.module.nwb.config.NwbDataItemConfig().toStruct();
    item.PrimaryGroup = '<Select a group>';
    item.NwbModule = '<Select an NWB module>';
    item.TargetNwbType = '<Select a neurodata type>';
    item.ConverterName = 'Default';
    item.Metadata = struct.empty;
end
