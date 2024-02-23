function keptModules = getNwbModules()

    folderPath = fullfile(matnwb.misc.getMatnwbDir(), 'namespaces');
    S = load(fullfile(folderPath, "core.mat") );

    moduleNames = strrep(S.filenames, 'nwb.', '');
    
    ignoreModules = {'device', 'file'};
    keptModules = string( setdiff(moduleNames, ignoreModules) );

    % Todo: get titles and description
end