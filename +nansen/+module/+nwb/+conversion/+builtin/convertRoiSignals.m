function nwbFile = convertRoiSignals(context)
%convertRoiSignals - Add ROI responses to the ophys processing module
%   nwbFile = convertRoiSignals(CONTEXT) converts the ROI signal array in
%   CONTEXT.Data to a RoiResponseSeries, points it at the rows of the
%   plane segmentation it was measured from, and stores it in the ophys
%   processing module.
%
%   The series is wrapped in a Fluorescence or DfOverF interface, which
%   is how NWB distinguishes raw ROI fluorescence from a normalized
%   signal.
%
%   CONTEXT.Data is a timetable with one column per ROI, or a double or
%   single matrix of samples by ROIs, the form NANSEN saves the
%   RoiSignals_* variables in. A matrix needs SamplingRate.
%
%   Converter arguments:
%       SamplingRate           - Samples per second of a matrix, in Hz
%       ResponseType           - "Fluorescence" (default) or "DeltaFOverF"
%       InterfaceName          - Name of the wrapping interface
%       ImageSegmentationName  - ImageSegmentation holding the ROI table
%       PlaneSegmentationName  - PlaneSegmentation the responses index
%
%   Errors:
%     nansen:nwb:missingPlaneSegmentation - the ROI table this series
%                     must reference has not been written yet.
%     nansen:nwb:unsupportedResponseType - ResponseType is not one of the
%                     supported values.
%
%   See also nansen.module.nwb.conversion.ophys.convertRoiResponses,
%   nansen.module.nwb.conversion.builtin.convertRoiGroupToPlaneSegmentation

    arguments
        context (1,1) struct
    end

    import nansen.module.nwb.conversion.getConverterArg

    args = context.ConverterArgs;

    signalName = context.DataItem.NWBVariableName;
    if strlength(signalName) == 0
        signalName = context.DataItem.VariableName;
    end

    roiResponseSeries = nansen.module.nwb.conversion.ophys.convertRoiResponses( ...
        context.Data, SamplingRate=getConverterArg(args, "SamplingRate", []));
    roiResponseSeries.rois = getRoiTableRegion( ...
        context.NwbFile, args, size(roiResponseSeries.data, 1));

    responseType = string(getConverterArg(args, "ResponseType", "Fluorescence"));
    interfaceName = string(getConverterArg(args, "InterfaceName", responseType));
    ophysModule = nansen.module.nwb.file.getProcessingModule( ...
        context.NwbFile, "ophys", "Optical physiology processing module");

    % Several signal items (planes, channels, raw and neuropil) share one
    % interface, so an existing one is added to rather than replaced.
    if ophysModule.nwbdatainterface.isKey(interfaceName)
        responseInterface = ophysModule.nwbdatainterface.get(interfaceName);
    else
        responseInterface = createResponseInterface(responseType);
    end
    responseInterface.roiresponseseries.set(char(signalName), roiResponseSeries);
    ophysModule.nwbdatainterface.set(char(interfaceName), responseInterface);

    nwbFile = context.NwbFile;
end

function responseInterface = createResponseInterface(responseType)
%createResponseInterface - The interface NWB uses for a kind of ROI response

    switch responseType
        case "Fluorescence"
            responseInterface = types.core.Fluorescence();
        case "DeltaFOverF"
            responseInterface = types.core.DfOverF();
        otherwise
            error("nansen:nwb:unsupportedResponseType", ...
                ['''%s'' is not a supported ROI response type. Set ', ...
                 'ConverterArgs.ResponseType to "Fluorescence" or ', ...
                 '"DeltaFOverF".'], responseType)
    end
end

function roiTableRegion = getRoiTableRegion(nwbFile, args, numRois)
%getRoiTableRegion - Build a region covering every row of the ROI table

    planeSegmentation = getPlaneSegmentation(nwbFile, args);

    % NWB indices are zero-based.
    roiTableRegion = types.hdmf_common.DynamicTableRegion( ...
        'table', types.untyped.ObjectView(planeSegmentation), ...
        'description', 'all ROIs in the plane segmentation', ...
        'data', (0:numRois-1)');
end

function planeSegmentation = getPlaneSegmentation(nwbFile, args)
%getPlaneSegmentation - Find the ROI table these responses were measured from

    import nansen.module.nwb.conversion.getConverterArg

    imageSegmentationName = string(getConverterArg(args, ...
        "ImageSegmentationName", "ImageSegmentation"));
    planeSegmentationName = string(getConverterArg(args, ...
        "PlaneSegmentationName", "PlaneSegmentation"));

    % A RoiResponseSeries is meaningless without the ROI table its columns
    % index, so the masks have to be converted first. The runner orders
    % items to make that happen; this check catches a hand-built
    % configuration that bypassed it.
    if ~nwbFile.processing.isKey("ophys") || ...
            ~nwbFile.processing.get("ophys").nwbdatainterface.isKey(imageSegmentationName)
        error("nansen:nwb:missingPlaneSegmentation", ...
            ['ROI signals reference the ROI table ''%s''/''%s'', which is ', ...
             'not in the file. Convert the ROI masks in the same run, or ', ...
             'into the file being appended to.'], ...
            imageSegmentationName, planeSegmentationName)
    end

    imageSegmentation = nwbFile.processing.get("ophys") ...
        .nwbdatainterface.get(imageSegmentationName);
    if ~imageSegmentation.planesegmentation.isKey(planeSegmentationName)
        error("nansen:nwb:missingPlaneSegmentation", ...
            ['ROI signals reference the plane segmentation ''%s'', but ', ...
             '''%s'' holds: %s.'], planeSegmentationName, imageSegmentationName, ...
            strjoin(string(imageSegmentation.planesegmentation.keys()), ", "))
    end

    planeSegmentation = imageSegmentation.planesegmentation.get(planeSegmentationName);
end
