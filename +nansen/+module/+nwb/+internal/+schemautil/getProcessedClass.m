function [processedClass, propertyInfo] = getProcessedClass(className)

    % Generated nodes and props for faster dependency resolution. Keyed by
    % namespace, because a type is only resolvable from the namespace that
    % defines it and the cache would otherwise be shared across them.
    persistent pregeneratedByNamespace
    if isempty(pregeneratedByNamespace)
        pregeneratedByNamespace = containers.Map;
    end

    namespaceName = getNamespaceName(className);
    className = utility.string.getSimpleClassName(className);

    if ~isKey(pregeneratedByNamespace, namespaceName)
        pregeneratedByNamespace(namespaceName) = containers.Map;
    end
    pregenerated = pregeneratedByNamespace(namespaceName);

    nwbSourceDir = misc.getMatnwbDir();
    Namespace = schemes.loadNamespace(namespaceName, nwbSourceDir);

    [processedClassHierarchy, ~, ~] = file.processClass(className, Namespace, pregenerated);

    if isa(processedClassHierarchy, 'file.Group')
        % Get all groups, datasets, attributes and links
        % Concatenate down, as the sibling fields below do. Classes in the
        % hierarchy report differently shaped subgroup arrays, so a
        % horizontal concatenation fails whenever one of them holds more
        % than a single subgroup.
        subgroups = cat(1, processedClassHierarchy.subgroups);
        attributes = cat(1, processedClassHierarchy.attributes);
        datasets = mergeDatasets( cat(1, processedClassHierarchy.datasets) );
        links = cat(1, processedClassHierarchy.links);
    
        % Create a struct where different elements across class hierarchy
        % are added...
    
        processedClass = struct();
        processedClass.type = processedClassHierarchy(1).type;
        processedClass.attributes = attributes;
        processedClass.datasets = datasets;
        processedClass.subgroups = subgroups;
        processedClass.links = links;

    elseif isa(processedClassHierarchy, 'file.Dataset')
        
        dataset = mergeDatasets(processedClassHierarchy);

        processedClass = struct();
        processedClass.type = processedClassHierarchy(1).type;
        processedClass.attributes = dataset.attributes;
        processedClass.datasets = [];%mergeDatasets( cat(1, processedClassHierarchy.datasets) );
        processedClass.subgroups = [];
        processedClass.links = [];
        % links = cat(1, processedClassHierarchy.links);
    end

    % Extract propertyInfo
    propertyInfo = struct('name', {}, 'readonly', {});
    tmpPropertyInfo = propertyInfo;

    for i = 1:numel(  processedClass.attributes )
        tmpPropertyInfo(1).name = processedClass.attributes(i).name;
        tmpPropertyInfo(1).readonly = processedClass.attributes(i).readonly;
        propertyInfo(end+1) = tmpPropertyInfo; %#ok<*AGROW>
    end
    for i = 1:numel(  processedClass.datasets )
        tmpPropertyInfo(1).name = processedClass.datasets(i).name;
        tmpPropertyInfo(1).readonly = false;
        propertyInfo(end+1) = tmpPropertyInfo;
        for j = 1:numel( processedClass.datasets(i).attributes )
            attributeName = processedClass.datasets(i).attributes(j).name;
            tmpPropertyInfo.name = sprintf('%s_%s', processedClass.datasets(i).name, attributeName);
            tmpPropertyInfo.readonly = processedClass.datasets(i).attributes(j).readonly;
            propertyInfo(end+1) = tmpPropertyInfo;
        end
    end
end

function mergedDatasets = mergeDatasets(datasets)

    % This class merges entities from top in hierarchy to bottom.
    
    if isempty(datasets)
        mergedDatasets = datasets; return
    end

    % Entities are ordered from bottom to top in class hierarhy, i.e the
    % most specific class is first, and the highest level superclass is last.
    if iscolumn(datasets)
        datasets = flipud(datasets);
    elseif isrow(datasets)
        datasets = fliplr(datasets);
    end

    mergedDatasets = datasets(1);

    for i = 2:numel(datasets)
        thisDataset = datasets(i);

        if any( strcmp({mergedDatasets.name}, thisDataset.name ) )
            isSame = strcmp({mergedDatasets.name}, thisDataset.name );
            
            referenceDataset = mergedDatasets(isSame);
            
            mergedAttributes = mergeAttributes(thisDataset.attributes, referenceDataset.attributes);
            thisDataset.attributes = mergedAttributes;
            
            mergedDatasets(isSame) = thisDataset;
        else
            mergedDatasets(end+1) = thisDataset;
        end
    end

    if iscolumn(datasets)
        mergedDatasets = reshape(mergedDatasets, [], 1);
    elseif isrow(datasets)
        mergedDatasets = reshape(mergedDatasets, 1, []);
    end
end

function mergedAttributes = mergeAttributes(attributesChild, attributesParent)
    
    if isempty(attributesParent)
        mergedAttributes = attributesChild;
        return
    else
        mergedAttributes = attributesParent;
    end

    if isempty(attributesChild); return; end

    attributeNamesParent = {attributesParent.name};
    attributeNamesChild = {attributesChild.name};

    [~, iA, iC] = intersect(attributeNamesParent, attributeNamesChild);
    
    mergedAttributes(iA) = attributesChild(iC);

    % Todo: Also add attributes which are unique to the child...
    [~, isUniqueToChild] = setdiff(attributeNamesChild, attributeNamesParent);

    % The parent and child attribute arrays do not share an orientation, so
    % normalize both to columns before concatenating. Appending along the
    % row otherwise fails whenever the two differ in height.
    mergedAttributes = cat(1, ...
        reshape(mergedAttributes, [], 1), ...
        reshape(attributesChild(isUniqueToChild), [], 1));
end

function namespaceName = getNamespaceName(className)
% getNamespaceName - Resolve which NWB namespace defines a type
%
%   A namespace only resolves the types it defines and those of the
%   namespaces it depends on. core reaches hdmf-common but not
%   hdmf-experimental, so the namespace cannot be assumed and is derived
%   from the type's fully qualified name instead.

    className = string(className);

    if ~startsWith(className, "types.")
        try
            className = string( nansen.module.nwb.internal.lookup ...
                .getFullTypeName( utility.string.getSimpleClassName(char(className)) ) );
        catch
            error('nansen:nwb:unknownNeurodataType', ...
                ['Neurodata type "%s" was not found in the NWB schema. ', ...
                 'Provide the name of a type from the loaded NWB namespaces, ', ...
                 'for example "TimeSeries" or "types.core.TimeSeries".'], className)
        end
    end

    % types.<namespace>.<TypeName>. The schema files name the namespace with
    % a hyphen where the generated package uses an underscore.
    nameParts = split(className, ".");
    namespaceName = char( replace(nameParts(2), "_", "-") );
end
