function config = loadConfiguration(filePath)
%loadConfiguration - Load an NWB conversion configuration from JSON
%   CONFIG = loadConfiguration(filePath) reads the JSON configuration at
%   filePath and returns it as an NWBFileConfiguration.
%
%   Errors:
%     nansen:nwb:invalidConfigFile - filePath does not hold valid JSON.
%
%   See also nansen.module.nwb.config.saveConfiguration,
%   nansen.module.nwb.config.NWBFileConfiguration, jsondecode

    arguments
        filePath (1,1) string {mustBeFile}
    end

    jsonText = fileread(filePath);

    try
        configStruct = jsondecode(jsonText);
    catch cause
        % jsondecode reports a parse position but not the file, which is
        % the part the user needs to act on.
        exception = MException("nansen:nwb:invalidConfigFile", ...
            ['Could not read the NWB configuration ''%s'': the file is ', ...
             'not valid JSON. Rebuild it with the configurator, or ', ...
             'restore it from version control.'], filePath);
        throw(addCause(exception, cause))
    end

    config = nansen.module.nwb.config.NWBFileConfiguration.fromStruct(configStruct);
end
