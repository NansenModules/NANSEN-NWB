function warnings = validateNwbConfiguration(dataItems)
% validateNwbConfiguration - Validate NWB configuration data items
%
%   warnings = validateNwbConfiguration(dataItems) checks an array of NWB
%   configuration item structs and returns a cell array of warning strings
%   describing any problems found.
%
%   Two classes of problems are detected:
%     1. Unfilled required table columns — PrimaryGroup, NwbModule for
%        processing data, or both converter and target type.
%     2. Missing required NWB metadata properties — required properties for
%        the selected TargetNwbType are absent or empty in Metadata.
%
%   Input Arguments:
%     dataItems - Struct array of configuration items, each with fields:
%                   VariableName, PrimaryGroup, NwbModule,
%                   TargetNwbType, Metadata (struct or empty).
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
        descriptor = getConfiguredDescriptor(item);
        hasConverterOwnedPlacement = ~isempty(descriptor) && ...
            descriptor.PlacementPolicy == "converter" && ...
            ~descriptor.AllowsPlacementOverride;

        % --- 1. Check required table columns ---
        if ~hasConverterOwnedPlacement && isUnset(item.PrimaryGroup)
            warnings{end+1} = sprintf('"%s": Primary group is not set.', varName); %#ok<AGROW>
        end

        if ~hasConverterOwnedPlacement && strcmp(string(item.PrimaryGroup), "Processing") && isUnset(item.NwbModule)
            warnings{end+1} = sprintf('"%s": NWB module is not set.', varName); %#ok<AGROW>
        end

        hasConverter = isfield(item, 'ConverterName') && ~isUnset(item.ConverterName) && ...
            string(item.ConverterName) ~= "Default";
        hasTargetType = ~isUnset(item.TargetNwbType);
        if ~hasConverter && ~hasTargetType
            warnings{end+1} = sprintf('"%s": Converter or target NWB type is not set.', varName); %#ok<AGROW>
            continue  % Cannot check metadata without a type
        end

        if ~hasTargetType
            continue
        end

        % --- 2. Check required NWB metadata properties ---
        try
            requiredProps = getRequiredProperties(item.TargetNwbType);
        catch
            continue  % Skip if type is not resolvable
        end

        if isempty(requiredProps)
            continue
        end

        metadata = item.Metadata;

        for j = 1:numel(requiredProps)
            propName = requiredProps{j};
            if isempty(metadata) || ~isfield(metadata, propName) || isEmptyValue(metadata.(propName))
                warnings{end+1} = sprintf( ...
                    '"%s" (%s): required property "%s" is not set.', ...
                    varName, item.TargetNwbType, propName); %#ok<AGROW>
            end
        end
    end
end

function descriptor = getConfiguredDescriptor(item)
    descriptor = [];
    if ~isfield(item, 'ConverterName') || isUnset(item.ConverterName) || ...
            string(item.ConverterName) == "Default"
        return
    end

    try
        descriptor = nansen.module.nwb.conversion.ConverterRegistry.instance().get( ...
            string(item.ConverterName));
    catch
        descriptor = [];
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
