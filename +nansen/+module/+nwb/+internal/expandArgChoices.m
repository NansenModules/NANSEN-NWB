function editorArgs = expandArgChoices(args)
%expandArgChoices - Turn choice-bearing arguments into dropdown structs
%   editorArgs = expandArgChoices(args) returns args with every pair of a
%   text argument X and a companion field X_ holding its valid values
%   replaced by the Alternatives/Selection struct that tools.editStruct
%   renders as a dropdown. Every companion field is removed: it configures
%   the editor and is not an argument itself.
%
%   The dropdown starts with a "<not set>" entry, selected while the
%   argument is blank, which collapseArgChoices turns back into blank
%   text. A current value outside the declared choices is appended to
%   them and selected, so a hand-edited configuration is never silently
%   replaced.
%
%   See also nansen.module.nwb.internal.collapseArgChoices,
%   nansen.module.nwb.gui.NWBConfiguratorApp

    arguments
        args (1,1) struct
    end

    unsetPlaceholder = '<not set>';

    editorArgs = args;
    names = string(fieldnames(args));
    companionNames = names(endsWith(names, "_"));

    for i = 1:numel(companionNames)
        companionName = companionNames(i);
        editorArgs = rmfield(editorArgs, companionName);

        argName = extractBefore(companionName, strlength(companionName));
        if ~isfield(args, argName)
            continue
        end
        value = args.(argName);
        isTextValue = ischar(value) || (isstring(value) && isscalar(value));
        if ~isTextValue
            continue
        end

        choices = reshape(cellstr(args.(companionName)), 1, []);
        value = char(value);
        if strlength(strtrim(string(value))) == 0
            selection = unsetPlaceholder;
        elseif any(strcmp(choices, value))
            selection = value;
        else
            choices = [choices, {value}]; %#ok<AGROW>
            selection = value;
        end

        editorArgs.(argName) = struct( ...
            "Alternatives", {[{unsetPlaceholder}, choices]}, ...
            "Selection", selection);
    end
end
