function nwbFile = convertRoiGroupToPlaneSegmentation(context)
%convertRoiGroupToPlaneSegmentation Add ROI masks to the ophys module.

    arguments
        context (1,1) struct
    end

    args = context.ConverterArgs;
    isCell = getOptionalArg(args, "IsCell", logical.empty);

    ensureOptophysiology(context.NwbFile, args)
    planeSegmentation = nansen.module.nwb.conversion.ophys.convertRoiGroup( ...
        context.Data, isCell, context.Metadata);
    planeSegmentation.imaging_plane = getImagingPlane(context.NwbFile, args);

    imageSegmentationName = string(getOptionalArg(args, "ImageSegmentationName", "ImageSegmentation"));
    planeSegmentationName = string(getOptionalArg(args, "PlaneSegmentationName", "PlaneSegmentation"));

    ophysModule = nansen.module.nwb.file.getProcessingModule( ...
        context.NwbFile, "ophys", "Ophys processing module");

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
    if ~isempty(nwbFile.general_optophysiology) && ~isempty(nwbFile.general_optophysiology.keys())
        return
    end

    nansen.module.nwb.conversion.ophys.initGeneralOptophysiology( ...
        nwbFile, ...
        "NumPlanes", getOptionalArg(args, "NumPlanes", 1), ...
        "NumChannels", getOptionalArg(args, "NumChannels", 1), ...
        "DeviceMetadata", getOptionalArg(args, "DeviceMetadata", struct()), ...
        "OpticalChannelMetadata", getOptionalArg(args, "OpticalChannelMetadata", struct()), ...
        "ImagingPlaneMetadata", getOptionalArg(args, "ImagingPlaneMetadata", struct()));
end

function imagingPlane = getImagingPlane(nwbFile, args)
    import nansen.module.nwb.conversion.ophys.utility.getOphysTypeName

    if isfield(args, 'ImagingPlaneName') && strlength(string(args.ImagingPlaneName)) > 0
        planeName = string(args.ImagingPlaneName);
    else
        planeName = getOphysTypeName("ImagingPlane", ...
            "ChannelNumber", getOptionalArg(args, "ChannelNumber", 1), ...
            "PlaneNumber", getOptionalArg(args, "PlaneNumber", 1), ...
            "NumPlanes", getOptionalArg(args, "NumPlanes", 1), ...
            "NumChannels", getOptionalArg(args, "NumChannels", 1));
    end

    if ~nwbFile.general_optophysiology.isKey(planeName)
        error("NansenNwb:MissingImagingPlane", ...
            "Imaging plane '%s' is missing from nwbFile.general_optophysiology.", planeName)
    end
    imagingPlane = nwbFile.general_optophysiology.get(planeName);
end

function value = getOptionalArg(args, name, defaultValue)
    name = char(name);
    if isfield(args, name) && ~isempty(args.(name))
        value = args.(name);
    else
        value = defaultValue;
    end
end
