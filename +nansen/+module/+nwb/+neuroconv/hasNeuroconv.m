function [tf, report] = hasNeuroconv(action)
%hasNeuroconv - Check whether NeuroConv can be run from MATLAB
%   TF = hasNeuroconv() returns true when MATLAB has a working Python
%   interpreter with NeuroConv importable, so NeuroConv-backed converters
%   can run.
%
%   [TF,REPORT] = hasNeuroconv() also returns a struct describing what was
%   found. When TF is false, REPORT.Message says which step failed and
%   what to do about it, which is what the configurator shows against a
%   converter it has greyed out.
%
%   REPORT has fields:
%       PythonAvailable   - Whether MATLAB can load a Python interpreter
%       PythonExecutable  - The interpreter MATLAB is configured to use
%       NeuroconvAvailable- Whether neuroconv could be imported
%       NeuroconvVersion  - The installed NeuroConv version, if any
%       Message           - What to fix, or a confirmation when all is well
%
%   The result is cached for the MATLAB session, since loading Python is
%   slow and its availability does not change under a running session.
%   Call hasNeuroconv("Refresh") after installing NeuroConv.
%
%   Example: Report why NeuroConv converters are unavailable
%       [tf, report] = nansen.module.nwb.neuroconv.hasNeuroconv();
%       if ~tf
%           disp(report.Message)
%       end
%
%   See also nansen.module.nwb.neuroconv.runConversion, pyenv

    arguments
        action (1,1) string {mustBeMember(action, ["Check", "Refresh"])} = "Check"
    end

    persistent cachedReport

    if action == "Check" && ~isempty(cachedReport)
        report = cachedReport;
        tf = report.NeuroconvAvailable;
        return
    end

    report = struct( ...
        "PythonAvailable", false, ...
        "PythonExecutable", "", ...
        "NeuroconvAvailable", false, ...
        "NeuroconvVersion", "", ...
        "Message", "");

    try
        environment = pyenv();
        report.PythonExecutable = string(environment.Executable);
        report.PythonAvailable = strlength(report.PythonExecutable) > 0;
    catch
        report.PythonAvailable = false;
    end

    if ~report.PythonAvailable
        report.Message = ['MATLAB has no Python interpreter configured, so ', ...
            'NeuroConv converters cannot run. Install Python and point ', ...
            'MATLAB at it with pyenv, then install NeuroConv into that ', ...
            'interpreter.'];
        cachedReport = report;
        tf = false;
        return
    end

    try
        py.importlib.import_module("neuroconv");
        report.NeuroconvAvailable = true;
        report.NeuroconvVersion = neuroconvVersion();
    catch cause
        report.Message = sprintf( ...
            ['NeuroConv is not importable from the Python at ''%s'', so ', ...
             'NeuroConv converters cannot run. Install it with ', ...
             '''pip install neuroconv''. Python reported: %s'], ...
            report.PythonExecutable, cause.message);
        cachedReport = report;
        tf = false;
        return
    end

    report.Message = sprintf("NeuroConv %s is available from %s.", ...
        report.NeuroconvVersion, report.PythonExecutable);

    cachedReport = report;
    tf = report.NeuroconvAvailable;
end

function versionText = neuroconvVersion()
%neuroconvVersion - Read the installed NeuroConv version

    % NeuroConv does not expose __version__ on the package, so the version
    % comes from the installed distribution metadata instead.
    try
        metadata = py.importlib.import_module("importlib.metadata");
        versionText = string(metadata.version("neuroconv"));
    catch
        versionText = "unknown";
    end
end
