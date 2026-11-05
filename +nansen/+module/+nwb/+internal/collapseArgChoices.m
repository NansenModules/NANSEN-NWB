function args = collapseArgChoices(editorArgs)
%collapseArgChoices - Turn dropdown structs back into text arguments
%   args = collapseArgChoices(editorArgs) replaces every
%   Alternatives/Selection struct that expandArgChoices made with the
%   selected text. A placeholder selection, text in angle brackets, means
%   no value was chosen and becomes blank text. Any other struct, such as
%   nested interface arguments, is kept as it is.
%
%   See also nansen.module.nwb.internal.expandArgChoices

    arguments
        editorArgs (1,1) struct
    end

    args = editorArgs;
    names = string(fieldnames(editorArgs));
    for i = 1:numel(names)
        value = editorArgs.(names(i));
        isChoiceStruct = isstruct(value) && isscalar(value) ...
            && isfield(value, "Selection") && isfield(value, "Alternatives");
        if ~isChoiceStruct
            continue
        end

        selection = strtrim(string(value.Selection));
        if startsWith(selection, "<")
            selection = "";
        end
        args.(names(i)) = char(selection);
    end
end
