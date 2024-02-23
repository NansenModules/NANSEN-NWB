function [metadata, instanceMap] = resolveMetadata(metadata, neuroDataType, nwbFile, instanceMap)

    import nansen.module.nwb.internal.lookup.getFullTypeName

    if ~isempty(metadata)
        metadata = utility.struct.removeConfigFields(metadata);
        metadata = structfun(@categorical2char, metadata, 'UniformOutput', 0);
        metadata = applyCustomModifications(metadata, neuroDataType);
    end

    % Get processed class info (i.e schema details) for the current neurodata type
    classInfo = nansen.module.nwb.internal.schemautil.getProcessedClass(neuroDataType);
    links = classInfo.links;

    % Add instances for links
    for i = 1:numel(links)
        
        linkName = links(i).name;
        linkType = links(i).type; % Note: comes without namespace name, i.e types.core
        linkClassName = getFullTypeName( linkType );
        
        linkInstanceName = metadata.(linkName);

        if isempty(linkInstanceName)
            warning('No link provided for %s of %s', linkType, neuroDataType)
            continue
        end

        if isConfigured(instanceMap) && isKey(instanceMap, linkInstanceName)
            nwbType = instanceMap{linkInstanceName};
        
        else
            % Get the instance data
            linkedMetadata = ...
                nansen.module.nwb.internal.getMetadataInstance(...
                    linkInstanceName, linkClassName);

            % Resolve the metadata, i.e resolve recursively
            [linkedMetadata, instanceMap] = ...
                nansen.module.nwb.internal.resolveMetadata(...
                    linkedMetadata, linkClassName, nwbFile, instanceMap);
            
            % Create metadata and add it to the instance map
            name = linkedMetadata.name;
            nwbType = nansen.module.nwb.internal.structToNwbType(linkedMetadata, linkClassName);
            instanceMap(linkInstanceName) = {nwbType};

            if ~isempty(nwbFile)
                nansen.module.nwb.file.addMetadata(nwbFile, name, nwbType);
            end
        end
        
        metadata.(linkName) = feval(getFullTypeName('SoftLink'), nwbType);
    end

    allFields = fieldnames(metadata);
    subgroups = classInfo.subgroups;
    
    % Why is the subgroup not converted to an nwb type?
    for i = 1:numel(subgroups)
        isMatch = strcmpi(allFields, subgroups(i).type);
        if any(isMatch)
                       
            nwbType = getFullTypeName(subgroups(i).type);
            instanceName = metadata.(lower(subgroups(i).type));

            catalog = nansen.module.nwb.internal.getMetadataCatalog( nwbType );
            embeddedMetadata = catalog.get(instanceName);
            [embeddedMetadata, ~] = utility.struct.popfield(embeddedMetadata, 'Uuid', false);
            
            [embeddedMetadata, instanceMap] = ...
                nansen.module.nwb.internal.resolveMetadata(...
                    embeddedMetadata, nwbType, nwbFile, instanceMap);

            metadata.(lower(subgroups(i).type)) = embeddedMetadata;
        end
    end

    if ~isempty(classInfo.datasets)
        
        datasetTypes = {classInfo.datasets.type};
        isTyped = cellfun(@(c) ~isempty(c), datasetTypes);
        typedDatasets = classInfo.datasets(isTyped);
        
        for i = 1:numel(typedDatasets)

            nwbType =  getFullTypeName(typedDatasets(i).type);
            instanceName = metadata.(typedDatasets(i).name);

            % Get the instance data
            embeddedMetadata = ...
                nansen.module.nwb.internal.getMetadataInstance(...
                    instanceName, nwbType);

            % Resolve the metadata, i.e resolve recursively
            [embeddedMetadata, instanceMap] = ...
                nansen.module.nwb.internal.resolveMetadata(...
                    embeddedMetadata, nwbType, nwbFile, instanceMap);

            [embeddedMetadata, ~] = utility.struct.popfield(embeddedMetadata, 'name');
    
            nvPairs = namedargs2cell(embeddedMetadata);
            embeddedMetadata = feval(nwbType, nvPairs{:});

            metadata.(typedDatasets(i).name) = embeddedMetadata;
        end
    end
    
    if ~isempty(classInfo.attributes)
        dataTypes = {classInfo.attributes.dtype};
        isTyped = cellfun(@(c) isa(c, 'containers.Map'), dataTypes);
        
        typedAttributes = classInfo.attributes(isTyped);
        for i = 1:numel(typedAttributes)
           
            assert(strcmp(typedAttributes(i).dtype('reftype'), 'object'), ...
                'Expected object') 

            %targetType = typedAttributes(i).dtype('target_type');
           
            if contains(neuroDataType, 'DynamicTableRegion') % Or if targetType is DynamicTable
                
                instanceName = metadata.( typedAttributes(i).name );

                if isConfigured(instanceMap) && isKey(instanceMap, instanceName)
                    nwbType = instanceMap{instanceName};
                else
                    dynamicTable = nansen.module.nwb.internal.getDynamicTableByName(instanceName);
                    if strcmp(instanceName, 'ElectrodesTable')
                        dynamicTable = convertElectrodeGroups(dynamicTable, nwbFile, instanceMap);
                    end
                    %matnwb.types.untyped.ObjectView(EGroup)

                    nwbType = matnwb.util.table2nwb(dynamicTable);
                
                    if ~isempty(nwbFile)
                        nansen.module.nwb.file.addMetadata(nwbFile, instanceName, nwbType);
                    end
                end
            else
                error('Unhandled type')
            end

            metadata.( typedAttributes(i).name ) = matnwb.types.untyped.ObjectView(nwbType);
        end
    end
end

function v = categorical2char(v)
    if iscategorical(v)
        v = char(v);
    end
end

function metadata = applyCustomModifications(metadata, neuroDataType)

    if contains(neuroDataType, 'DynamicTableRegion')
        metadata.data = cell2mat(metadata.data); % - 1 Todo: do this here
    end
end

function [dynamicTable, instanceMap] = convertElectrodeGroups(dynamicTable, nwbFile, instanceMap)
    %electrodeGroups = dynamicTable.group;
    
    % Note: Electrode groups are stored both in this table and in a
    % metadata instance catalog. For now, we use the instances from the
    % table and not the catalog. Not sure what is the best long term
    % solution...
    % Note2: Would be great to generalize the conversion of dynamic tables
    % with object references...

    groupName = dynamicTable.group_name;

    nwbType = 'matnwb.types.core.ElectrodeGroup';
    catalog = nansen.module.nwb.internal.getMetadataCatalog(nwbType);
    
    objectViews = cell(size(groupName));

    for i = 1:numel(groupName)
        if ismissing(groupName(i))
            iGroupName = sprintf('Electrode %03d', i);
            % Todo: Error...
        else
            iGroupName = groupName(i);
        end
        
        iElectrodeGroup = catalog.get(iGroupName);
        [iElectrodeGroup, instanceMap] = ...
            nansen.module.nwb.internal.resolveMetadata(...
                iElectrodeGroup, nwbType, nwbFile, instanceMap);

        % Todo: Need to do this more consistently in one place...
        [iElectrodeGroup, ~] = utility.struct.popfield(iElectrodeGroup, 'Uuid', false);    
        [iElectrodeGroup, ~] = utility.struct.popfield(iElectrodeGroup, 'name', false);    

        nvPairs = namedargs2cell(iElectrodeGroup);
        iElectrodeGroup = feval(nwbType, nvPairs{:}); %#ok<FVAL>

        nwbFile.general_extracellular_ephys.set(iGroupName, iElectrodeGroup);
        %nansen.module.nwb.file.addMetadata(nwbFile, iGroupName, iElectrodeGroup);

        objectViews{i} =  matnwb.types.untyped.ObjectView( iElectrodeGroup );
    end

    dynamicTable.group = cat(1, objectViews{:});
end
