function planeSegmentation = convertRoiGroup(roiGroup, isCell, metadata)
% convertRoiGroup - Convert roig group to plane segmentation neurodata type    
    
    arguments
        roiGroup
        isCell (:,1) logical = logical.empty
        metadata (1,1) struct = struct
    end

    % Todo: Loop over channels and planes of RoiGroup?

    imageWidth = roiGroup.FovImageSize(2);
    imageHeight = roiGroup.FovImageSize(1);
    
    roiArray = roiGroup.roiArray;

    if ~isempty(isCell)
        roiArray = roiArray(isCell);
    end

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
