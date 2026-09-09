function nwbFilePath = runAbfConversionExample(abfFilePath, options)
%runAbfConversionExample - Convert ABF files to NWB through NeuroConv
%   nwbFilePath = runAbfConversionExample(abfFilePath) builds a conversion
%   configuration by hand for one ABF recording, hands it to NeuroConv's
%   AbfInterface through the conversion runner, and returns the NWB file
%   it wrote. Every ABF file beside abfFilePath goes into the same NWB
%   file, which is how NeuroConv treats a session's recordings. No NANSEN
%   session is needed.
%
%   runAbfConversionExample(...,PythonExecutable=EXE) loads Python from
%   EXE when this MATLAB session has not loaded one yet. That Python needs
%   "neuroconv[abf]" installed.
%
%   runAbfConversionExample(...,OutputFolder=FOLDER) writes the file to
%   FOLDER instead of a temporary folder.
%
%   The example is the check that the NeuroConv path works end to end for
%   an intracellular format: the runner creates the file with session and
%   subject metadata, the interface appends its electrodes, recordings and
%   sweep tables, and the file carries one file_create_date entry.
%
%   Example: Convert a session's ABF files, with tests/manual on the path
%       nwbFilePath = runAbfConversionExample( ...
%           "/data/sub-01/2026_09_08_0001.abf", ...
%           PythonExecutable="/Users/me/.venvs/nansen-nwb/bin/python");
%       nwbRead(nwbFilePath)
%
%   See also nansen.module.nwb.conversion.NWBFileConverter,
%   nansen.module.nwb.neuroconv.runConversion,
%   tests.manual.runStandaloneConversionExample

    arguments
        abfFilePath (1,1) string {mustBeFile}
        options.PythonExecutable (1,1) string = ""
        options.OutputFolder (1,1) string = string(tempname())
    end

    import nansen.module.nwb.config.NWBFileConfiguration
    import nansen.module.nwb.config.NWBDataItemConfig

    if ~isfolder(options.OutputFolder)
        mkdir(options.OutputFolder)
    end
    nwbFilePath = fullfile(options.OutputFolder, "sub-demo_ses-abf.nwb");

    % A NANSEN session would record this from its variable model; here it
    % is the only source evidence the converter needs.
    sourceInfo = NWBDataItemConfig.emptySourceInfo();
    sourceInfo.Path = abfFilePath;

    converterArgs = struct();
    if strlength(options.PythonExecutable) > 0
        converterArgs.PythonExecutable = options.PythonExecutable;
    end

    % NeuroConv wants lists of named entries here, which a cell array
    % becomes on the way into Python. The interface reads the electrodes
    % from the file headers; the item only describes the device.
    itemMetadata = struct("Icephys", struct("Device", ...
        {{struct("name", "DeviceIcephys", "description", "Patch-clamp amplifier")}}));

    config = NWBFileConfiguration( ...
        OutputPath=nwbFilePath, ...
        SessionMetadata=struct( ...
            "session_description", "ABF conversion example", ...
            "identifier", "abf-example-001", ...
            "session_start_time", datetime("now", TimeZone="local")), ...
        SubjectMetadata=struct( ...
            "subject_id", "demo", ...
            "species", "Mus musculus", ...
            "sex", "U", ...
            "age", "P90D"), ...
        GeneralMetadata=struct( ...
            "institution", "Example University", ...
            "lab", "Example Lab"), ...
        DataItems=NWBDataItemConfig( ...
            VariableName="patchClampRecording", ...
            ConverterName="NeuroConvAbfInterface", ...
            Metadata=itemMetadata, ...
            ConverterArgs=converterArgs, ...
            SourceInfo=sourceInfo));

    converter = nansen.module.nwb.conversion.NWBFileConverter(config);

    nwbFilePath = converter.convert();

    fprintf("Wrote %s\n", nwbFilePath)
    describeFile(nwbFilePath)
end

function describeFile(nwbFilePath)
%describeFile - Print what ended up in the file

    nwbFile = nwbRead(nwbFilePath);

    fprintf("  identifier      : %s\n", nwbFile.identifier)
    fprintf("  subject         : %s\n", nwbFile.general_subject.subject_id)
    fprintf("  acquisition     : %s\n", ...
        strjoin(string(nwbFile.acquisition.keys()), ", "))
    fprintf("  electrodes      : %s\n", ...
        strjoin(string(nwbFile.general_intracellular_ephys.keys()), ", "))

    createDates = loadValues(nwbFile.file_create_date);
    fprintf("  times exported  : %d\n", numel(createDates))
end

function values = loadValues(value)
%loadValues - Read a value whether or not it is still a stub

    if isa(value, "types.untyped.DataStub")
        values = value.load();
    else
        values = value;
    end
end
