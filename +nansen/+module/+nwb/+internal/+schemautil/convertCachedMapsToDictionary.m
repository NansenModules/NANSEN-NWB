function D = convertCachedMapsToDictionary()

    folderPath = fullfile(misc.getMatnwbDir(), 'namespaces');
    S = load(fullfile(folderPath, "core.mat") );

    % Simplify the representation of the actual schemas.
    D = map2dict(S.schema);

    function D = map2dict(map)
        D = dictionary( string(map.keys), map.values);
        allKeys = D.keys;
    
        for i = 1:numel(allKeys)
            if isa( D{allKeys(i)}, 'containers.Map' )
                D{allKeys(i)} = map2dict( D{allKeys(i)} );
            elseif isa( D{allKeys(i)}, 'cell' )
                cellOfMaps = D{allKeys(i)};
                cellOfDicts = cell(size(cellOfMaps));
                
                for j = 1:numel(cellOfMaps)
                    if isa( cellOfMaps{j}, 'containers.Map' )
                        cellOfDicts{j} = map2dict( cellOfMaps{j} );
                    else
                        cellOfDicts{j} = cellOfMaps{j} ;
                    end
                end
                D{allKeys(i)} = cellOfDicts;
            end
        end
    end
end