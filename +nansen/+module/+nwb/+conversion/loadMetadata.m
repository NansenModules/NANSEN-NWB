function metadataNameValuePairs = loadMetadata(nwbType, options)
    arguments
        nwbType
        options.Name % If there are many instances for one type...
    end
    metadataNameValuePairs = {};
    
    project = nansen.getCurrentProject();
    metadataFolder = project.getMetadataFolder('nwb');
    
    L = dir(fullfile(metadataFolder, '*.json'));
    if ~isempty(L)
        filePath = fullfile({L.folder}, {L.name});
        if numel(filePath) > 1
            warning('Multiple metadata files are not supported')
        end

        metadata = jsondecode( fileread(filePath{1}) );

        if isfield(metadata, nwbType)
            % Todo: Check if there are named instances... 
            % Todo: Need a convention for named instances...
            metadataNameValuePairs = namedargs2cell(metadata.(nwbType));
        else
            return
        end
    end
end
