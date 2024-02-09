function [processedClass, propertyInfo] = getProcessedClass(className)

    persistent pregenerated
    if isempty(pregenerated)
        %generated nodes and props for faster dependency resolution
        pregenerated = containers.Map; 
    end

    className = utility.string.getSimpleClassName(className);
    
    nwbSourceDir = misc.getMatnwbDir();
    namespaceName = 'core';
    Namespace = schemes.loadNamespace(namespaceName, nwbSourceDir);
    
    [processedClassHierarchy, classprops, inherited] = file.processClass(className, Namespace, pregenerated);
    
    if isa(processedClassHierarchy, 'file.Group')
        % Get all groups, datasets, attributes and links
        subgroups = [processedClassHierarchy.subgroups];
        attributes = cat(1, processedClassHierarchy.attributes);
        datasets = mergeDatasets( cat(1, processedClassHierarchy.datasets) );
        links = cat(1, processedClassHierarchy.links);
    
    
        %processedClassHierarchy(1)
        % Create a struct where different constituents across class hierarchy
        % are added...
    
        processedClass = struct();
        processedClass.type = processedClassHierarchy(1).type;
        processedClass.attributes = attributes;
        processedClass.datasets = datasets;
        processedClass.subgroups = subgroups;
        processedClass.links = links;
        

    elseif isa(processedClassHierarchy, 'file.Dataset')
        
        processedClass = struct();
        processedClass.type = processedClassHierarchy(1).type;
        processedClass.attributes = cat(1, processedClassHierarchy.attributes);
        processedClass.datasets = [];%mergeDatasets( cat(1, processedClassHierarchy.datasets) );
        processedClass.subgroups = [];
        processedClass.links = [];
        %links = cat(1, processedClassHierarchy.links);
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
            mergedDatasets(end+1) = thisDataset; %#ok<AGROW>
        end
    end

    if iscolumn(datasets)
        mergedDatasets = reshape(mergedDatasets, [], 1);
    elseif isrow(datasets)
        mergedDatasets = reshape(mergedDatasets, 1, []);
    end
end

function mergedAttributes = mergeAttributes(attributesChild, attributesParent)
    
    mergedAttributes = attributesParent;

    if isempty(attributesChild); return; end

    attributeNamesParent = {attributesParent.name};
    attributeNamesChild = {attributesChild.name};

    [~, iA, iC] = intersect(attributeNamesParent, attributeNamesChild);
    
    mergedAttributes(iA) = attributesChild(iC);
end