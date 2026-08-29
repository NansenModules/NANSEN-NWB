function nwbFile = convertProjectionImages(context)
%convertProjectionImages - Add field-of-view projection images to the file
%   nwbFile = convertProjectionImages(CONTEXT) stores the projection
%   images in CONTEXT.Data in an Images collection in the ophys
%   processing module, creating the collection on first use so several
%   items can add to one.
%
%   A projection image summarizes a recording: an average or maximum
%   over frames, or a correlation image. CONTEXT.Data may be an image
%   matrix, an ImageStack whose first frame is taken, or a struct whose
%   fields each name one image.
%
%   Converter arguments:
%       CollectionName - Images collection to add to, "FovProjectionImages"
%                        by default
%       Description    - Description given to a newly created collection
%
%   See also nansen.module.nwb.conversion.builtin.convertImageStackToTwoPhotonSeries,
%   nansen.module.nwb.file.getProcessingModule

    arguments
        context (1,1) struct
    end

    import nansen.module.nwb.conversion.getConverterArg

    args = context.ConverterArgs;
    collectionName = string(getConverterArg(args, "CollectionName", "FovProjectionImages"));
    description = string(getConverterArg(args, "Description", ...
        "Field of view projection images."));

    images = namedImages(context.Data, context.DataItem);

    ophysModule = nansen.module.nwb.file.getProcessingModule( ...
        context.NwbFile, "ophys", "Optical physiology processing module");

    if ophysModule.nwbdatainterface.isKey(collectionName)
        imageCollection = ophysModule.nwbdatainterface.get(collectionName);
    else
        imageCollection = types.core.Images('description', char(description));
    end

    for i = 1:numel(images)
        addImage(imageCollection, images(i).Name, images(i).Data)
    end

    ophysModule.nwbdatainterface.set(char(collectionName), imageCollection);

    nwbFile = context.NwbFile;
end

function addImage(imageCollection, name, imageData)
%addImage - Put one image into the collection
%
%   NWB 2.9 renamed the Images collection's member property from image to
%   baseimage. The module does not pin a matnwb version, so whichever the
%   installed schema defines is used.

    grayscaleImage = types.core.GrayscaleImage('data', imageData);

    if isprop(imageCollection, 'baseimage')
        imageCollection.baseimage.set(char(name), grayscaleImage);
    else
        imageCollection.image.set(char(name), grayscaleImage);
    end
end

function images = namedImages(data, dataItem)
%namedImages - Resolve the input into a list of named images

    baseName = dataItem.NWBVariableName;
    if strlength(baseName) == 0
        baseName = dataItem.VariableName;
    end

    if isstruct(data) && isscalar(data)
        % A struct of projections: each field is one named image.
        fieldNames = string(fieldnames(data));
        images = struct("Name", cell(1, numel(fieldNames)), "Data", []);
        for i = 1:numel(fieldNames)
            images(i).Name = fieldNames(i);
            images(i).Data = imageMatrix(data.(fieldNames(i)));
        end
        return
    end

    images = struct("Name", baseName, "Data", imageMatrix(data));
end

function imageData = imageMatrix(data)
%imageMatrix - Take an image matrix from the data, without loading a stack

    % An ImageStack holds far more than one image, so only the frame the
    % projection needs is read.
    if isobject(data) && ismethod(data, "getFrameSet")
        imageData = data.getFrameSet(1);
        return
    end

    if ~isnumeric(data) && ~islogical(data)
        error("nansen:nwb:invalidConverterInput", ...
            ['A projection image must be a numeric matrix, a struct of ', ...
             'them, or an image stack, but was %s.'], class(data))
    end

    imageData = data;
end
