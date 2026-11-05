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
%   sweep), SamplingRate, ChannelNames, ChannelUnits and Header. The
%   samples are stored as recorded, with data_conversion set so that they
%   read as volts or amperes, the units NWB requires.
%
%   The clamp mode decides what each channel is. In current clamp a
%   channel in volts or millivolts is the recorded response, a
%   CurrentClampSeries in acquisition, and a channel in amperes,
%   nanoamperes or picoamperes the injected current, a
%   CurrentClampStimulusSeries in stimulus_presentation. Voltage clamp is
%   the other way round, with VoltageClampSeries and
%   VoltageClampStimulusSeries.
%
%   Each sweep starts at the time Header.sweepStartInPts gives it, which
%   abfload reads from the file's synch array. A file without one, such
%   as an ABF 1 file recorded in a fixed-length mode, records no start
%   time per sweep: every sweep then starts at 0 and the comment of each
%   series says so. A file whose start times do not match its sweeps is
%   warned about and handled the same way.
%
%   A series is named after the item, the channel when the recording has
%   several, and the sweep number. A channel without a name, or with a
%   name another channel shares, is named "ch<N>".
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
%       ClampMode           - "current" or "voltage"; by default the mode
%                             whose response is in the unit of the first
%                             channel stored
%
%   CONTEXT.Metadata goes into every series: description, comments, gain
%   and the other properties of a patch-clamp series. The properties this
%   converter computes, such as data_conversion, electrode and
%   sweep_number, are taken from the recording, and the same fields in
%   CONTEXT.Metadata are ignored with a warning. Fields left empty, as in
%   a metadata template, are not passed on.
%
%   Errors:
%     nansen:nwb:invalidConverterInput - CONTEXT.Data is not such a
%                     struct, or a channel's unit is not one of the above.
%     nansen:nwb:invalidConverterArg - ClampMode is not "current" or
%                     "voltage".
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
    channelIndex = reshape(getConverterArg(args, "ChannelIndex", 1:numChannels), 1, []);
    stimulusDescription = string(getConverterArg(args, "StimulusDescription", "not described"));

    channelUnits = string(recording.ChannelUnits);
    clampMode = string(getConverterArg(args, "ClampMode", ...
        defaultClampMode(channelUnits(channelIndex(1)), context.DataItem.VariableName)));
    if ~any(clampMode == ["current", "voltage"])
        error("nansen:nwb:invalidConverterArg", ...
            'ClampMode must be "current" or "voltage", but was "%s".', clampMode)
    end

    [sweepStartTimes, startTimeNote] = sweepStartTimesOf(recording, numSweeps, ...
        context.DataItem.VariableName);

    nwbFile = context.NwbFile;
    device = getOrCreateDevice(nwbFile, getConverterArg(args, "DeviceMetadata", struct()));
    electrode = getOrCreateElectrode(nwbFile, ...
        getConverterArg(args, "ElectrodeMetadata", struct()), device);

    seriesMetadata = itemMetadata(context.Metadata);
    comments = startTimeNote;
    if isfield(seriesMetadata, "comments")
        comments = strtrim(string(seriesMetadata.comments) + " " + comments);
        seriesMetadata = rmfield(seriesMetadata, "comments");
    end
    metadataNvPairs = namedargs2cell(charStrings(seriesMetadata));
    if strlength(comments) > 0
        metadataNvPairs = [{'comments', char(comments)}, metadataNvPairs];
    end

    baseName = string(context.Placement.Name);
    labels = channelLabels(string(recording.ChannelNames), numChannels);

    for channel = channelIndex
        [seriesConstructor, storedUnit, conversion, isStimulus] = seriesForUnit( ...
            channelUnits(channel), clampMode, context.DataItem.VariableName);
        if isStimulus
            targetGroup = nwbFile.stimulus_presentation;
        else
            targetGroup = nwbFile.acquisition;
        end

        for sweep = 1:numSweeps
            series = seriesConstructor( ...
                'data', squeeze(samples(:, channel, sweep)), ...
                'data_unit', storedUnit, ...
                'data_conversion', conversion, ...
                'starting_time', sweepStartTimes(sweep), ...
                'starting_time_rate', recording.SamplingRate, ...
                'electrode', types.untyped.SoftLink(electrode), ...
                'sweep_number', uint32(sweep), ...
                'stimulus_description', char(stimulusDescription), ...
                metadataNvPairs{:});

            targetGroup.set(char(seriesName(baseName, labels(channel), ...
                numChannels, sweep)), series);
        end
    end
end

function metadata = itemMetadata(metadata)
%itemMetadata - The item's metadata without what the converter computes
%
%   The configurator fills an item's metadata from the template of
%   PatchClampSeries, which holds data_conversion = 1 and an empty
%   electrode. Passed after the computed values, those would label
%   millivolts as volts and unlink the electrode.

    computedNames = ["data", "data_unit", "data_conversion", "starting_time", ...
        "starting_time_rate", "timestamps", "electrode", "sweep_number", ...
        "stimulus_description"];

    for fieldName = string(fieldnames(metadata))'
        value = metadata.(fieldName);
        if isempty(value) || (isstring(value) && all(strlength(value) == 0))
            metadata = rmfield(metadata, fieldName);
        elseif any(computedNames == fieldName)
            warning("nansen:nwb:metadataIgnored", ...
                ['%s is taken from the recording, so the value in the ', ...
                 'item''s metadata is ignored.'], fieldName)
            metadata = rmfield(metadata, fieldName);
        end
    end
end

function clampMode = defaultClampMode(unit, variableName)
%defaultClampMode - The clamp mode whose response is recorded in a unit

    [~, ~, ~, isStimulusInCurrentClamp] = seriesForUnit(unit, "current", variableName);
    if isStimulusInCurrentClamp
        clampMode = "voltage";
    else
        clampMode = "current";
    end
end

function [startTimes, note] = sweepStartTimesOf(recording, numSweeps, variableName)
%sweepStartTimesOf - Sweep start times in seconds, and a note when they are not known
%
%   abfload gives sweepStartInPts in samples of one channel from the
%   start of the recording, read from the file's synch array. Without
%   usable start times every sweep starts at 0, and the note, written
%   into each series' comments, says why.

    startTimes = zeros(1, numSweeps);
    note = "Sweep start times are not recorded in the file; every sweep starts at 0.";
    if ~isfield(recording, "Header") || ~isstruct(recording.Header) ...
            || ~isfield(recording.Header, "sweepStartInPts")
        return
    end

    startInSamples = double(recording.Header.sweepStartInPts(:))';
    if numel(startInSamples) ~= numSweeps
        warning("nansen:nwb:sweepStartTimesMismatch", ...
            ['''%s'' records %d sweep start times for %d sweeps, so they ', ...
             'cannot be matched to the sweeps; every sweep starts at 0.'], ...
            variableName, numel(startInSamples), numSweeps)
        note = "The file's sweep start times do not match its sweeps; every sweep starts at 0.";
        return
    end

    startTimes = startInSamples / recording.SamplingRate;
    note = "";
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

function [constructor, storedUnit, conversion, isStimulus] = seriesForUnit(unit, clampMode, variableName)
%seriesForUnit - The series class and the conversion a channel's unit calls for
%
%   In current clamp the potential is the response and the current the
%   stimulus; in voltage clamp it is the other way round. NWB stores
%   potentials in volts and currents in amperes; data_conversion carries
%   the factor from the recorded unit.

    switch strtrim(unit)
        case "V"
            isVoltage = true; conversion = 1;
        case "mV"
            isVoltage = true; conversion = 1e-3;
        case "A"
            isVoltage = false; conversion = 1;
        case "nA"
            isVoltage = false; conversion = 1e-9;
        case "pA"
            isVoltage = false; conversion = 1e-12;
        otherwise
            error("nansen:nwb:invalidConverterInput", ...
                ['A channel of ''%s'' is recorded in ''%s'', which is neither ', ...
                 'a voltage (V, mV) nor a current (A, nA, pA), so it cannot ', ...
                 'be stored as a clamp series.'], variableName, unit)
    end

    if isVoltage
        storedUnit = 'volts';
    else
        storedUnit = 'amperes';
    end

    isStimulus = isVoltage == (clampMode == "voltage");
    if clampMode == "current" && ~isStimulus
        constructor = @types.core.CurrentClampSeries;
    elseif clampMode == "current"
        constructor = @types.core.CurrentClampStimulusSeries;
    elseif ~isStimulus
        constructor = @types.core.VoltageClampSeries;
    else
        constructor = @types.core.VoltageClampStimulusSeries;
    end
end

function labels = channelLabels(channelNames, numChannels)
%channelLabels - The label each channel's series names carry
%
%   A channel's own name, or "ch<N>" when the name is blank or another
%   channel has it too: two series with one name would leave only the
%   second in the file.

    names = strings(1, numChannels);
    numNamed = min(numel(channelNames), numChannels);
    names(1:numNamed) = strtrim(channelNames(1:numNamed));

    [~, ~, groupIndex] = unique(names);
    counts = accumarray(groupIndex(:), 1);
    isShared = reshape(counts(groupIndex) > 1, 1, []);

    labels = "ch" + (1:numChannels);
    isUsable = strlength(names) > 0 & ~isShared;
    labels(isUsable) = names(isUsable);
end

function name = seriesName(baseName, channelLabel, numChannels, sweep)
%seriesName - <item>[_<channel>]_sweep<nnn>

    name = baseName;
    if numChannels > 1
        name = name + "_" + channelLabel;
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
