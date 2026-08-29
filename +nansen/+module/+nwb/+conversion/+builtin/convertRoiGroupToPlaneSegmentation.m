function nwbFile = convertRoiGroupToPlaneSegmentation(context)
%convertRoiGroupToPlaneSegmentation - Add ROI masks to the ophys module
%   nwbFile = convertRoiGroupToPlaneSegmentation(CONTEXT) converts the ROI
%   group in CONTEXT.Data to a PlaneSegmentation, links it to its imaging
%   plane, and stores it in an ImageSegmentation in the ophys processing
%   module.
%
%   The optophysiology metadata the segmentation links to is created when
%   the file does not already carry it, so ROI masks can be the first
%   ophys item converted.
%
%   Converter arguments:
%       IsCell                 - Logical vector marking which ROIs are cells
%       NumPlanes              - Imaging planes in the recording (default 1)
%       NumChannels            - Channels in the recording (default 1)
%       PlaneNumber            - Plane this ROI group belongs to (default 1)
%       ChannelNumber          - Channel this ROI group belongs to (default 1)
%       ImagingPlaneName       - Name of the imaging plane to link to
%       ImageSegmentationName  - Name of the containing ImageSegmentation
%       PlaneSegmentationName  - Name given to the PlaneSegmentation
%       DeviceMetadata         - Metadata for the imaging device
%       OpticalChannelMetadata - Metadata for the optical channel
%       ImagingPlaneMetadata   - Metadata for the imaging plane
%
%   Errors:
%     nansen:nwb:missingImagingPlane - the named imaging plane is not in
%                     the file's optophysiology metadata.
%
%   See also nansen.module.nwb.conversion.ophys.convertRoiGroup,
%   nansen.module.nwb.conversion.builtin.convertRoiSignals

    arguments
        context (1,1) struct
    end

    import nansen.module.nwb.conversion.getConverterArg

    args = context.ConverterArgs;

    ensureOptophysiology(context.NwbFile, args)

    planeSegmentation = nansen.module.nwb.conversion.ophys.convertRoiGroup( ...
        context.Data, getConverterArg(args, "IsCell", logical.empty), context.Metadata);
    planeSegmentation.imaging_plane = getImagingPlane(context.NwbFile, args);

    imageSegmentationName = string(getConverterArg(args, ...
        "ImageSegmentationName", "ImageSegmentation"));
    planeSegmentationName = string(getConverterArg(args, ...
        "PlaneSegmentationName", "PlaneSegmentation"));

    ophysModule = nansen.module.nwb.file.getProcessingModule( ...
        context.NwbFile, "ophys", "Optical physiology processing module");

    % Several ROI groups (planes, channels) share one ImageSegmentation.
    if ophysModule.nwbdatainterface.isKey(imageSegmentationName)
        imageSegmentation = ophysModule.nwbdatainterface.get(imageSegmentationName);
    else
        imageSegmentation = types.core.ImageSegmentation();
    end

    imageSegmentation.planesegmentation.set(char(planeSegmentationName), planeSegmentation);
    ophysModule.nwbdatainterface.set(char(imageSegmentationName), imageSegmentation);

    nwbFile = context.NwbFile;
end

function ensureOptophysiology(nwbFile, args)
%ensureOptophysiology - Create optophysiology metadata when absent

    import nansen.module.nwb.conversion.getConverterArg

    if ~isempty(nwbFile.general_optophysiology) && ...
            ~isempty(nwbFile.general_optophysiology.keys())
        return
    end

    nansen.module.nwb.conversion.ophys.initGeneralOptophysiology( ...
        nwbFile, ...
        "NumPlanes", getConverterArg(args, "NumPlanes", 1), ...
        "NumChannels", getConverterArg(args, "NumChannels", 1), ...
        "DeviceMetadata", getConverterArg(args, "DeviceMetadata", struct()), ...
        "OpticalChannelMetadata", getConverterArg(args, "OpticalChannelMetadata", struct()), ...
        "ImagingPlaneMetadata", getConverterArg(args, "ImagingPlaneMetadata", struct()));
end

function imagingPlane = getImagingPlane(nwbFile, args)
%getImagingPlane - Look up the imaging plane this ROI group belongs to

    import nansen.module.nwb.conversion.ophys.utility.getOphysTypeName
    import nansen.module.nwb.conversion.getConverterArg

    planeName = string(getConverterArg(args, "ImagingPlaneName", ""));
    if strlength(planeName) == 0
        planeName = getOphysTypeName("ImagingPlane", ...
            "ChannelNumber", getConverterArg(args, "ChannelNumber", 1), ...
            "PlaneNumber", getConverterArg(args, "PlaneNumber", 1), ...
            "NumPlanes", getConverterArg(args, "NumPlanes", 1), ...
            "NumChannels", getConverterArg(args, "NumChannels", 1));
    end

    if ~nwbFile.general_optophysiology.isKey(planeName)
        error("nansen:nwb:missingImagingPlane", ...
            ['Imaging plane ''%s'' is not in the file. Set ', ...
             'ConverterArgs.ImagingPlaneName to one of: %s.'], planeName, ...
            strjoin(string(nwbFile.general_optophysiology.keys()), ", "))
    end
    imagingPlane = nwbFile.general_optophysiology.get(planeName);
end
