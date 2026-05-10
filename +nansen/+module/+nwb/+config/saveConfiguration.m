function saveConfiguration(config, filePath)
%saveConfiguration Save an NWB conversion configuration as JSON.

    arguments
        config
        filePath (1,1) string
    end

    config = nansen.module.nwb.config.NwbFileConfiguration.fromAny(config);

    parentFolder = fileparts(filePath);
    if parentFolder ~= "" && ~isfolder(parentFolder)
        mkdir(parentFolder)
    end

    jsonText = jsonencode(config.toStruct(), "PrettyPrint", true);
    fid = fopen(filePath, "w");
    assert(fid > 0, "NansenNwb:CouldNotOpenFile", ...
        "Could not open configuration file for writing: %s", filePath)

    cleanupObj = onCleanup(@() fclose(fid));
    fwrite(fid, jsonText, "char");
    fwrite(fid, newline, "char");
end
