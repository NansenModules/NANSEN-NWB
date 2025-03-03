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

    % Create roi response series
    rrs = types.core.RoiResponseSeries(...
        'data', signalArray.Variables', ... % Transpose to get time along second dimension
        'data_unit', 'fluorescence intensity', ...
        'starting_time', 0, ...
        'starting_time_rate', signalArray.Properties.SampleRate );
end
