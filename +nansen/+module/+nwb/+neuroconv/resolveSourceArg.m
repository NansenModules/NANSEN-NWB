function sourceArg = resolveSourceArg(dataItem, converterArgs)
%resolveSourceArg Create NeuroConv constructor source arguments.

    arguments
        dataItem (1,1)
        converterArgs (1,1) struct
    end

    if isfield(converterArgs, 'SourceArg') && ~isempty(converterArgs.SourceArg)
        if ~isstruct(converterArgs.SourceArg)
            error("NansenNwb:InvalidNeuroconvSource", ...
                "ConverterArgs.SourceArg must be a struct of NeuroConv DataInterface constructor arguments.")
        end
        sourceArg = converterArgs.SourceArg;
        return
    end

    if ~isfield(converterArgs, 'SourceArgumentName') || ...
            strlength(string(converterArgs.SourceArgumentName)) == 0
        error("NansenNwb:MissingNeuroconvSource", ...
            "NeuroConv converters require ConverterArgs.SourceArg or ConverterArgs.SourceArgumentName.")
    end

    sourceInfo = dataItem.SourceInfo;
    sourcePathMode = "file";
    if isfield(converterArgs, 'SourcePathMode') && ~isempty(converterArgs.SourcePathMode)
        sourcePathMode = string(converterArgs.SourcePathMode);
    end

    sourcePath = resolveSourcePath(sourceInfo, sourcePathMode);
    sourceArgumentName = char(converterArgs.SourceArgumentName);
    sourceArg = struct();

    if sourcePathMode == "fileList"
        sourceArg.(sourceArgumentName) = cellstr(sourcePath);
    else
        sourceArg.(sourceArgumentName) = sourcePath;
    end
end

function sourcePath = resolveSourcePath(sourceInfo, sourcePathMode)
    sourcePathMode = string(sourcePathMode);
    switch sourcePathMode
        case {"file", "path"}
            sourcePath = getSourceInfoPath(sourceInfo, ["Path", "FilePath"]);
        case "folder"
            sourcePath = getSourceInfoPath(sourceInfo, ["FolderPath", "Path"]);
        case "parentFolder"
            sourcePath = getSourceInfoPath(sourceInfo, ["Path", "FilePath"]);
            sourcePath = string(fileparts(sourcePath));
        case "fileList"
            sourcePath = getSourceInfoPath(sourceInfo, ["Path", "FilePath"]);
        otherwise
            error("NansenNwb:InvalidNeuroconvSourcePathMode", ...
                "Unsupported NeuroConv SourcePathMode: %s.", sourcePathMode)
    end

    if strlength(sourcePath) == 0
        error("NansenNwb:MissingNeuroconvSource", ...
            "NeuroConv source path could not be resolved from SourceInfo.")
    end
end

function sourcePath = getSourceInfoPath(sourceInfo, fieldNames)
    sourcePath = "";
    for i = 1:numel(fieldNames)
        fieldName = char(fieldNames(i));
        if isfield(sourceInfo, fieldName) && ~isempty(sourceInfo.(fieldName))
            sourcePath = string(sourceInfo.(fieldName));
            return
        end
    end
end
