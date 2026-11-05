function configurePython(pythonExecutable, executionMode)
%configurePython - Point MATLAB at the requested Python, if it can
%   configurePython(pythonExecutable,executionMode) loads Python from
%   pythonExecutable in the given execution mode when no Python has been
%   loaded into this MATLAB session yet. An empty pythonExecutable leaves
%   the configured Python as it is.
%
%   Errors:
%     nansen:nwb:pythonAlreadyLoaded - a different Python is already
%                     loaded, which MATLAB cannot change without a restart.
%
%   See also nansen.module.nwb.neuroconv.runConversion, pyenv

    arguments
        pythonExecutable (1,1) string
        executionMode (1,1) string ...
            {mustBeMember(executionMode, ["InProcess", "OutOfProcess"])} = "OutOfProcess"
    end

    if strlength(pythonExecutable) == 0
        return
    end

    environment = pyenv();

    if string(environment.Status) == "NotLoaded"
        pyenv("Version", pythonExecutable, "ExecutionMode", executionMode);
        return
    end

    % MATLAB loads one Python per session, so a second, different
    % interpreter cannot be honored without a restart.
    if string(environment.Executable) ~= pythonExecutable
        error("nansen:nwb:pythonAlreadyLoaded", ...
            ['Python is already loaded in this MATLAB session from ''%s'', ', ...
             'so ''%s'' cannot be used. Restart MATLAB to switch ', ...
             'interpreters.'], string(environment.Executable), pythonExecutable)
    end
end
