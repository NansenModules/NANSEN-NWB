function findings = inspectFile(nwbFilePath, options)
%inspectFile - Check an NWB file against NWB Best Practices
%   FINDINGS = inspectFile(nwbFilePath) runs NWB Inspector over the file
%   and returns what it reports, as a table with one row per finding.
%
%   FINDINGS = inspectFile(...,MinimumImportance=LEVEL) reports only
%   findings at or above LEVEL. LEVEL must be:
%       "BEST_PRACTICE_SUGGESTION" - (default) Everything
%       "BEST_PRACTICE_VIOLATION"  - Violations and worse
%       "CRITICAL"                 - Only what makes the file unusable
%
%   The table has the columns Importance, Check, Message and Location.
%   It is empty when the file passes.
%
%   Validation is delegated rather than reimplemented: NWB Inspector is
%   the reference implementation of the practices, and a MATLAB copy of
%   it would drift from what a repository actually checks on submission.
%
%   Errors:
%     nansen:nwb:inspectorUnavailable - NWB Inspector could not be
%                     imported from the configured Python.
%
%   Example: Check a converted file, worst finding first
%       findings = nansen.module.nwb.neuroconv.inspectFile("session.nwb");
%       disp(findings)
%
%   See also nansen.module.nwb.neuroconv.hasNeuroconv,
%   nansen.module.nwb.conversion.NWBFileConverter

    arguments
        nwbFilePath (1,1) string {mustBeFile}
        options.MinimumImportance (1,1) string ...
            {mustBeMember(options.MinimumImportance, ["BEST_PRACTICE_SUGGESTION", ...
                "BEST_PRACTICE_VIOLATION", "CRITICAL"])} = "BEST_PRACTICE_SUGGESTION"
    end

    try
        inspector = py.importlib.import_module("nwbinspector");
    catch cause
        exception = MException("nansen:nwb:inspectorUnavailable", ...
            ['NWB Inspector could not be imported, so the converted file ', ...
             'was not checked. Install it with ''pip install nwbinspector'' ', ...
             'into the Python MATLAB is configured to use.']);
        throw(addCause(exception, cause))
    end

    messages = py.list(inspector.inspect_nwbfile(pyargs( ...
        "nwbfile_path", char(nwbFilePath))));

    findings = emptyFindings();
    rank = importanceRank(options.MinimumImportance);

    for i = 1:double(py.len(messages))
        message = messages{i};

        % Importance is a Python enum member. MATLAB does not expose an
        % enum member's name as a property, so it is read explicitly.
        importance = string(py.getattr(message.importance, 'name'));

        if importanceRank(importance) < rank
            continue
        end

        findings(end+1, :) = { ...
            importance, ...
            string(message.check_function_name), ...
            string(message.message), ...
            locationOf(message)}; %#ok<AGROW>
    end

    % Worst first, so the row that matters is the one the caller sees.
    if ~isempty(findings)
        [~, order] = sort(arrayfun(@importanceRank, findings.Importance), "descend");
        findings = findings(order, :);
    end
end

function findings = emptyFindings()
%emptyFindings - An empty findings table with the right columns

    findings = table(string.empty(0, 1), string.empty(0, 1), ...
        string.empty(0, 1), string.empty(0, 1), ...
        VariableNames=["Importance", "Check", "Message", "Location"]);
end

function rank = importanceRank(importance)
%importanceRank - Order the importance levels, worst highest

    switch string(importance)
        case "CRITICAL"
            rank = 3;
        case "BEST_PRACTICE_VIOLATION"
            rank = 2;
        otherwise
            rank = 1;
    end
end

function location = locationOf(message)
%locationOf - Where in the file a finding applies

    location = "";

    if ~isequal(message.location, py.None)
        location = string(message.location);
    end

    if ~isequal(message.object_name, py.None)
        location = location + string(message.object_name);
    end
end
