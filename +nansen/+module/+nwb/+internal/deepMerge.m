function merged = deepMerge(baseStruct, overlayStruct)
%deepMerge - Merge two structs, recursing into nested struct fields
%   MERGED = deepMerge(baseStruct,overlayStruct) returns baseStruct with
%   the fields of overlayStruct laid over it. A field present in both
%   takes the overlay's value, with two exceptions: two scalar structs
%   merge field by field rather than the overlay replacing the base
%   wholesale, and an empty overlay value does not erase a base value.
%
%   The empty-value rule is what makes the function usable for defaults:
%   a configuration whose institution field was never filled in reads as
%   "not specified", not as "specified to be nothing", so the default
%   survives it.
%
%   Anything that is not a pair of scalar structs is replaced whole:
%   arrays, cell arrays and struct arrays are values here, not
%   containers to merge element by element.
%
%   Example: Lay session metadata over project-wide defaults
%       defaults = struct("institution", "UiO", "lab", "Vervaeke");
%       session = struct("lab", "Roth", "session_id", "s01");
%       merged = nansen.module.nwb.internal.deepMerge(defaults, session);
%       % institution "UiO", lab "Roth", session_id "s01"
%
%   See also nansen.module.nwb.config.NWBFileConfiguration

    arguments
        baseStruct (1,1) struct
        overlayStruct (1,1) struct
    end

    merged = baseStruct;
    overlayFields = string(fieldnames(overlayStruct));

    for i = 1:numel(overlayFields)
        fieldName = overlayFields(i);
        overlayValue = overlayStruct.(fieldName);

        if ~isfield(merged, fieldName)
            merged.(fieldName) = overlayValue;
            continue
        end

        baseValue = merged.(fieldName);

        if isstruct(baseValue) && isscalar(baseValue) && ...
                isstruct(overlayValue) && isscalar(overlayValue)
            merged.(fieldName) = ...
                nansen.module.nwb.internal.deepMerge(baseValue, overlayValue);
        elseif ~isEmptyValue(overlayValue)
            merged.(fieldName) = overlayValue;
        end
        % An empty overlay value keeps the base value.
    end
end

function tf = isEmptyValue(value)
%isEmptyValue - True for a value that carries no information
%
%   A blank string scalar counts: isempty("") is false, but a field
%   holding "" was never given a value any more than one holding [].

    tf = isempty(value) || ...
        (isstring(value) && isscalar(value) && ...
            (ismissing(value) || strlength(value) == 0));
end
