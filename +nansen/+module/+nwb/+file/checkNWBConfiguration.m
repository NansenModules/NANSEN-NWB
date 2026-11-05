function warnings = checkNWBConfiguration(dataItems)
%checkNWBConfiguration - Report problems in NWB configuration data items
%
%   warnings = checkNWBConfiguration(dataItems) checks an array of NWB
%   configuration item structs and returns a cell array of warning strings
%   describing any problems found. It reports rather than enforces, and
%   never raises, so a caller decides what to do about the result.
%
%   Two classes of problems are detected:
%     1. Unfilled required table columns — PrimaryGroupName, NwbModule, or
%        NeuroDataType still hold their placeholder values.
%     2. Missing required NWB metadata properties — required properties for
%        the selected NeuroDataType are absent or empty in DefaultMetadata.
%        Properties that carry data rather than metadata, such as "data"
%        and "timestamps", are excluded: they are supplied at conversion
%        time and are never part of a configuration.
%
%   Input Arguments:
%     dataItems - Struct array of configuration items, each with fields:
%                   VariableName, PrimaryGroupName, NwbModule,
%                   NeuroDataType, DefaultMetadata (struct or empty).
%
%   Output Arguments:
%     warnings  - Cell array of warning strings. Empty if none.
%
%   See also: nansen.module.nwb.internal.schemautil.getRequiredProperties

    arguments
        % mustBeA rejects other types. A bare "struct" class constraint
        % would instead convert a table by calling struct() on it, which
        % succeeds and then fails on a missing field further down.
        dataItems {mustBeA(dataItems, "struct")}
    end

    import nansen.module.nwb.internal.schemautil.getRequiredProperties

    placeholders = nansen.module.nwb.internal.getUnsetPlaceholders();
    placeholderLabels = string(struct2cell(placeholders));

    warnings = {};

    for i = 1:numel(dataItems)
        item = dataItems(i);
        varName = item.VariableName;

        % --- 1. Check required table columns ---
        if isUnset(item.PrimaryGroupName, placeholderLabels)
            warnings{end+1} = sprintf('"%s": Primary group is not set.', varName); %#ok<AGROW>
        end

        if isUnset(item.NwbModule, placeholderLabels)
            warnings{end+1} = sprintf('"%s": NWB module is not set.', varName); %#ok<AGROW>
        end

        if isUnset(item.NeuroDataType, placeholderLabels)
            warnings{end+1} = sprintf('"%s": Neurodata type is not set.', varName); %#ok<AGROW>
            continue  % Cannot check metadata without a type
        end

        % --- 2. Check required NWB metadata properties ---
        try
            requiredProps = getRequiredProperties(item.NeuroDataType);
        catch
            continue  % Skip if type is not resolvable
        end

        % Only a property the metadata editor offers can be set in a
        % configuration. getTypeMetadataStruct decides which those are: it
        % leaves out the properties that carry data, which
        % convertToNeuroDataType fills from the session data, and the
        % read-only, hidden and deprecated ones. Asking it keeps this check
        % and the editor on one definition.
        [configurableProps, isKnown] = configurableProperties(item.NeuroDataType);
        if isKnown
            requiredProps = intersect(requiredProps, configurableProps, 'stable');
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

function tf = isUnset(value, placeholderLabels)
% isUnset - True if a column is empty or still shows a placeholder label
%
%   Any of the labels counts, not only the column's own: the type column
%   of a saved configuration may hold the module label, which the table
%   offered there while no module was chosen.
    if isempty(value)
        tf = true;
    elseif ischar(value) || isstring(value)
        tf = isscalar(string(value)) && any(strtrim(string(value)) == placeholderLabels);
    else
        tf = false;
    end
end

function [propertyNames, isKnown] = configurableProperties(neuroDataType)
% configurableProperties - Properties the metadata editor offers for a type
%
%   isKnown is false when the type could not be instantiated. The caller
%   then checks every required property, so a degraded environment reports
%   too much rather than nothing.

    import nansen.module.nwb.internal.lookup.getFullTypeName

    % getTypeMetadataStruct instantiates the type to read its defaults,
    % and matnwb warns that a unit is set while the data is not. Nothing
    % is written here, so the warning has nothing to tell the user.
    warningState = warning('off', 'NWB:AttributeDependencyNotSet');
    restoreWarning = onCleanup(@() warning(warningState));

    try
        shortName = utility.string.getSimpleClassName(char(neuroDataType));
        metadataStruct = nansen.module.nwb.internal.getTypeMetadataStruct( ...
            char(getFullTypeName(string(shortName))));
        propertyNames = fieldnames(metadataStruct);
        isKnown = true;
    catch
        propertyNames = {};
        isKnown = false;
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
