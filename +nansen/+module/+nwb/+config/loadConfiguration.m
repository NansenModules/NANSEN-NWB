function config = loadConfiguration(filePath)
%loadConfiguration Load an NWB conversion configuration from JSON.

    arguments
        filePath (1,1) string {mustBeFile}
    end

    jsonText = fileread(filePath);
    configStruct = jsondecode(jsonText);
    config = nansen.module.nwb.config.NwbFileConfiguration.fromStruct(configStruct);
end
