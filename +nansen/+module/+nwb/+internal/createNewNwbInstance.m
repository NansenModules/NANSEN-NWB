function [itemName, itemData] = createNewNwbInstance(items, nwbNodeStack, options)

    % Todo. Add onValue changed callback and popup error dialog if provided
    % name already exists when a new item is created (but no if edited...)

    % Todo: 
    % Express function as 
    % [itemName, itemData] = createNewNwbInstance(itemNames, itemData, nwbDataType)
     
    arguments
        items (1,:) string %??
        nwbNodeStack (1,:) nansen.module.nwb.internal.NwbNode
        options.IsEditing (1,1) logical = false
    end

    import nansen.module.nwb.internal.appendDropdownOptions
    import nansen.module.nwb.internal.appendTableDropdownOptions
    
    isEditing = options.IsEditing;

    nwbDataType = nwbNodeStack(end).PropertyTypeFullName;
    nwbShortName = nwbNodeStack(end).PropertyType;
    %ancestorType = nwbNodeStack(end).DefiningType;


    % The figure on top of the stack should be the reference figure.
    f = findall(0, 'type','figure'); f = f(1);
    referencePosition = f.Position + [40,-40,0,0];


    % % Should be separate method (initializeNwbInstanceForm)
    % Get the defaults for the current item
    [SOrig, info, isRequired] = nansen.module.nwb.internal.getTypeMetadataStruct(nwbDataType);
    SOrig.name = '';

    actionStr = 'Create new';

    % If the item given as input exist in the catalog, we will edit that
    % item. Otherwise we create a new one.
    catalog = nansen.module.nwb.internal.getMetadataCatalog(nwbDataType);

    % This does not work if there was only one item in the list!!!

    % if numel(items) == 1 && isstring(items) && catalog.contains(items)
    
    if isEditing
        SOrig = catalog.get(items);
        SOrig.Uuid_ = 'internal';
        actionStr = 'Edit';
    end
    
    SOrig = nansen.module.nwb.internal.addLinkedTypeInstances(SOrig, nwbDataType, nwbNodeStack);

    % This is so custom that it is added manually
    if strcmp(nwbDataType, "matnwb.types.hdmf_common.DynamicTableRegion")
        nwbNode = nansen.module.nwb.internal.NwbNode(...
                'table', 'ObjectView', nwbDataType);
        SOrig = appendTableDropdownOptions(SOrig, [nwbNodeStack, nwbNode]);
        if isempty(SOrig.data);SOrig.data={[]}; end
        SOrig.data_ = @(S, nodes) nansen.module.nwb.internal.uiSelectTableRegion(S, [nwbNodeStack, nwbNode]);
        % Note: The data is initialized as a cell array with an empty
        % numeric. This is a customization which is necessary for the
        % structeditor. Having it as a cell array will render this field
        % ans an input where values are entered asa space separated list. 
        % The data needs to be converted to a numeric vector when creating
        % the DynamicTableRegion neurodata type.
    end

    info.name = sprintf('Provide a name for this %s', nwbDataType);
    SOrig = orderfields(SOrig, ['name'; setdiff(fieldnames(SOrig), 'name', 'stable')]); % Put name first.
    
    [S, wasAborted] = tools.editStruct(SOrig, 'all', sprintf('%s %s', actionStr, nwbShortName), ...
        'Prompt', sprintf('Enter details for %s', nwbShortName), ...
        'DataTips', info, ...
        'ReferencePosition', referencePosition, ...
        'ValueChangedFcn', @onValueChanged );
            
    % Preallocate an empty item
    itemName = ''; itemData = feval(sprintf('%s.empty', nwbDataType));

    if ~wasAborted
        % Save to persistent catalog.
        if isempty(S.name)
            errordlg('Name must be filled in')
            return
        end

        catalog = nansen.module.nwb.internal.getMetadataCatalog(nwbDataType);
        
        % Remove config fields.
        S = utility.struct.removeConfigFields(S);

        if isEditing
            catalog.replace(S)
        else
            catalog.add(S)
        end
        catalog.save()

        itemName = S.name;
    end

    if nargout == 2
        S = rmfield(S, "name");
        
        [S, ~] = ...
            nansen.module.nwb.internal.resolveMetadata(...
                S, nwbDataType, [], dictionary);

        nvPairs = namedargs2cell(S);
        itemData = feval( nwbDataType, nvPairs{:} );
    end
end

function onValueChanged(src, evt)
    % Todo: Validation of entered values...
end