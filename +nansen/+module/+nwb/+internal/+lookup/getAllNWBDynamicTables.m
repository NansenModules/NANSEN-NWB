function getAllNWBDynamicTables()
%getAllNWBDynamicTables - Print the dynamic tables an NWB file can hold
%   getAllNWBDynamicTables() walks the NWBFile schema and prints the name
%   and type of each group beneath it, so the dynamic tables a file can
%   contain can be read off at the prompt. It returns nothing.
%
%   See also nansen.module.nwb.internal.schemautil.getProcessedClass

    import nansen.module.nwb.internal.schemautil.getProcessedClass

    [classInfo, ~] = getProcessedClass('NWBFile');

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
