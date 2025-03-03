function rrs = convertRoiResponses(signalArray)
% convertRoiResponses - Converts the provided signal array into a RoiResponseSeries object.
% 
% Syntax:
%   roiResponseSeries = convertRoiResponses(signalArray) converts a signal 
%   array into a RoiResponseSeries.
% 
% Input Arguments:
%   signalArray - The array of signals to be converted.
% 
% Output Arguments:
%   rrs         - The resulting RoiResponseSeries object containing the converted data.

    arguments
        signalArray
    end

    % Todo: Get time props from timetable (utility method), i.e timestamps
    % or starting_time

    numericData = signalArray.Variables';  % Transpose to get time along second dimension

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
        'starting_time_rate', signalArray.Properties.SampleRate );
end

function chunkSize = getChunkSize(A, dimensionConstraints, targetChunkSize)

    info = whos("A");
    elementSize = info.bytes / numel(A); % bytes per element

    % Determine the target number of elements per chunk.
    targetNumElements = targetChunkSize / elementSize;
    
    flexLength = round(targetNumElements / dimensionConstraints{1});
    chunkSize = [ dimensionConstraints{1}, flexLength ];
end

