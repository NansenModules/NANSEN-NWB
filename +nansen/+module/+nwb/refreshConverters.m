function registry = refreshConverters()
%refreshConverters Rebuild the NWB converter registry.

    registry = nansen.module.nwb.conversion.ConverterRegistry.instance("Refresh", true);
end
