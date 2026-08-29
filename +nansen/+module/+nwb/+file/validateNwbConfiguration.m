function warnings = validateNwbConfiguration(dataItems)
% validateNwbConfiguration - Validate NWB configuration data items
%
%   warnings = validateNwbConfiguration(dataItems) checks an array of NWB
%   configuration item structs and returns a cell array of warning strings
%   describing any problems found.
%
%   Two classes of problems are detected:
%     1. Unfilled required table columns — PrimaryGroupName, NwbModule, or
%        NeuroDataType still hold their placeholder values.
%     2. Missing required NWB metadata properties — required properties for
%        the selected NeuroDataType are absent or empty in DefaultMetadata.
%
%   Input Arguments:
%     dataItems - Struct array of configuration items, each with fields:
%                   VariableName, PrimaryGroupName, NwbModule,
%                   NeuroDataType, DefaultMetadata (struct or empty).
%
%   Output Arguments:
%     warnings  - Cell array of warning message strings. Empty if no issues.
%
%   See also: nansen.module.nwb.internal.schemautil.getRequiredProperties

    import nansen.module.nwb.internal.schemautil.getRequiredProperties

    warnings = {};

    for i = 1:numel(dataItems)
        item = dataItems(i);
        varName = item.VariableName;

        % --- 1. Check required table columns ---
        if isUnset(item.PrimaryGroupName)
            warnings{end+1} = sprintf('"%s": Primary group is not set.', varName); %#ok<AGROW>
        end

        if isUnset(item.NwbModule)
            warnings{end+1} = sprintf('"%s": NWB module is not set.', varName); %#ok<AGROW>
        end

        if isUnset(item.NeuroDataType)
            warnings{end+1} = sprintf('"%s": Neurodata type is not set.', varName); %#ok<AGROW>
            continue  % Cannot check metadata without a type
        end

        % --- 2. Check required NWB metadata properties ---
        try
            requiredProps = getRequiredProperties(item.NeuroDataType);
        catch
            continue  % Skip if type is not resolvable
        end

        if isempty(requiredProps)
            continue
        end

        metadata = item.DefaultMetadata;

        for j = 1:numel(requiredProps)
            propName = requiredProps{j};
            if isempty(metadata) || ~isfield(metadata, propName) || isEmptyValue(metadata.(propName))
                warnings{end+1} = sprintf( ...
                    '"%s" (%s): required property "%s" is not set.', ...
                    varName, item.NeuroDataType, propName); %#ok<AGROW>
            end
        end
    end
end

function tf = isUnset(value)
% isUnset - True if value is empty or a placeholder string (starts with '<')
    if isempty(value)
        tf = true;
    elseif ischar(value) || isstring(value)
        tf = startsWith(strtrim(value), '<');
    else
        tf = false;
    end
end

function tf = isEmptyValue(value)
% isEmptyValue - True if value is empty or a blank string
    if isempty(value)
        tf = true;
    elseif ischar(value) || isstring(value)
        tf = strlength(strtrim(value)) == 0;
    else
        tf = false;
    end
end
