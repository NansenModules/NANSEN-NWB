function initGeneralOptophysiology(nwbFile, options)

    arguments
        nwbFile
        options.NumPlanes = 1
        options.NumChannels = 1
        options.DeviceMetadata (1,1) struct = struct()
        options.OpticalChannelMetadata (1,1) struct = struct()
        options.ImagingPlaneMetadata (1,1) struct = struct()
    end

    import nansen.module.nwb.conversion.loadMetadata
    import nansen.module.nwb.conversion.ophys.utility.getOphysTypeName

    % Add 2-photon microscope device to nwb file object
    deviceMetadata = loadMetadata("Device", "Name", "2PhotonMicroscope");
    deviceMetadata = mergeMetadata(deviceMetadata, options.DeviceMetadata);
    twoPhotonMicroscopeDevice = types.core.Device( deviceMetadata{:} );
    nwbFile.general_devices.set("2PhotonMicroscope", twoPhotonMicroscopeDevice);
    
    for iCh = 1:options.NumChannels

        channelName = getOphysTypeName("OpticalChannel", ...
            "ChannelNumber", iCh, ...
            "NumChannels", options.NumChannels);

        channelMetadata = loadMetadata("OpticalChannel", "Name", channelName);
        channelMetadata = mergeMetadata(channelMetadata, options.OpticalChannelMetadata);
        channelMetadata = coerceSingleField(channelMetadata, "emission_lambda");
        assertRequiredMetadata(channelMetadata, ...
            ["description", "emission_lambda"], "OpticalChannel", ...
            "ConverterArgs.OpticalChannelMetadata");

        % Add optical channel 
        opticalChannel = types.core.OpticalChannel(channelMetadata{:});

        for iPlane = 1:options.NumPlanes

            planeName = getOphysTypeName("ImagingPlane", ...
                "ChannelNumber", iCh, ...
                "NumChannels", options.NumChannels, ...
                "PlaneNumber", iPlane, ...
                "NumPlanes", options.NumPlanes);

            planeMetadata = loadMetadata("ImagingPlane", "Name", planeName);
            planeMetadata = mergeMetadata(planeMetadata, options.ImagingPlaneMetadata);
            planeMetadata = coerceSingleField(planeMetadata, "excitation_lambda");
            assertRequiredMetadata(planeMetadata, ...
                ["excitation_lambda", "indicator", "location"], ...
                "ImagingPlane", "ConverterArgs.ImagingPlaneMetadata");

            imagingPlane = types.core.ImagingPlane( ...
                planeMetadata{:}, ...
                'optical_channel', opticalChannel, ...
                'device', twoPhotonMicroscopeDevice ...
                );
    
            nwbFile.general_optophysiology.set(planeName, imagingPlane);
        end
    end
end

function metadataNameValuePairs = mergeMetadata(metadataNameValuePairs, metadataStruct)
    if isempty(fieldnames(metadataStruct))
        return
    end

    fieldNames = fieldnames(metadataStruct);
    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        existingIndex = find(strcmp(metadataNameValuePairs(1:2:end), fieldName), 1);
        if isempty(existingIndex)
            metadataNameValuePairs = [metadataNameValuePairs, {fieldName, metadataStruct.(fieldName)}]; %#ok<AGROW>
        else
            metadataNameValuePairs{2*existingIndex} = metadataStruct.(fieldName);
        end
    end
end

function metadataNameValuePairs = coerceSingleField(metadataNameValuePairs, fieldName)
    fieldName = char(fieldName);
    fieldIndex = find(strcmp(metadataNameValuePairs(1:2:end), fieldName), 1);
    if ~isempty(fieldIndex) && isnumeric(metadataNameValuePairs{2*fieldIndex})
        metadataNameValuePairs{2*fieldIndex} = single(metadataNameValuePairs{2*fieldIndex});
    end
end

function assertRequiredMetadata(metadataNameValuePairs, requiredFields, typeName, optionName)
    metadataNames = string(metadataNameValuePairs(1:2:end));
    for i = 1:numel(requiredFields)
        fieldName = requiredFields(i);
        fieldIndex = find(metadataNames == fieldName, 1);
        if isempty(fieldIndex) || isempty(metadataNameValuePairs{2*fieldIndex})
            error("NansenNwb:MissingOphysMetadata", ...
                "%s metadata requires '%s'. Provide it in %s or in the project NWB metadata JSON.", ...
                typeName, fieldName, optionName)
        end
    end
end
