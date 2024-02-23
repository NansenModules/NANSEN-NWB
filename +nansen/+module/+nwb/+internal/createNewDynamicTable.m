function [itemName, itemData] = createNewDynamicTable(items, nwbNodeStack)

    % Note: work in progress. This function is currently only tested for
    % the electrodes table. Should be generalized to work for all dynmic
    % tables, and also allow creation of arbitrary dynamic tables, i.e not
    % just those that are defined in the nwb file schema (see
    % getDynamicTableForRegionView)

    arguments
        items (1,:) string % Currently noy used. 
        nwbNodeStack (1,:) nansen.module.nwb.internal.NwbNode
    end

    import nansen.module.nwb.internal.lookup.getDynamicTableForRegionView
    import nansen.module.nwb.internal.lookup.getFullTypeName

    isEditing = false; % todo: support editing?

    nwbDataType = nwbNodeStack.PropertyTypeFullName;
    %nwbShortName = nwbNodeStack.PropertyType;
    %ancestorType = nwbNodeStack.DefiningType;

    %linkedTableName='SimultaneousRecordingsTable'
    %linkedTableName='PlaneSegmentation'

    % Use a lookup function to figure out if a special table is going to be created.
    ancestorNeuroDataType = nwbNodeStack(end-1).DefiningType;
    ancestorPropertyName = nwbNodeStack(end-1).PropertyName;
    linkedTableName = getDynamicTableForRegionView(ancestorNeuroDataType, ancestorPropertyName);

    % Initialize the table
    if strcmp(linkedTableName, 'ElectrodesTable')
        dynamicTable = nansen.module.nwb.internal.dtable.initializeElectrodesTable();
    else
        % Todo: Need an initializer cuz this just creates empty tables...
        error('Not implemented yet')
        fullLinkedTableType = getFullTypeName(linkedTableName);
        dynamicTable = feval(fullLinkedTableType);
        dynamicTable = dynamicTable.toTable();

        % Todo: Is there any case where we just need to create a generic
        % dynamic table???
    end

    % Open the table in the UIDynamicTable
    [h, data] = nansen.module.nwb.gui.UICreateDynamicTable(dynamicTable);
        
    % The figure on top of the stack should be the reference figure.
    f = findall(0, 'type','figure'); f = f(1);
    referencePosition = f.Position + [40,-40,0,0];

    % Place the newly created figure according to the reference figure
    uim.utility.layout.centerObjectInRectangle(h.Figure, referencePosition)

    % Todo: Enter name somehow...?

    uiwait(h)

    % Preallocate an empty item
    nwbDataType = 'matnwb.types.hdmf_common.DynamicTable';
    itemName = ''; itemData = feval(sprintf('%s.empty', nwbDataType));

    if isKey(data, 'State')
        % Save to table to a catalog when user hit save!
        if strcmp( data('State'), "Saved" )
            %newTable = data('Table');
            itemName = linkedTableName;
            itemData = data('Table');

            S = struct; 
            S.name = linkedTableName;
            S.DynamicTable = itemData;

            catalog = nansen.module.nwb.internal.getMetadataCatalog(linkedTableName);
    
            % Remove config fields.
            S = utility.struct.removeConfigFields(S);
    
            if isEditing
                catalog.replace(S)
            else
                catalog.add(S)
            end
            catalog.save()
    
            %itemName = S.name;
        end
    end

    % Update NWB Configurator somehow,

    if nargout == 1
        clear itemData
        %S = rmfield(S, "name");
        %nvPairs = namedargs2cell(S);
        %itemData = feval( nwbDataType, nvPairs{:} );
    end
end
