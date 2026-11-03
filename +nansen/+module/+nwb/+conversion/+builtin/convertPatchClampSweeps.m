function nwbFile = convertPatchClampSweeps(context)
%convertPatchClampSweeps - Store the sweeps of an episodic patch-clamp recording
%   nwbFile = convertPatchClampSweeps(CONTEXT) writes each sweep of the
%   recording in CONTEXT.Data as its own series in the acquisition group,
%   named after the item with the sweep number appended, numbered in
%   sweep_number, and linked to one intracellular electrode and one
%   device, which are created in the file on first use.
%
%   CONTEXT.Data is the struct the SHAREbrain ABF file adapter returns:
%   Data (samples x channels x sweeps, or samples x channels for one
%   sweep), SamplingRate, ChannelNames and ChannelUnits. A channel in
%   volts or millivolts becomes a CurrentClampSeries and one in amperes,
%   nanoamperes or picoamperes a VoltageClampSeries. The samples are
%   stored as recorded, with data_conversion set so that they read as
%   volts or amperes, the units NWB requires.
%
%   An ABF 1 file records no start time per sweep, so every sweep starts
%   at 0 relative to the session start, at the recording's sampling rate,
%   and the comment of each series says so.
%
%   Converter arguments:
%       DeviceMetadata      - name, description and manufacturer of the
%                             amplifier; the name defaults to "Amplifier"
%       ElectrodeMetadata   - name, description, location, slice and
%                             filtering of the pipette; the name defaults
%                             to "electrode-0"
%       StimulusDescription - what stimulus_description says; defaults to
%                             "not described"
%       ChannelIndex        - channels to store; every channel by default
%
%   CONTEXT.Metadata goes into every series: description, comments, gain
%   and the other properties of a patch-clamp series.
%
%   Errors:
%     nansen:nwb:invalidConverterInput - CONTEXT.Data is not such a
%                     struct, or a channel's unit is not one of the above.
%
%   See also nansen.module.sharebrain.fileadapter.ABF,
%   nansen.module.nwb.conversion.ConverterRegistry

    arguments
        context (1,1) struct
    end

    import nansen.module.nwb.conversion.getConverterArg

    recording = context.Data;
    assertRecording(recording, context.DataItem.VariableName)

    samples = recording.Data;
    if ismatrix(samples)
        samples = reshape(samples, size(samples, 1), size(samples, 2), 1);
    end
    numChannels = size(samples, 2);
    numSweeps = size(samples, 3);

    args = context.ConverterArgs;
    channelIndex = getConverterArg(args, "ChannelIndex", 1:numChannels);
    stimulusDescription = string(getConverterArg(args, "StimulusDescription", "not described"));

    nwbFile = context.NwbFile;
    device = getOrCreateDevice(nwbFile, getConverterArg(args, "DeviceMetadata", struct()));
    electrode = getOrCreateElectrode(nwbFile, ...
        getConverterArg(args, "ElectrodeMetadata", struct()), device);

    metadataNvPairs = namedargs2cell(charStrings(context.Metadata));
    comments = "Sweep start times are not recorded in the file; every sweep starts at 0.";
    if isfield(context.Metadata, "comments")
        comments = string(context.Metadata.comments) + " " + comments;
        metadataNvPairs = namedargs2cell(charStrings(rmfield(context.Metadata, "comments")));
    end

    baseName = string(context.Placement.Name);
    channelNames = string(recording.ChannelNames);
    channelUnits = string(recording.ChannelUnits);

    for channel = reshape(channelIndex, 1, [])
        [seriesConstructor, storedUnit, conversion] = seriesForUnit( ...
            channelUnits(channel), context.DataItem.VariableName);

        for sweep = 1:numSweeps
            series = seriesConstructor( ...
                'data', squeeze(samples(:, channel, sweep)), ...
                'data_unit', storedUnit, ...
                'data_conversion', conversion, ...
                'starting_time', 0, ...
                'starting_time_rate', recording.SamplingRate, ...
                'electrode', types.untyped.SoftLink(electrode), ...
                'sweep_number', uint32(sweep), ...
                'stimulus_description', char(stimulusDescription), ...
                'comments', char(comments), ...
                metadataNvPairs{:});

            nwbFile.acquisition.set(char(seriesName(baseName, channelNames, channel, ...
                numChannels, sweep)), series);
        end
    end
end

function assertRecording(recording, variableName)
%assertRecording - Require the struct the ABF adapter returns

    requiredFields = ["Data", "SamplingRate", "ChannelNames", "ChannelUnits"];
    if ~isstruct(recording) || ~isscalar(recording) || ~all(isfield(recording, requiredFields))
        error("nansen:nwb:invalidConverterInput", ...
            ['The patch-clamp sweeps converter needs the struct an ABF file ', ...
             'adapter returns, with the fields %s, but ''%s'' is %s.'], ...
            strjoin(requiredFields, ", "), variableName, class(recording))
    end
    if ndims(recording.Data) > 3 || isempty(recording.Data) || ~isnumeric(recording.Data)
        error("nansen:nwb:invalidConverterInput", ...
            ['''%s'' must hold samples x channels x sweeps of numbers, but ', ...
             'holds %s of size %s.'], variableName, class(recording.Data), ...
            mat2str(size(recording.Data)))
    end
end

function [constructor, storedUnit, conversion] = seriesForUnit(unit, variableName)
%seriesForUnit - The series class and the conversion a channel's unit calls for
%
%   A membrane potential is recorded in current clamp and a current in
%   voltage clamp, so the unit decides the series. NWB stores the first
%   in volts and the second in amperes; data_conversion carries the
%   factor from the recorded unit.

    switch strtrim(unit)
        case "V"
            constructor = @types.core.CurrentClampSeries; storedUnit = 'volts'; conversion = 1;
        case "mV"
            constructor = @types.core.CurrentClampSeries; storedUnit = 'volts'; conversion = 1e-3;
        case "A"
            constructor = @types.core.VoltageClampSeries; storedUnit = 'amperes'; conversion = 1;
        case "nA"
            constructor = @types.core.VoltageClampSeries; storedUnit = 'amperes'; conversion = 1e-9;
        case "pA"
            constructor = @types.core.VoltageClampSeries; storedUnit = 'amperes'; conversion = 1e-12;
        otherwise
            error("nansen:nwb:invalidConverterInput", ...
                ['A channel of ''%s'' is recorded in ''%s'', which is neither ', ...
                 'a voltage (V, mV) nor a current (A, nA, pA), so it cannot ', ...
                 'be stored as a clamp series.'], variableName, unit)
    end
end

function name = seriesName(baseName, channelNames, channel, numChannels, sweep)
%seriesName - <item>[_<channel>]_sweep<nnn>

    name = baseName;
    if numChannels > 1
        channelName = "";
        if numel(channelNames) >= channel
            channelName = strtrim(channelNames(channel));
        end
        if strlength(channelName) == 0
            channelName = "ch" + channel;
        end
        name = name + "_" + channelName;
    end
    name = name + sprintf("_sweep%03d", sweep);
end

function device = getOrCreateDevice(nwbFile, deviceMetadata)
%getOrCreateDevice - The amplifier, created on first use

    import nansen.module.nwb.conversion.getConverterArg

    name = string(getConverterArg(deviceMetadata, "name", "Amplifier"));
    if nwbFile.general_devices.isKey(name)
        device = nwbFile.general_devices.get(name);
        return
    end

    properties = rmfieldIfPresent(deviceMetadata, "name");
    nvPairs = namedargs2cell(charStrings(properties));
    device = types.core.Device(nvPairs{:});
    nwbFile.general_devices.set(char(name), device);
end

function electrode = getOrCreateElectrode(nwbFile, electrodeMetadata, device)
%getOrCreateElectrode - The pipette, created on first use

    import nansen.module.nwb.conversion.getConverterArg

    name = string(getConverterArg(electrodeMetadata, "name", "electrode-0"));
    if nwbFile.general_intracellular_ephys.isKey(name)
        electrode = nwbFile.general_intracellular_ephys.get(name);
        return
    end

    properties = rmfieldIfPresent(electrodeMetadata, "name");
    if ~isfield(properties, "description")
        properties.description = "patch pipette";
    end
    nvPairs = namedargs2cell(charStrings(properties));
    electrode = types.core.IntracellularElectrode('device', types.untyped.SoftLink(device), nvPairs{:});
    nwbFile.general_intracellular_ephys.set(char(name), electrode);
end

function S = rmfieldIfPresent(S, fieldName)
%rmfieldIfPresent - Remove a field a struct may not have

    if isfield(S, fieldName)
        S = rmfield(S, fieldName);
    end
end

function S = charStrings(S)
%charStrings - Give matnwb the text shape it expects

    fieldNames = fieldnames(S);
    for i = 1:numel(fieldNames)
        value = S.(fieldNames{i});
        if isstring(value) && isscalar(value)
            S.(fieldNames{i}) = char(value);
        end
    end
end
