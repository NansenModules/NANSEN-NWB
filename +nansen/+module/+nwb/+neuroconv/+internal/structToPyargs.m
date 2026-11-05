function nvPairs = structToPyargs(S)
%structToPyargs - Flatten a struct into name-value pairs for pyargs
%   nvPairs = structToPyargs(S) returns the fields of S as a cell array
%   of names and values, each value converted with toPythonValue, ready
%   to expand into pyargs.
%
%   See also nansen.module.nwb.neuroconv.toPythonValue, pyargs

    arguments
        S (1,1) struct
    end

    fieldNames = fieldnames(S);
    nvPairs = cell(1, 2*numel(fieldNames));

    for i = 1:numel(fieldNames)
        nvPairs{2*i - 1} = fieldNames{i};
        nvPairs{2*i} = nansen.module.nwb.neuroconv.toPythonValue(S.(fieldNames{i}));
    end
end
