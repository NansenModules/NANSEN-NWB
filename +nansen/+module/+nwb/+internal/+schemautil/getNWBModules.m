function keptModules = getNWBModules()
%getNWBModules - Get the names of the NWB core modules
%   keptModules = getNWBModules() returns the modules of the core
%   namespace, with device and file left out because neither groups
%   neurodata types the way the others do.
%
%   See also nansen.module.nwb.internal.schemautil.getTypesForModule

    folderPath = fullfile(misc.getMatnwbDir(), 'namespaces');
    S = load(fullfile(folderPath, "core.mat") );

    moduleNames = strrep(S.filenames, 'nwb.', '');
    
    ignoreModules = {'device', 'file'};
    keptModules = string( setdiff(moduleNames, ignoreModules) );

    % Todo: get titles and description
end
