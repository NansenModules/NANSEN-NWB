function metadata = addIcephysExperimentType(metadata, sourceArg, experimentType)
%addIcephysExperimentType - Set the clamp mode of every file's recording session
%   metadata = addIcephysExperimentType(metadata,sourceArg,experimentType)
%   adds an Icephys session for each file in sourceArg.file_paths, the
%   constructor arguments of a NeuroConv AbfInterface, named by the file's
%   name and with icephys_experiment_type set to experimentType.
%
%   AbfInterface keeps one Icephys session per file, named by the file's
%   name, and NeuroConv merges caller metadata into it by that name. The
%   sessions are a cell array so they stay a list for a single file.
%
%   Errors:
%     nansen:nwb:invalidConverterArg - experimentType is not
%                     "current_clamp", "voltage_clamp" or "izero", or
%                     sourceArg has no file_paths.
%
%   See also nansen.module.nwb.conversion.builtin.convertWithNeuroconv

    arguments
        metadata (1,1) struct
        sourceArg (1,1) struct
        experimentType (1,1) string
    end

    validTypes = ["current_clamp", "voltage_clamp", "izero"];
    if ~any(experimentType == validTypes)
        error("nansen:nwb:invalidConverterArg", ...
            ['IcephysExperimentType must be "current_clamp", ', ...
             '"voltage_clamp" or "izero", but was "%s".'], experimentType)
    end

    if ~isfield(sourceArg, "file_paths")
        error("nansen:nwb:invalidConverterArg", ...
            ['IcephysExperimentType sets the clamp mode of each file ', ...
             'AbfInterface is given as file_paths, but the interface''s ', ...
             'arguments have no file_paths.'])
    end
    filePaths = string(sourceArg.file_paths);

    sessions = cell(1, numel(filePaths));
    for i = 1:numel(filePaths)
        [~, name, extension] = fileparts(filePaths(i));
        sessions{i} = struct("name", name + extension, ...
            "icephys_experiment_type", experimentType);
    end

    if ~isfield(metadata, "Icephys")
        metadata.Icephys = struct();
    end
    metadata.Icephys.Sessions = sessions;
end
