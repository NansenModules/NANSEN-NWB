function runConversion(interfaceClassName, sourceArg, nwbFilePath, metadata, options)
%runConversion - Run a NeuroConv data interface from MATLAB
%   runConversion(interfaceClassName,sourceArg,nwbFilePath) imports the
%   named interface from neuroconv.datainterfaces, instantiates it with
%   the fields of sourceArg as constructor arguments, and runs its
%   conversion into nwbFilePath.
%
%   runConversion(...,METADATA) also passes a metadata struct, converted
%   to the nested dictionary NeuroConv expects.
%
%   runConversion(...,AppendOnDiskNwbFile=true) appends to the file at
%   nwbFilePath instead of creating it. NeuroConv refuses to touch a file
%   that already exists unless this or Overwrite is set.
%
%   runConversion(...,Overwrite=true) replaces the file instead.
%
%   runConversion(...,PythonExecutable=EXE) loads Python from EXE, when
%   Python has not been loaded into this MATLAB session yet.
%
%   runConversion(...,RunConversionArgs=ARGS) forwards the fields of the
%   struct ARGS to run_conversion as further arguments.
%
%   runConversion(...,UseInterfaceMetadata=true) starts from the metadata
%   the interface harvests from its source files and lays METADATA over
%   it. An intracellular interface, for one, works out its electrodes and
%   recording tables from the file headers, and run_conversion uses that
%   only when handed no metadata at all. Values in METADATA win where the
%   two overlap. When appending, the NWBFile section is emptied and
%   Subject dropped after the merge, since whoever created the file wrote
%   its own metadata.
%
%   runConversion(...,AlignToStartTime=T) also shifts the interface's data
%   so that their times count from the datetime T, the session_start_time
%   of the file being appended to. An interface times its data from the
%   start of its own recording, which it reports in get_metadata; a start
%   written without a UTC offset is taken to be in T's time zone, and one
%   without a date, as from an ABF 1 header, to be on T's date.
%
%   This is the only place in the module that calls Python. Everything
%   else, including the registry and the configurator, works whether or
%   not Python is available.
%
%   Errors:
%     nansen:nwb:neuroconvFailed - the conversion raised a Python error.
%                     The Python traceback is attached as the cause.
%     nansen:nwb:invalidWriteMode - both Overwrite and
%                     AppendOnDiskNwbFile were requested.
%     nansen:nwb:recordingBeforeSessionStart - the interface's recording
%                     started before AlignToStartTime.
%
%   Example: Append a ScanImage recording to an existing file
%       nansen.module.nwb.neuroconv.runConversion( ...
%           "ScanImageImagingInterface", struct("file_path", "/data/rec.tif"), ...
%           "/data/sub-01_ses-01.nwb", struct(), AppendOnDiskNwbFile=true)
%
%   See also nansen.module.nwb.neuroconv.hasNeuroconv,
%   nansen.module.nwb.neuroconv.resolveSourceArg, pyenv

    arguments
        interfaceClassName (1,1) string
        sourceArg (1,1) struct
        nwbFilePath (1,1) string
        metadata (1,1) struct = struct()
        options.PythonExecutable (1,1) string = ""
        options.ExecutionMode (1,1) string ...
            {mustBeMember(options.ExecutionMode, ["InProcess", "OutOfProcess"])} = "OutOfProcess"
        options.Overwrite (1,1) logical = false
        options.AppendOnDiskNwbFile (1,1) logical = false
        options.RunConversionArgs (1,1) struct = struct()
        options.UseInterfaceMetadata (1,1) logical = false
        options.AlignToStartTime datetime {mustBeScalarOrEmpty} = datetime.empty
    end

    if options.Overwrite && options.AppendOnDiskNwbFile
        error("nansen:nwb:invalidWriteMode", ...
            ['NeuroConv can either overwrite the NWB file or append to it, ', ...
             'not both. Set only one of Overwrite and AppendOnDiskNwbFile.'])
    end

    import nansen.module.nwb.neuroconv.internal.configurePython
    import nansen.module.nwb.neuroconv.internal.createInterface
    import nansen.module.nwb.neuroconv.internal.structToPyargs

    configurePython(options.PythonExecutable, options.ExecutionMode)

    try
        interface = createInterface(interfaceClassName, sourceArg);

        if ~isempty(options.AlignToStartTime)
            alignToStartTime(interface, options.AlignToStartTime)
        end

        metadataValue = nansen.module.nwb.neuroconv.toPythonValue(metadata);
        if options.UseInterfaceMetadata
            metadataValue = mergeWithInterfaceMetadata(interface, metadataValue, ...
                options.AppendOnDiskNwbFile);
        end

        runConversionNvPairs = { ...
            "nwbfile_path", char(nwbFilePath), ...
            "metadata", metadataValue};

        if options.Overwrite
            runConversionNvPairs = [runConversionNvPairs, {"overwrite", py.bool(true)}];
        elseif options.AppendOnDiskNwbFile
            runConversionNvPairs = [runConversionNvPairs, ...
                {"append_on_disk_nwbfile", py.bool(true)}];
        end

        runConversionNvPairs = [runConversionNvPairs, ...
            structToPyargs(options.RunConversionArgs)];

        interface.run_conversion(pyargs(runConversionNvPairs{:}));
    catch cause
        if cause.identifier == "nansen:nwb:recordingBeforeSessionStart"
            rethrow(cause)
        end
        % The Python traceback is the useful part, so it is kept as the
        % cause rather than flattened into the message.
        exception = MException("nansen:nwb:neuroconvFailed", ...
            ['The NeuroConv interface ''%s'' failed while converting into ', ...
             '''%s''. The Python error is attached below.'], ...
            interfaceClassName, nwbFilePath);
        throw(addCause(exception, cause))
    end
end

function alignToStartTime(interface, fileStartTime)
%alignToStartTime - Shift an interface's times to count from the file's start
%
%   Appending drops the start time the interface reports, so without the
%   shift its data would sit early on the file's timeline by the time
%   between the file's start and the recording's.

    nwbFileSection = interface.get_metadata().get("NWBFile");
    if isequal(nwbFileSection, py.None)
        return
    end
    pythonStart = nwbFileSection.get("session_start_time");
    if isequal(pythonStart, py.None)
        return
    end

    if isa(pythonStart, "py.str")
        startText = string(pythonStart);
    else
        startText = string(pythonStart.isoformat());
    end
    interfaceStart = nansen.module.nwb.internal.iso8601ToDatetime(startText);
    if isempty(interfaceStart)
        warning("nansen:nwb:unalignedRecording", ...
            ['The interface reports its start as ''%s'', which could not be ', ...
             'read, so its data are not aligned to the file''s start.'], startText)
        return
    end
    if interfaceStart.TimeZone == ""
        interfaceStart.TimeZone = fileStartTime.TimeZone;
    end

    % An ABF 1 header holds a time of day but no date, which NeuroConv
    % reports on 1900-01-01. That time of day is taken on the file's date.
    if year(interfaceStart) < 1970
        interfaceStart = dateshift(fileStartTime, "start", "day") ...
            + timeofday(interfaceStart);
    end

    offsetSeconds = seconds(interfaceStart - fileStartTime);
    if offsetSeconds == 0
        return
    end
    if offsetSeconds < 0
        error("nansen:nwb:recordingBeforeSessionStart", ...
            ['The recording started at %s, before the file''s ', ...
             'session_start_time %s. Set the session''s date and time to ', ...
             'when the recording started, or earlier.'], ...
            string(interfaceStart), string(fileStartTime))
    end
    if ~py.hasattr(interface, "set_aligned_starting_time")
        warning("nansen:nwb:unalignedRecording", ...
            ['The interface cannot shift its timestamps, so its data start ', ...
             '%g s early on the file''s timeline.'], offsetSeconds)
        return
    end

    interface.set_aligned_starting_time(offsetSeconds);
end

function merged = mergeWithInterfaceMetadata(interface, callerMetadata, isAppending)
%mergeWithInterfaceMetadata - Lay the caller's metadata over the interface's
%
%   dict_deep_update is NeuroConv's own merge: nested dicts merge key by
%   key, and lists of named entries merge on their "name" field, so a
%   device description supplied by the caller replaces the placeholder
%   the interface put under the same device name.

    utils = py.importlib.import_module("neuroconv.utils");
    merged = utils.dict_deep_update(interface.get_metadata(), callerMetadata);

    if isAppending
        % Appending drops the requirements inside the NWBFile section but
        % not the section itself, and the harvested one carries a session
        % start time that must not compete with what the file already has.
        merged.update(py.dict(pyargs("NWBFile", py.dict())));
        merged.pop("Subject", py.None);
    end
end
