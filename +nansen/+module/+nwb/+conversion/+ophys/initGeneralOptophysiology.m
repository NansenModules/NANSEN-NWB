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
%   NWB requires an optical channel to have a description and an
%   emission_lambda, and an imaging plane an excitation_lambda, an
%   indicator and a location. They are checked before anything is added
%   to the file, because matnwb checks them only when the file is
%   exported, after every other data item has been converted.
%
%   Errors:
%     nansen:nwb:missingRequiredMetadata - neither the metadata given nor
%                     the stored metadata sets a property NWB requires.
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

    deviceMetadata = mergeMetadata( ...
        loadMetadata("Device", "Name", "2PhotonMicroscope"), options.DeviceMetadata);

    % Every channel and plane is described and checked before the file is
    % touched, so a missing property leaves the file as it was.
    channelMetadata = cell(1, options.NumChannels);
    planeNames = strings(options.NumChannels, options.NumPlanes);
    planeMetadata = cell(options.NumChannels, options.NumPlanes);
    for iCh = 1:options.NumChannels

        channelName = getOphysTypeName("OpticalChannel", ...
            "ChannelNumber", iCh, ...
            "NumChannels", options.NumChannels);

        channelMetadata{iCh} = mergeMetadata( ...
            loadMetadata("OpticalChannel", "Name", channelName), ...
            options.OpticalChannelMetadata);
        assertRequiredMetadata(channelMetadata{iCh}, ["description", "emission_lambda"], ...
            "optical channel", channelName, "OpticalChannelMetadata")

        for iPlane = 1:options.NumPlanes

            planeNames(iCh, iPlane) = getOphysTypeName("ImagingPlane", ...
                "ChannelNumber", iCh, ...
                "NumChannels", options.NumChannels, ...
                "PlaneNumber", iPlane, ...
                "NumPlanes", options.NumPlanes);

            planeMetadata{iCh, iPlane} = mergeMetadata( ...
                loadMetadata("ImagingPlane", "Name", planeNames(iCh, iPlane)), ...
                options.ImagingPlaneMetadata);
            assertRequiredMetadata(planeMetadata{iCh, iPlane}, ...
                ["excitation_lambda", "indicator", "location"], ...
                "imaging plane", planeNames(iCh, iPlane), "ImagingPlaneMetadata")
        end
    end

    % Add 2-photon microscope device to nwb file object
    deviceNvPairs = namedargs2cell(deviceMetadata);
    twoPhotonMicroscopeDevice = types.core.Device( deviceNvPairs{:} );
    nwbFile.general_devices.set("2PhotonMicroscope", twoPhotonMicroscopeDevice);

    for iCh = 1:options.NumChannels

        % Add optical channel
        channelNvPairs = namedargs2cell(channelMetadata{iCh});
        opticalChannel = types.core.OpticalChannel(channelNvPairs{:});

        for iPlane = 1:options.NumPlanes

            planeNvPairs = namedargs2cell(planeMetadata{iCh, iPlane});
            imagingPlane = types.core.ImagingPlane( ...
                planeNvPairs{:}, ...
                'optical_channel', opticalChannel, ...
                'device', twoPhotonMicroscopeDevice ...
                );
    
            nwbFile.general_optophysiology.set(planeNames(iCh, iPlane), imagingPlane);
        end
    end
end

function merged = mergeMetadata(storedNvPairs, overrides)
%mergeMetadata - Lay metadata given by the caller over the stored metadata

    stored = struct();
    for i = 1:2:numel(storedNvPairs)
        stored.(storedNvPairs{i}) = storedNvPairs{i + 1};
    end

    merged = nansen.module.nwb.internal.deepMerge(stored, overrides);
end

function assertRequiredMetadata(metadata, requiredNames, typeLabel, objectName, argumentName)
%assertRequiredMetadata - Require the properties NWB needs for one object

    isMissing = false(size(requiredNames));
    for i = 1:numel(requiredNames)
        isMissing(i) = ~isfield(metadata, requiredNames(i)) ...
            || isBlankValue(metadata.(requiredNames(i)));
    end

    if any(isMissing)
        missingNames = requiredNames(isMissing);
        error("nansen:nwb:missingRequiredMetadata", ...
            ['The %s ''%s'' needs %s, which NWB requires. Set them in ', ...
             'ConverterArgs.%s, or in the project''s stored metadata.'], ...
            typeLabel, objectName, strjoin(missingNames, ", "), argumentName)
    end
end

function tf = isBlankValue(value)
%isBlankValue - True for a value a template leaves unset

    tf = isempty(value) || ((isstring(value) || ischar(value)) && all(strlength(string(value)) == 0));
end
