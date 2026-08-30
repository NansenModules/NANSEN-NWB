function config = convertLegacyConfiguration(legacyItems, options)
%convertLegacyConfiguration - Convert a pilot .mat configuration to the new schema
%   CONFIG = convertLegacyConfiguration(legacyItems) converts the data
%   items of a pilot configuration catalog to an NWBFileConfiguration.
%   legacyItems is the struct array the pilot configurator saved, either
%   read from a .mat file or taken from a loaded catalog.
%
%   CONFIG = convertLegacyConfiguration(...,OutputPath=PATH) also sets
%   where the NWB file is written. Without it the path is left empty, to
%   be filled in per session.
%
%   This is a one-off tool, run once per configuration, not a loader.
%   Nothing in the conversion path reads the pilot schema: a
%   configuration is either converted and saved as JSON, or rebuilt in
%   the configurator.
%
%   A pilot item naming its own converter function cannot be carried
%   over, because the new registry needs a descriptor saying what the
%   converter accepts and produces. Those items are converted without a
%   converter and reported, so they can be pointed at a registered
%   converter afterwards.
%
%   Example: Convert a saved pilot configuration
%       loaded = load("nwbConfiguration.mat");
%       config = nansen.module.nwb.config.convertLegacyConfiguration( ...
%           loaded.nwbConfigurationData.DataItems);
%       nansen.module.nwb.config.saveConfiguration(config, "nwbConfiguration.json")
%
%   See also nansen.module.nwb.config.NWBFileConfiguration,
%   nansen.module.nwb.config.saveConfiguration

    arguments
        legacyItems struct
        options.OutputPath (1,1) string = ""
    end

    placeholders = nansen.module.nwb.internal.getUnsetPlaceholders();
    dataItems = nansen.module.nwb.config.NWBDataItemConfig.empty(0, 1);
    itemsWithOwnConverter = string.empty;

    for i = 1:numel(legacyItems)
        legacyItem = legacyItems(i);

        item = nansen.module.nwb.config.NWBDataItemConfig( ...
            VariableName=readText(legacyItem, "VariableName"), ...
            NWBVariableName=readText(legacyItem, "NWBVariableName"), ...
            PrimaryGroup=unsetToEmpty(readText(legacyItem, "PrimaryGroupName"), ...
                placeholders.PrimaryGroupName), ...
            NWBModule=unsetToEmpty(readText(legacyItem, "NwbModule"), ...
                placeholders.NwbModule), ...
            TargetNWBType=unsetToEmpty(readText(legacyItem, "NeuroDataType"), ...
                placeholders.NeuroDataType), ...
            Metadata=readMetadata(legacyItem));

        % The pilot schema had no group default, so an item that never
        % had one chosen would otherwise silently become Acquisition.
        if strlength(item.PrimaryGroup) == 0
            item.PrimaryGroup = "Acquisition";
        end

        converterFunction = readText(legacyItem, "Converter");
        if strlength(converterFunction) > 0 && converterFunction ~= "Default"
            itemsWithOwnConverter(end+1) = item.VariableName; %#ok<AGROW>
        end

        dataItems(end+1, 1) = item; %#ok<AGROW>
    end

    if ~isempty(itemsWithOwnConverter)
        warning("nansen:nwb:legacyConverterNotCarriedOver", ...
            ['%s named their own converter function, which the registry ', ...
             'cannot use without a descriptor. Register the converter with ', ...
             'registerConverterFolder and set ConverterName on those items.'], ...
            strjoin(itemsWithOwnConverter, ", "))
    end

    config = nansen.module.nwb.config.NWBFileConfiguration( ...
        OutputPath=options.OutputPath, ...
        DataItems=dataItems);
end

function value = readText(S, fieldName)
%readText - Read one field as scalar text, or "" when it is absent

    if isfield(S, fieldName) && ~isempty(S.(fieldName))
        value = string(S.(fieldName));
        value = value(1);
    else
        value = "";
    end
end

function value = readMetadata(S)
%readMetadata - Read the metadata struct, or an empty one

    if isfield(S, "DefaultMetadata") && isstruct(S.DefaultMetadata) && ...
            isscalar(S.DefaultMetadata)
        value = S.DefaultMetadata;
    else
        value = struct();
    end
end

function value = unsetToEmpty(value, placeholder)
%unsetToEmpty - Turn a configurator placeholder back into no value

    if value == placeholder || startsWith(value, "<")
        value = "";
    end
end
