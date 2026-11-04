function rrs = convertRoiResponses(signalArray, options)
%convertRoiResponses - Convert a signal array to a RoiResponseSeries
%
% Syntax:
%   roiResponseSeries = convertRoiResponses(signalArray) converts a
%   timetable with one column per ROI into a RoiResponseSeries timed by
%   the timetable's sample rate.
%
%   roiResponseSeries = convertRoiResponses(signalArray, SamplingRate=RATE)
%   converts a numeric matrix with one row per sample and one column per
%   ROI, sampled at RATE Hz. This is how NANSEN saves the RoiSignals_*
%   variables.
%
% Input Arguments:
%   signalArray  - Timetable, or double or single matrix of samples by ROIs.
%   SamplingRate - Samples per second. Required for a matrix, which
%                  carries no timing of its own; ignored for a timetable.
%
% Output Arguments:
%   rrs         - The resulting RoiResponseSeries object.
%
% Errors:
%   nansen:nwb:missingSamplingRate - signalArray is a matrix and no
%                   SamplingRate was given.
%   nansen:nwb:unsupportedRoiSignalShape - signalArray has more than two
%                   dimensions, for example several neuropil regions per ROI.

    arguments
        signalArray {mustBeA(signalArray, ["timetable", "double", "single"])}
        options.SamplingRate double {mustBeScalarOrEmpty, mustBePositive} = []
    end

    % Todo: Get time props from timetable (utility method), i.e timestamps
    % or starting_time

    if istimetable(signalArray)
        samplesByRois = signalArray.Variables;
        samplingRate = signalArray.Properties.SampleRate;
    else
        if ~ismatrix(signalArray)
            error("nansen:nwb:unsupportedRoiSignalShape", ...
                ['ROI signals must be a matrix of samples by ROIs, but ', ...
                 'this one has size %s.'], mat2str(size(signalArray)))
        end
        if isempty(options.SamplingRate)
            error("nansen:nwb:missingSamplingRate", ...
                ['A matrix of ROI signals carries no timing. Set ', ...
                 'ConverterArgs.SamplingRate to the frame rate of the ', ...
                 'recording, in Hz.'])
        end
        samplesByRois = signalArray;
        samplingRate = options.SamplingRate;
    end

    numericData = samplesByRois';  % Transpose to get time along second dimension

    chunkSize = getChunkSize(numericData, {64, 'flex'}, 10e6); % 10MB
    maxSize = size(numericData);

    dataPipeArgs = {...
        "data", numericData, ...
        "maxSize", maxSize, ...
        "chunkSize", chunkSize, ...
        "hasShuffle", true, ...
        "compressionLevel", 3 };

    data = types.untyped.DataPipe(dataPipeArgs{:});

    % Create roi response series
    rrs = types.core.RoiResponseSeries(...
        'data', data, ...
        'data_unit', 'fluorescence intensity', ...
        'starting_time', 0, ...
        'starting_time_rate', samplingRate );
end

function chunkSize = getChunkSize(A, dimensionConstraints, targetChunkSize)

    info = whos("A");
    elementSize = info.bytes / numel(A); % bytes per element

    % Determine the target number of elements per chunk.
    targetNumElements = targetChunkSize / elementSize;

    flexLength = round(targetNumElements / dimensionConstraints{1});
    chunkSize = [ dimensionConstraints{1}, flexLength ];
end
