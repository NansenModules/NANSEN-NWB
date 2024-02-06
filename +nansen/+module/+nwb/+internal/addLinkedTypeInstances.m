function S = addLinkedTypeInstances(S, neuroDataType)
% addLinkedTypeInstances - Add linked type instances to a metadata structure.
%
%   This function adds "config" fields for linked types of an NWB metadata
%   structure. Each of the config fields will be a cell array of known instance
%   names of the corresponding type, as well as a structure with
%   specifications for creating a new instance. The purpose of the "config"
%   field is that the input field for the linked type will be a dropdown
%   control where users can select instances by name or select an option to
%   create a new instance when the struct is passed to the structeditor
%   app
%
%   S = addLinkedTypeInstances(S, neuroDataType) adds config fields for 
%   instances of linked types to the structure S based on the provided 
%   neuroDataType. It populates S with dropdown configurations for 
%   each linked type instance, facilitating the creation of new instances.
%
%   Inputs:
%   - S: Structure to which linked type config fields will be added.
%   - neuroDataType: The type of neuro data (NWB) for which linked type 
%     instances need to be added.
%
%   Output:
%   - S: Updated structure with linked type config fields added.
%
%   See also: getMetadataInstances, createNewNwbInstance, structeditor.App
    
    import nansen.module.nwb.internal.getMetadataInstances
    import nansen.module.nwb.internal.createNewNwbInstance
    import nansen.module.nwb.internal.appendDropdownOptions

    % Gets class info for specific neurodata type.
    classInfo = nansen.module.nwb.internal.schemautil.getProcessedClass(neuroDataType);

    links = classInfo.links;

    % Add config field for each of the found links
    for i = 1:numel(links)
        
        linkName = links(i).name;
        linkType = links(i).type; % Note: comes without namespace name, i.e types.core

        S = appendDropdownOptions(S, linkName, linkType);
    end

    allFields = fieldnames(S);
    subgroups = classInfo.subgroups;
    for i = 1:numel(subgroups)
        isMatch = strcmpi(allFields, subgroups(i).type);
        if any(isMatch)
            S = appendDropdownOptions(S, lower(subgroups(i).type), subgroups(i).type);
            S.(lower(subgroups(i).type)) = '';
        end
    end
end
