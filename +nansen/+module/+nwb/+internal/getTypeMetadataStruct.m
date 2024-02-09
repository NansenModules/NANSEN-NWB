function [S, info, isRequired] = getTypeMetadataStruct(typeName)
% getTypeMetadataStruct - Get a struct of metadata for a neurodata type
%
%   This class removes non-settable properties and data-properties from the
%   list of properties associated with a neurodata type, returning only
%   properties considered metadata.

    import nansen.module.nwb.internal.addLinkedTypeInstances
    import nansen.module.nwb.internal.lookup.getDeprecatedPropertyNames

    persistent dataPropertyMap customPropertyMap
    if isempty(dataPropertyMap)
        dataPropertyMap = nansen.module.nwb.internal.dataPropertyLookupMap();
    end
    if isempty(customPropertyMap)
        customPropertyMap = nansen.module.nwb.internal.customPropertyLookupMap();
    end

    %typeName = 'types.core.RoiResponseSeries';

    mc = meta.class.fromName(typeName);
    typeShortName = utility.string.getSimpleClassName(typeName);

    propertyList = mc.PropertyList;

    % Skip properties with non-public set access
    isEditable = string({propertyList.SetAccess}) == "public";
    isHidden = [propertyList.Hidden];
    propertyList = propertyList(isEditable & ~isHidden);

    numProperties = numel( propertyList );

    defaultType = feval(typeName);

    [classInfo, propInfo] = nansen.module.nwb.internal.schemautil.getProcessedClass(typeName);
    if ~isempty(classInfo.links)
        linkNames = {classInfo.links.name};
    else
        linkNames = {''};
    end
    
    isReadOnly = [propInfo.readonly];
    readOnlyPropNames = {propInfo(isReadOnly).name};

    deprecatedProperties = getDeprecatedPropertyNames();

    [S, info, isRequired] = deal( struct );
    for i = 1:numProperties

        thisPropertyName = propertyList(i).Name;
        outPropertyName = thisPropertyName;

        % Ignore deprecated properties
        if any( strcmp(deprecatedProperties, thisPropertyName) )
            continue
        end

        % Ignore readonly properties
        if any( strcmp(readOnlyPropNames, thisPropertyName) )
            continue
        end

        % Get the defining class.
        definingClass = propertyList(i).DefiningClass.Name;
        
        % Check lookup table if property should be ignored.
        definingClassShortName = utility.string.getSimpleClassName(definingClass);
        if isfield(dataPropertyMap, definingClassShortName)
            if any(strcmp(dataPropertyMap.(definingClassShortName), thisPropertyName))
                continue
            end
        end

        propertyDescription = propertyList(i).Description;
        if contains(propertyDescription, 'DEPRECATED')
            continue
        end

        isRequired.(outPropertyName) = strncmp(propertyList(i).Description, 'REQUIRED', 8);
        
        isLink = strcmp(linkNames, thisPropertyName);
        if any(isLink)
            % Linked types have poor documnetation in the meta class...
            info.(outPropertyName) = cleanDescription( classInfo.links(isLink).doc );
        else
            info.(outPropertyName) = cleanDescription( propertyDescription );
        end
        
        % Check if there are any customizations based on this class
        if isfield(customPropertyMap, typeShortName)
            if isfield(customPropertyMap.(typeShortName), thisPropertyName)
                S.(outPropertyName) = customPropertyMap.(typeShortName).(thisPropertyName);
                continue
            end
        end
    
        % Check if there are any customizations based on the defining class (could be superclass)
        if ~strcmp(typeShortName, definingClassShortName)
            if isfield(customPropertyMap, definingClassShortName)
                if isfield(customPropertyMap.(definingClassShortName), thisPropertyName)
                    S.(outPropertyName) = customPropertyMap.(definingClassShortName).(thisPropertyName);
                    continue
                end
            end
        end

        S.(outPropertyName) = defaultType.(thisPropertyName);
    end

    S = postprocessStruct(S);
end

function S = postprocessStruct(S)

    propertyNames = fieldnames(S);
    for i = 1:numel(propertyNames)
        thisPropertyName = propertyNames{i};
        thisPropertyValue = S.(thisPropertyName);

        switch class(thisPropertyValue)
            case 'categorical'
                configPropertyName = sprintf('%s_', thisPropertyName); 
                S.(thisPropertyName) = char(thisPropertyValue);
                S.(configPropertyName) = categories(thisPropertyValue)';
        end
    end
end

function str = cleanDescription(str)
    str = strrep(str, 'REQUIRED ', '');

    % Regular expression pattern to match a word enclosed in parentheses at the beginning
    pattern = '^\((\w+)\)\s*';
    
    % Use regexprep to remove the matched pattern from the input string
    str = regexprep(str, pattern, '');
end