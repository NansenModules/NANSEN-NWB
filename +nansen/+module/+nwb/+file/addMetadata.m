function addMetadata(nwbFile, name, nwbObject)

    % Todo: Generate a mapping from type to general based on file schema

    switch class(nwbObject)
            
        case "types.core.Device"
            nwbFile.general_devices.set(name, nwbObject)

        case "types.core.ImagingPlane"
            nwbFile.general_optophysiology.set(name, nwbObject)

    end

end