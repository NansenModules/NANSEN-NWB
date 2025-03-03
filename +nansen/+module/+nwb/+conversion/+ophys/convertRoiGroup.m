function planeSegmentation = convertRoiGroup(roiGroup, isCell, metadata, options)
% convertRoiGroup - Convert roig group to plane segmentation neurodata type    
    
    arguments
        roiGroup
        isCell (:,1) logical = logical.empty
        metadata (1,1) struct = struct
        options.MaskType = 'pixel'
    end

    % Todo: Loop over channels and planes of RoiGroup?

    imageWidth = roiGroup.FovImageSize(2);
    imageHeight = roiGroup.FovImageSize(1);
    
    roiArray = roiGroup.roiArray;

    if ~isempty(isCell)
        roiArray = roiArray(isCell);
    end

    planeSegmentation = createPixelMaskPlaneSegmentation(roiArray);
    return

    % Prepare imagemasks
    numRois = numel(roiArray);
    imageMask = zeros(imageHeight, imageWidth, numRois, 'single');
    
    for i = 1:numRois
        thisMask = single(roiArray(i).mask);
        thisMask(thisMask==1) = roiArray(i).pixelweights;
        imageMask(:, :, i) = thisMask;
    end

    % Create plane segmentation with image masks
    planeSegmentation = types.core.PlaneSegmentation( ...
        'colnames', {'image_mask'}, ...
        'description', 'Image mask from segmentation', ...
        'id', types.hdmf_common.ElementIdentifiers('data', int64(0:numRois-1)'), ...
        'image_mask', types.hdmf_common.VectorData(...
            'description', 'image masks', ...
            'data', imageMask ...
            ) ...
    );
end

function plane_segmentation = createPixelMaskPlaneSegmentation(roiArray)
    
    numRois = numel(roiArray);

    xInd = cell(1,numel(roiArray));
    yInd = cell(1,numel(roiArray));
    w = cell(1,numel(roiArray));

    for i = 1:numel(roiArray)
        xInd{i} = roiArray(i).coordinates(:,1);
        yInd{i} = roiArray(i).coordinates(:,2);
        w{i} = roiArray(i).pixelweights;
    end
    pixel_mask_struct = struct();
    pixel_mask_struct.x = uint32( cat(1, xInd{:}) ); % Add x coordinates to struct field x
    pixel_mask_struct.y = uint32( cat(1, yInd{:}) ); % Add y coordinates to struct field y
    pixel_mask_struct.weight = single( cat(1, w{:}) ); 
    
    % Create pixel mask vector data
    pixel_mask = types.hdmf_common.VectorData(...
            'data', struct2table(pixel_mask_struct), ...
            'description', 'pixel masks');

    % When creating a pixel mask, it is also necessary to specify a
    % pixel_mask_index vector. See the documentation for ragged arrays linked
    % above to learn more.
    numPixelsPerRoi = zeros(numel(roiArray), 1); % Column vector
    for iRoi = 1:numel(roiArray)
        numPixelsPerRoi(iRoi) = numel(roiArray(iRoi).pixelweights);
    end

    pixelMaskIndex = uint32(cumsum(numPixelsPerRoi)); % Note: Use an integer 
    % type that can accommodate the maximum value of the cumulative sum

    % Create pixel_mask_index vector
    pixelMaskIndex = types.hdmf_common.VectorIndex(...
            'description', 'Index into pixel_mask VectorData', ...
            'data', pixelMaskIndex, ...
            'target', types.untyped.ObjectView(pixel_mask) );

    plane_segmentation = types.core.PlaneSegmentation( ...
        'colnames', {'pixel_mask'}, ...
        'description', 'roi pixel position (x,y) and pixel weight', ...
        'pixel_mask_index', pixelMaskIndex, ...
        'pixel_mask', pixel_mask, ...
        'id', types.hdmf_common.ElementIdentifiers('data', int64(0:numRois-1)') ...
    );
end