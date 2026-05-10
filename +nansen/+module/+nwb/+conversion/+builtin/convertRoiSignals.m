function nwbFile = convertRoiSignals(context)
%convertRoiSignals Add ROI responses to the ophys processing module.

    arguments
        context (1,1) struct
    end

    args = context.ConverterArgs;
    signalName = string(context.DataItem.NWBVariableName);
    if signalName == ""
        signalName = string(context.DataItem.VariableName);
    end

    roiResponseSeries = nansen.module.nwb.conversion.ophys.convertRoiResponses(context.Data);
    roiResponseSeries.rois = getRoiTableRegion(context.NwbFile, args, size(roiResponseSeries.data, 1));

    responseType = string(getOptionalArg(args, "ResponseType", "Fluorescence"));
    switch responseType
        case "Fluorescence"
            wrapper = types.core.Fluorescence();
        case "DeltaFOverF"
            wrapper = types.core.DfOverF();
        otherwise
            error("NansenNwb:UnsupportedRoiResponseType", ...
                "Unsupported ROI response type: %s", responseType)
    end
    wrapper.roiresponseseries.set(char(signalName), roiResponseSeries);

    interfaceName = string(getOptionalArg(args, "InterfaceName", responseType));
    ophysModule = nansen.module.nwb.file.getProcessingModule( ...
        context.NwbFile, "ophys", "Ophys processing module");
    ophysModule.nwbdatainterface.set(char(interfaceName), wrapper);

    nwbFile = context.NwbFile;
end

function roiTableRegion = getRoiTableRegion(nwbFile, args, nRois)
    planeSegmentation = getPlaneSegmentation(nwbFile, args);
    roiTableRegion = types.hdmf_common.DynamicTableRegion( ...
        'table', types.untyped.ObjectView(planeSegmentation), ...
        'description', 'all_rois', ...
        'data', (0:nRois-1)');
end

function planeSegmentation = getPlaneSegmentation(nwbFile, args)
    imageSegmentationName = string(getOptionalArg(args, "ImageSegmentationName", "ImageSegmentation"));
    planeSegmentationName = string(getOptionalArg(args, "PlaneSegmentationName", "PlaneSegmentation"));

    if ~nwbFile.processing.isKey("ophys")
        error("NansenNwb:MissingOphysProcessingModule", ...
            "ROI signals require ROI masks to be written first.")
    end

    ophysModule = nwbFile.processing.get("ophys");
    if ~ophysModule.nwbdatainterface.isKey(imageSegmentationName)
        error("NansenNwb:MissingImageSegmentation", ...
            "ROI signals require ImageSegmentation '%s' to exist.", imageSegmentationName)
    end

    imageSegmentation = ophysModule.nwbdatainterface.get(imageSegmentationName);
    if ~imageSegmentation.planesegmentation.isKey(planeSegmentationName)
        error("NansenNwb:MissingPlaneSegmentation", ...
            "ROI signals require PlaneSegmentation '%s' to exist.", planeSegmentationName)
    end

    planeSegmentation = imageSegmentation.planesegmentation.get(planeSegmentationName);
end

function value = getOptionalArg(args, name, defaultValue)
    name = char(name);
    if isfield(args, name) && ~isempty(args.(name))
        value = args.(name);
    else
        value = defaultValue;
    end
end
