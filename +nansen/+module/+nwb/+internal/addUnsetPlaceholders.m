function args = addUnsetPlaceholders(args)
%addUnsetPlaceholders - Offer "<not set>" in every choice list
%   args = addUnsetPlaceholders(args) prepends a "<not set>" entry to the
%   choice list of every text argument X that a companion field X_ pairs
%   with, NANSEN's config-field convention for a dropdown.
%
%   The editor shows a dropdown's first choice even while the argument is
%   blank, so without a placeholder entry a blank argument would read as
%   the first value, and a set one could not be cleared. The placeholder
%   stands for no value: removeUnsetPlaceholders turns it back into blank
%   text when the edited arguments are saved.
%
%   See also nansen.module.nwb.internal.removeUnsetPlaceholders,
%   nansen.module.nwb.gui.NWBConfiguratorApp

    arguments
        args (1,1) struct
    end

    unsetPlaceholder = '<not set>';

    names = string(fieldnames(args));
    companionNames = names(endsWith(names, "_"));

    for i = 1:numel(companionNames)
        companionName = companionNames(i);
        argName = extractBefore(companionName, strlength(companionName));
        if ~isfield(args, argName) || ~iscell(args.(companionName))
            continue
        end
        value = args.(argName);
        isTextValue = ischar(value) || (isstring(value) && isscalar(value));
        if ~isTextValue
            continue
        end

        choices = reshape(args.(companionName), 1, []);
        args.(companionName) = [{unsetPlaceholder}, choices];
    end
end
