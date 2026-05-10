function registerConverterFolder(folderPath)
%registerConverterFolder Register custom NWB converter descriptors.

    arguments
        folderPath (1,1) string {mustBeFolder}
    end

    registry = nansen.module.nwb.conversion.ConverterRegistry.instance();
    registry.registerFolder(folderPath)
end
