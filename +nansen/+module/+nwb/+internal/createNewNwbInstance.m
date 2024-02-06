function item = createNewNwbInstance(items, nwbDataType)

    % The figure on top of the stack should be the reference figure.
    f = findall(0, 'type','figure');
    f = f(1);
    referencePosition = f.Position + [40,-40,0,0];

    % Get short name for nwb data type
    nwbShortName = utility.string.getSimpleClassName(nwbDataType);

    % Todo. Add onValue changed callback and popup error dialog if provided
    % name already exists...

    [S, info, isRequired] = nansen.module.nwb.internal.getTypeMetadataStruct(nwbDataType);
    
    S = nansen.module.nwb.internal.addLinkedTypeInstances(S, nwbDataType);

    S.name = '';
    info.name = sprintf('Provide a name for this %s', nwbDataType);
    S = orderfields(S, ['name'; setdiff(fieldnames(S), 'name', 'stable')]); % Put name first.
    
    [S, wasAborted] = tools.editStruct(S, 'all', sprintf('Create new %s', nwbShortName), ...
        'Prompt', sprintf('Enter details for %s', nwbShortName), ...
        'DataTips', info, ...
        'ReferencePosition', referencePosition, ...
        'ValueChangedFcn', @onValueChanged );
            
    % Preallocate an empty item
    item = '';

    if ~wasAborted
        % Save to persistent catalog.
        if isempty(S.name)
            errordlg('Name must be filled in')
            return
        end

        catalog = nansen.module.nwb.internal.getMetadataCatalog(nwbDataType);

        % todo: remove config fields...
        catalog.add(S)
        catalog.save()

        % Todo: update table
        item = S.name;
    end
end

function onValueChanged(src, evt)
    % Todo: Validation of entered values...
    %disp('a')
end