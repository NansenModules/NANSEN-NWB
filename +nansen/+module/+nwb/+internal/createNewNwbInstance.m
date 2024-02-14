function [itemName, itemData] = createNewNwbInstance(items, nwbDataType)

    % Todo. Add onValue changed callback and popup error dialog if provided
    % name already exists when a new item is created (but no if edited...)

    % Todo: 
    % Express function as 
    % [itemName, itemData] = createNewNwbInstance(itemNames, itemData, nwbDataType)
    
    % The figure on top of the stack should be the reference figure.
    f = findall(0, 'type','figure');
    f = f(1);
    referencePosition = f.Position + [40,-40,0,0];

    % Get short name for nwb data type
    nwbShortName = utility.string.getSimpleClassName(nwbDataType);

    % Get the defaults for the current item
    [SOrig, info, isRequired] = nansen.module.nwb.internal.getTypeMetadataStruct(nwbDataType);
    SOrig.name = '';
    isEditing = false;
    actionStr = 'Create new';


    % If the item given as input exist in the catalog, we will edit that
    % item. Otherwise we create a new one.
    catalog = nansen.module.nwb.internal.getMetadataCatalog(nwbDataType);
    if numel(items) == 1 && ischar(items) && catalog.contains(items)
        SOrig = catalog.get(items);
        isEditing = true;
        actionStr = 'Edit';
    end
    
    SOrig = nansen.module.nwb.internal.addLinkedTypeInstances(SOrig, nwbDataType);

    info.name = sprintf('Provide a name for this %s', nwbDataType);
    SOrig = orderfields(SOrig, ['name'; setdiff(fieldnames(SOrig), 'name', 'stable')]); % Put name first.
    
    [S, wasAborted] = tools.editStruct(SOrig, 'all', sprintf('%s %s', actionStr, nwbShortName), ...
        'Prompt', sprintf('Enter details for %s', nwbShortName), ...
        'DataTips', info, ...
        'ReferencePosition', referencePosition, ...
        'ValueChangedFcn', @onValueChanged );
            
    % Preallocate an empty item
    itemName = ''; itemData = feval([nwbDataType, '.empty']);

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
        nvPairs = namedargs2cell(S);
        itemData = feval( nwbDataType, nvPairs{:} );
    end
end

function onValueChanged(src, evt)
    % Todo: Validation of entered values...
    %disp('a')
end