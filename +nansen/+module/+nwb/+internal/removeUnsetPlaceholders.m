function args = removeUnsetPlaceholders(args)
%removeUnsetPlaceholders - Turn placeholder arguments back into blank text
%   args = removeUnsetPlaceholders(args) replaces every text argument
%   holding a configurator placeholder, text in angle brackets such as
%   "<not set>", with blank text. The configurator treats angle-bracket
%   text as standing for no value throughout, so a placeholder chosen in
%   a dropdown is never stored as if it were a value.
%
%   See also nansen.module.nwb.internal.addUnsetPlaceholders,
%   nansen.module.nwb.gui.NWBConfiguratorApp

    arguments
        args (1,1) struct
    end

    names = string(fieldnames(args));
    for i = 1:numel(names)
        value = args.(names(i));
        isTextValue = ischar(value) || (isstring(value) && isscalar(value));
        if isTextValue && startsWith(strtrim(string(value)), "<")
            args.(names(i)) = '';
        end
    end
end
