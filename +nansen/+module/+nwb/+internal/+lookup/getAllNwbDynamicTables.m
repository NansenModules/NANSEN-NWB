function getAllNwbDynamicTables()


    import nansen.module.nwb.internal.schemautil.getProcessedClass

    [classInfo, ~] = getProcessedClass('NWBFile');

    S = struct;
    displayGroupNameAndType( classInfo.subgroups )
    
end

function displayGroupNameAndType(subgroups)
    
    for i = 1:numel(subgroups)
        
        fprintf('Name: % 30s - Type: % 30s\n', subgroups(i).name, subgroups(i).type);
        if ~isempty( subgroups(i).subgroups )
            displayGroupNameAndType(subgroups(i).subgroups )
        end
    end 
end