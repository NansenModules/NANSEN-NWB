function metadata = resolveMetadata(metadata, neuroDataType, nwb)

    classInfo = nansen.module.nwb.internal.schemautil.getProcessedClass(neuroDataType);

    links = classInfo.links;

    % Add config field for each of the found links
    for i = 1:numel(links)
        
        linkName = links(i).name;
        linkType = links(i).type; % Note: comes without namespace name, i.e types.core
        linkClassName = "types.core." + linkType;
        
        linkInstanceName = metadata.(linkName);
        catalog = nansen.module.nwb.internal.getMetadataCatalog(linkClassName);
        
        linkedMetadata = catalog.get(linkInstanceName);
        [linkedMetadata, ~] = utility.struct.popfield(linkedMetadata, 'Uuid', false);
        linkedMetadata = nansen.module.nwb.internal.resolveMetadata(linkedMetadata, linkClassName, nwb);
        
        % Create metadata
        name = linkedMetadata.name;
        linkedMetadata = rmfield(linkedMetadata, name);

        nvPairs = namedargs2cell(linkedMetadata);
        nwbType = feval(linkClassName, nvPairs{:});

        nansen.module.nwb.file.addMetadata(nwb, name, nwbType);
        metadata.(linkName) = types.untyped.Softlink(nwbType);
    end

    allFields = fieldnames(metadata);
    subgroups = classInfo.subgroups;
    
    for i = 1:numel(subgroups)
        isMatch = strcmpi(allFields, subgroups(i).type);
        if any(isMatch)
            
            catalog = nansen.module.nwb.internal.getMetadataCatalog("types.core." + subgroups(i).type);
            instanceName = metadata.(lower(subgroups(i).type));
            embeddedMetadata = catalog.get(instanceName);
            [embeddedMetadata, ~] = utility.struct.popfield(embeddedMetadata, 'Uuid', false);
            embeddedMetadata = nansen.module.nwb.internal.resolveMetadata(embeddedMetadata, "types.core." + subgroups(i).type);

            metadata.(lower(subgroups(i).type)) = embeddedMetadata;
        end
    end
end
