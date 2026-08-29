function instanceNames = getMetadataInstanceNames(neuroDataType)
%getMetadataInstanceNames - Get names of stored instances of a neurodata type
%
%   instanceNames = getMetadataInstanceNames(neuroDataType) returns the
%   names under which instances of the given neurodata type are stored in
%   the project's metadata catalog. Use getMetadataInstance to retrieve one
%   of them.
%
%   See also: nansen.module.nwb.internal.getMetadataInstance

    catalog = nansen.module.nwb.internal.getMetadataCatalog(neuroDataType);

    % Todo: Specify name property.
    instanceNames = catalog.ItemNames;
end
