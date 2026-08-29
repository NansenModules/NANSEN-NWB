function dynamicTable = getDynamicTableByName(instanceName)
%getDynamicTableByName - Get a stored dynamic table by instance name
%   dynamicTable = getDynamicTableByName(instanceName) returns the table
%   saved under the given name.
%
%   Only the electrodes table is supported, where the instance name and
%   the neurodata type happen to be the same string. The lookup is by
%   type, so a table whose instance name differs from its type will not
%   be found.
%
%   See also nansen.module.nwb.internal.getMetadataCatalog

    % Todo: Need to generalize this for all dynamic tables and subtypes...
    
    catalog = nansen.module.nwb.internal.getMetadataCatalog(instanceName);
    item = catalog.get(instanceName);
    dynamicTable = item.DynamicTable;
end
