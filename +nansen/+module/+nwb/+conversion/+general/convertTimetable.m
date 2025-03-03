function timeseriesSet = convertTimetable(TT, options)
% convertTimetable - Convert a time table into a set of NWB Timeseries objects
% 
% Syntax:
%   convertedData = convertTimetable(TT, options) 
%   This function takes a time table and converts it into a specified format.
% 
% Input Arguments:
%   TT - The timetable to be converted
% 
% Output Arguments:
%   convertedData - The converted data in the desired format

% Todo:
% Add containertype as option? then add set to container?


    arguments
        TT timetable
        options.NeurodataType = @types.core.TimeSeries
        options.Metadata (1,1) struct = struct
    end
    
    variableNames = TT.Properties.VariableNames;
    
    variableDescriptions = string( TT.Properties.VariableDescriptions );
    if isempty(variableDescriptions)
        variableDescriptions = repmat("no description", 1, numel(variableNames));
    end

    variableUnits = string( TT.Properties.VariableUnits );
    if isempty(variableUnits)
        variableUnits = repmat("n/a", 1, numel(variableNames));
    end

    metadataNvPairs = namedargs2cell(options.Metadata);

    timeseriesSet = types.untyped.Set();
    
    for i = 1:numel(variableNames)
        
        name  = variableNames{i};
        
        assert(ismatrix(TT.(name)), ...
            'This converter only works for timeseries matrices, i.e vectors and 2D arrays')

        timeSeries = feval(options.NeurodataType, ...
            'description', char(variableDescriptions(i)), ...
            'data', TT.(name)', ... % Transpose to get time on last dimension
            'data_unit', char(variableUnits(i)), ...
            'timestamps', seconds( TT.Time ), ...
            metadataNvPairs{:});

        timeseriesSet.set(name, timeSeries);
    end 
end
