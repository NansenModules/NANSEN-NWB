function initGeneralOptophysiology(nwbFile, options)
%initGeneralOptophysiology - Add the optophysiology metadata to a file
%   initGeneralOptophysiology(nwbFile) creates the device, optical
%   channel and imaging plane an optophysiology recording needs and adds
%   them to the general_optophysiology group of the file. It modifies the
%   file in place and returns nothing.
%
%   initGeneralOptophysiology(...,NumPlanes=VALUE,NumChannels=VALUE) also
%   states how many planes and channels the recording has, so that one
%   imaging plane is created per combination and named apart.
%
%   initGeneralOptophysiology(...,DeviceMetadata=S,OpticalChannelMetadata=S,
%   ImagingPlaneMetadata=S) also supplies metadata for the device, for
%   every optical channel and for every imaging plane, as structs of
%   property values. A property given here wins over the one the
%   project's stored metadata holds for it.
%
%   Values not given are taken from the project's stored metadata where
%   present.
%
%   See also nansen.module.nwb.conversion.ophys.utility.getOphysTypeName

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
    deviceMetadata = mergeMetadata( ...
        loadMetadata("Device", "Name", "2PhotonMicroscope"), options.DeviceMetadata);
    twoPhotonMicroscopeDevice = types.core.Device( deviceMetadata{:} );
    nwbFile.general_devices.set("2PhotonMicroscope", twoPhotonMicroscopeDevice);
    
    for iCh = 1:options.NumChannels

        channelName = getOphysTypeName("OpticalChannel", ...
            "ChannelNumber", iCh, ...
            "NumChannels", options.NumChannels);

        channelMetadata = mergeMetadata( ...
            loadMetadata("OpticalChannel", "Name", channelName), ...
            options.OpticalChannelMetadata);

        % Add optical channel
        opticalChannel = types.core.OpticalChannel(channelMetadata{:});

        for iPlane = 1:options.NumPlanes

            planeName = getOphysTypeName("ImagingPlane", ...
                "ChannelNumber", iCh, ...
                "NumChannels", options.NumChannels, ...
                "PlaneNumber", iPlane, ...
                "NumPlanes", options.NumPlanes);

            planeMetadata = mergeMetadata( ...
                loadMetadata("ImagingPlane", "Name", planeName), ...
                options.ImagingPlaneMetadata);

            imagingPlane = types.core.ImagingPlane( ...
                planeMetadata{:}, ...
                'optical_channel', opticalChannel, ...
                'device', twoPhotonMicroscopeDevice ...
                );
    
            nwbFile.general_optophysiology.set(planeName, imagingPlane);
        end
    end
end

function nvPairs = mergeMetadata(storedNvPairs, overrides)
%mergeMetadata - Lay metadata given by the caller over the stored metadata

    stored = struct();
    for i = 1:2:numel(storedNvPairs)
        stored.(storedNvPairs{i}) = storedNvPairs{i + 1};
    end

    merged = nansen.module.nwb.internal.deepMerge(stored, overrides);
    nvPairs = namedargs2cell(merged);
end
