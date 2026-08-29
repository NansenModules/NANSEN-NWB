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
%   Values are taken from the project's stored metadata where present.
%
%   See also nansen.module.nwb.conversion.ophys.utility.getOphysTypeName

    arguments
        nwbFile
        options.NumPlanes = 1
        options.NumChannels = 1
    end

    import nansen.module.nwb.conversion.loadMetadata
    import nansen.module.nwb.conversion.ophys.utility.getOphysTypeName

    % Add 2-photon microscope device to nwb file object
    deviceMetadata = loadMetadata("Device", "Name", "2PhotonMicroscope");
    twoPhotonMicroscopeDevice = types.core.Device( deviceMetadata{:} );
    nwbFile.general_devices.set("2PhotonMicroscope", twoPhotonMicroscopeDevice);
    
    for iCh = 1:options.NumChannels

        channelName = getOphysTypeName("OpticalChannel", ...
            "ChannelNumber", iCh, ...
            "NumChannels", options.NumChannels);

        channelMetadata = loadMetadata("OpticalChannel", "Name", channelName);

        % Add optical channel
        opticalChannel = types.core.OpticalChannel(channelMetadata{:});

        for iPlane = 1:options.NumPlanes

            planeName = getOphysTypeName("ImagingPlane", ...
                "ChannelNumber", iCh, ...
                "NumChannels", options.NumChannels, ...
                "PlaneNumber", iPlane, ...
                "NumPlanes", options.NumPlanes);

            planeMetadata = loadMetadata("ImagingPlane", "Name", planeName);

            imagingPlane = types.core.ImagingPlane( ...
                planeMetadata{:}, ...
                'optical_channel', opticalChannel, ...
                'device', twoPhotonMicroscopeDevice ...
                );
    
            nwbFile.general_optophysiology.set(planeName, imagingPlane);
        end
    end
end
