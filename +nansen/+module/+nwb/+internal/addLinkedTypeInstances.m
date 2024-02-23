function S = addLinkedTypeInstances(S, neuroDataType, nwbNodeStack)
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
%   - nwbNodeStack: stack of NWB nodes, used when creating nested instances
%
%   Output:
%   - S: Updated structure with linked type config fields added.
%
%   See also: structeditor.App

    arguments
        S (1,1) struct
        neuroDataType (1,1) string
        nwbNodeStack (1,:) nansen.module.nwb.internal.NwbNode = nansen.module.nwb.internal.NwbNode.empty
    end

    import nansen.module.nwb.internal.appendDropdownOptions

    % Gets class info for specific neurodata type.
    classInfo = nansen.module.nwb.internal.schemautil.getProcessedClass(neuroDataType);

    links = classInfo.links;

    % Add config field for each of the found links
    for i = 1:numel(links)
        
        linkName = links(i).name;
        linkType = links(i).type; % Note: comes without namespace name, i.e types.core
        nwbNode = nansen.module.nwb.internal.NwbNode(linkName, linkType);
        S = appendDropdownOptions(S, [nwbNodeStack, nwbNode]);
    end

    allFields = fieldnames(S);
    subgroups = classInfo.subgroups;
    for i = 1:numel(subgroups)
        isMatch = strcmpi(allFields, subgroups(i).type);
        if any(isMatch)
            nwbNode = nansen.module.nwb.internal.NwbNode(...
                lower(subgroups(i).type), subgroups(i).type);

            S = appendDropdownOptions(S, [nwbNodeStack, nwbNode]);
            
            if isa(S.(lower(subgroups(i).type)), 'types.untyped.Set') || isa(S.(lower(subgroups(i).type)), 'matnwb.types.untyped.Set')
                % This is an internal nwb type and the value needs to 
                % initialized to a char in order to correctly render in the
                % struct editor
                S.(lower(subgroups(i).type)) = '';
            end
        end
    end

    if ~isempty(classInfo.datasets)
        datasetTypes = {classInfo.datasets.type};
        isTyped = cellfun(@(c) ~isempty(c), datasetTypes);
        typedDatasets = classInfo.datasets(isTyped);
        
        for i = 1:numel(typedDatasets)
            nwbNode = nansen.module.nwb.internal.NwbNode(...
                typedDatasets(i).name, typedDatasets(i).type, neuroDataType);

            S = appendDropdownOptions(S, [nwbNodeStack, nwbNode]);
        end
    end

    if ~isempty(classInfo.attributes)
        dataTypes = {classInfo.attributes.dtype};
        isTyped = cellfun(@(c) isa(c, 'containers.Map'), dataTypes);
        
        typedAttributes = classInfo.attributes(isTyped);
        for i = 1:numel(typedAttributes)
            assert(strcmp(typedAttributes(i).dtype('reftype'), 'object'), ...
                'Expected object') 
            
            dataType = typedAttributes(i).dtype('target_type');
                       
            nwbNode = nansen.module.nwb.internal.NwbNode(...
                typedAttributes(i).name, dataType, neuroDataType);

            S = appendDropdownOptions(S, [nwbNodeStack, nwbNode]);
        end
    end
end
