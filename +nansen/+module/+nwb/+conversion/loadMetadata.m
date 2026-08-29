function metadataNameValuePairs = loadMetadata(nwbType, options)
%loadMetadata - Load stored metadata for a neurodata type
%   metadataNameValuePairs = loadMetadata(nwbType) returns the metadata
%   recorded for the given neurodata type in the current project, as a
%   cell array ready to expand into a constructor call. It returns an
%   empty cell array when the project has no metadata file.
%
%   metadataNameValuePairs = loadMetadata(...,Name=VALUE) selects one
%   named instance, for a type that has more than one.
%
%   Metadata is read from a single JSON file in the project's nwb
%   metadata folder. More than one file is not supported and warns.
%
%   See also nansen.module.nwb.internal.getMetadataInstance
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
