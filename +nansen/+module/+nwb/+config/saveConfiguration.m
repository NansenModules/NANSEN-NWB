function saveConfiguration(config, filePath)
%saveConfiguration - Save an NWB conversion configuration as JSON
%   saveConfiguration(CONFIG,filePath) writes CONFIG to filePath as
%   pretty-printed JSON, creating the parent folder if needed. CONFIG is
%   an NWBFileConfiguration or a struct in the same shape.
%
%   Example: Save a configuration next to the session data
%       config = nansen.module.nwb.config.NWBFileConfiguration();
%       config.OutputPath = "/data/sub-01_ses-01.nwb";
%       nansen.module.nwb.config.saveConfiguration(config, "/data/nwb.json")
%
%   See also nansen.module.nwb.config.loadConfiguration,
%   nansen.module.nwb.config.NWBFileConfiguration, jsonencode

    arguments
        config
        filePath (1,1) string
    end

    config = nansen.module.nwb.config.NWBFileConfiguration.fromAny(config);

    parentFolder = fileparts(filePath);
    if parentFolder ~= "" && ~isfolder(parentFolder)
        mkdir(parentFolder)
    end

    jsonText = jsonencode(config.toStruct(), "PrettyPrint", true);

    fid = fopen(filePath, "w");
    if fid < 0
        error("nansen:nwb:couldNotOpenFile", ...
            ['Could not open ''%s'' for writing. Check that the folder ', ...
             'exists and is writable.'], filePath)
    end
    cleanupObj = onCleanup(@() fclose(fid));

    fwrite(fid, jsonText, "char");
    fwrite(fid, newline, "char");
end
