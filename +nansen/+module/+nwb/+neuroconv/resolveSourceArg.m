function sourceArg = resolveSourceArg(dataItem, converterArgs)
%resolveSourceArg - Build the source arguments a NeuroConv interface takes
%   sourceArg = resolveSourceArg(dataItem,converterArgs) returns a struct
%   of constructor arguments for a NeuroConv data interface, derived from
%   the data item's recorded source path.
%
%   NeuroConv interfaces differ in what they take: one wants a file, the
%   next the folder holding it, a third a list of files. SourcePathMode
%   in converterArgs says which, and SourceArgumentName says what the
%   argument is called. A converter with an unusual signature can bypass
%   both by setting SourceArg to the finished struct.
%
%   SourcePathMode must be one of:
%       "file"         - (default) The data item's own path
%       "path"         - Same as "file"
%       "folder"       - A recorded folder path, or the path itself
%       "parentFolder" - The folder containing the data item's path
%       "fileList"     - Every recorded path, as a cell array
%       "siblingFiles" - Every file beside the data item's path with the
%                        same extension, sorted by name, as a cell array.
%                        For formats that split one session across many
%                        files, such as ABF.
%
%   Errors:
%     nansen:nwb:missingConverterArg - neither SourceArg nor
%                     SourceArgumentName is set.
%     nansen:nwb:missingSourcePath - the data item records no path.
%     nansen:nwb:invalidConverterArg - SourceArg or SourcePathMode is not
%                     a value this function accepts.
%
%   See also nansen.module.nwb.neuroconv.runConversion,
%   nansen.module.nwb.conversion.builtin.convertWithNeuroconv

    arguments
        dataItem (1,1)
        converterArgs (1,1) struct
    end

    import nansen.module.nwb.conversion.getConverterArg

    % An interface whose constructor does not fit the path-argument
    % pattern can be given its arguments verbatim.
    explicitSourceArg = getConverterArg(converterArgs, "SourceArg", []);
    if ~isempty(explicitSourceArg)
        if ~isstruct(explicitSourceArg) || ~isscalar(explicitSourceArg)
            error("nansen:nwb:invalidConverterArg", ...
                ['ConverterArgs.SourceArg must be a scalar struct of ', ...
                 'NeuroConv constructor arguments, but was %s.'], ...
                class(explicitSourceArg))
        end
        sourceArg = explicitSourceArg;
        return
    end

    sourceArgumentName = string(getConverterArg(converterArgs, "SourceArgumentName", ""));
    if strlength(sourceArgumentName) == 0
        error("nansen:nwb:missingConverterArg", ...
            ['A NeuroConv converter needs to know what its source argument ', ...
             'is called. Set ConverterArgs.SourceArgumentName, for example ', ...
             'to "file_path", or give the whole struct as ', ...
             'ConverterArgs.SourceArg.'])
    end

    sourcePathMode = string(getConverterArg(converterArgs, "SourcePathMode", "file"));
    sourcePaths = resolveSourcePaths(dataItem, sourcePathMode);

    sourceArg = struct();
    if any(sourcePathMode == ["fileList", "siblingFiles"])
        sourceArg.(sourceArgumentName) = cellstr(sourcePaths);
    else
        sourceArg.(sourceArgumentName) = sourcePaths(1);
    end
end

function sourcePaths = resolveSourcePaths(dataItem, sourcePathMode)
%resolveSourcePaths - Derive the paths for one source path mode

    recordedPaths = getRecordedPaths(dataItem);

    if isempty(recordedPaths)
        error("nansen:nwb:missingSourcePath", ...
            ['''%s'' has no source path, so there is nothing to hand to ', ...
             'NeuroConv. Set SourceInfo.Path on the data item, or export ', ...
             'from a session where the variable''s file can be found.'], ...
            dataItem.VariableName)
    end

    switch sourcePathMode
        case {"file", "path", "folder"}
            sourcePaths = recordedPaths(1);

        case "parentFolder"
            sourcePaths = string(fileparts(recordedPaths(1)));

        case "fileList"
            sourcePaths = recordedPaths;

        case "siblingFiles"
            sourcePaths = listSiblingFiles(recordedPaths(1));

        otherwise
            error("nansen:nwb:invalidConverterArg", ...
                ['''%s'' is not a supported SourcePathMode. Use one of: ', ...
                 'file, path, folder, parentFolder, fileList, siblingFiles.'], ...
                sourcePathMode)
    end
end

function siblingPaths = listSiblingFiles(filePath)
%listSiblingFiles - Every file beside filePath with its extension, by name
%
%   NANSEN records one path per variable, but a format such as ABF splits
%   one session across many files that NeuroConv takes together. The
%   extension comparison ignores case: Axon writes ".ABF", and a session
%   folder may hold a mix.

    [folder, ~, extension] = fileparts(filePath);

    if strlength(extension) == 0
        error("nansen:nwb:invalidConverterArg", ...
            ['SourcePathMode "siblingFiles" needs a path with a file ', ...
             'extension to match on, but ''%s'' has none.'], filePath)
    end

    listing = dir(folder);
    listing = listing(~[listing.isdir]);

    names = strings(1, 0);
    if ~isempty(listing)
        names = string({listing.name});
    end
    names = names(endsWith(names, extension, IgnoreCase=true) & ~startsWith(names, "."));

    if isempty(names)
        error("nansen:nwb:missingSourcePath", ...
            ['No %s files were found beside ''%s'', so there is nothing to ', ...
             'hand to NeuroConv. Check that the session folder is reachable.'], ...
            extension, filePath)
    end

    siblingPaths = reshape(string(fullfile(folder, sort(names))), 1, []);
end

function recordedPaths = getRecordedPaths(dataItem)
%getRecordedPaths - Read the paths recorded on a data item

    recordedPaths = strings(1, 0);

    sourceInfo = dataItem.SourceInfo;
    if isfield(sourceInfo, "Path") && ~isempty(sourceInfo.Path)
        recordedPaths = reshape(string(sourceInfo.Path), 1, []);
    end

    recordedPaths = recordedPaths(~ismissing(recordedPaths) & recordedPaths ~= "");
end
