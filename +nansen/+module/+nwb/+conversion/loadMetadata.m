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
            
            typeMetadata = metadata.(nwbType);
            
            % Todo: Need a convention for named instances...
            if numel(typeMetadata) && isfield(typeMetadata, 'name')
                isMatch = strcmp({typeMetadata.name}, options.Name);
                typeMetadata = typeMetadata(isMatch);
                typeMetadata = rmfield(typeMetadata, 'name');
            end

            metadataNameValuePairs = namedargs2cell(typeMetadata);
        else
            return
        end
    end
end
