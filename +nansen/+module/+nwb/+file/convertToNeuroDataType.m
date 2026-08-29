function neuroData = convertToNeuroDataType(metadata, data, neuroDataType)
%convertToNeuroDataType - Create an NWB "data" object
%
%   Create an NWB "data" object given metadata, data and the name of the
%   neurodata type.
%
%   Note: Work in progress, currently handles timeseries somewhat...

%   Todo:
%     [ ] Handle other types.
%        [ ] Dynamic tables?
%        [ ] Images

    arguments
        metadata (1,1) struct
        data % ?? Could be whatever?
        neuroDataType (1,1) string
    end

    import nansen.module.nwb.internal.lookup.getFullTypeName

    % Special case: Handle "wrapper" types.
    wrapperNames = nansen.module.nwb.internal.lookup.getWrapperClassNames();
    isContainerType = any(wrapperNames==neuroDataType);
    
    if isContainerType
        classInfo = nansen.module.nwb.internal.schemautil.getProcessedClass(neuroDataType);
        containerType = neuroDataType;
        neuroDataType = classInfo.subgroups.type;
        
        metadata = struct2cell(metadata);
        if ~isempty(metadata)
            metadata = metadata{1};
            [metadata, ~] = utility.struct.popfield(metadata, 'name');
        else
            metadata = struct;
        end

        % todo: recursive:
        neuroData = nansen.module.nwb.file.convertToNeuroDataType(metadata, data, neuroDataType);

        fcn = str2func( getFullTypeName(containerType) );

        if isa(neuroData, 'struct')
            nvPairs = [{neuroData.name};{neuroData.data}];
            neuroData = feval(fcn, nvPairs{:});
        else
            neuroData = feval(fcn, neuroDataType, neuroData);
        end
        return
    end

    if isempty(metadata)
        nvPairs = {};
    else
        nvPairs = namedargs2cell(metadata);
    end

    % todo: resolve base neurodata type
    baseNeurodataType = "Timeseries";
    fcn = str2func( getFullTypeName(neuroDataType) );

    switch baseNeurodataType
        case "Timeseries"
    
            if isa(data, 'timetable')
                % assert(isContainerType)
                variables = data.Properties.VariableNames;
                
                % time = seconds( data.Time );
                time = seconds( data.Properties.RowTimes );

                if numel(variables) > 1
                    % % assert(isContainerType, ...
                    % %     'NeuroDataType must be one of the following to support adding multiple timetable variables: \n\n%s\n', strjoin("  " + wrapperNames, newline))
                    
                    neuroData = struct;
                    for i = 1:numel(variables)
                        thisData = data.(variables{i});
                        neuroData(i).name = variables{i};
                        neuroData(i).data = feval(fcn, 'data', thisData, 'timestamps', time, nvPairs{:});
                    end
                else
                    data = data.(variables{1});
                    if ismatrix(data) && size(data, 1) == numel(time)
                        data = transpose(data);
                    elseif ismatrix(data) && size(data, 2) == numel(time)
                        % Do nothing
                    else
                        error('Unhandled data shape')
                    end
                    neuroData = feval(fcn, 'data', data, 'timestamps', time, nvPairs{:});
                end

                % dataV = data{:,1};
                % nvPairs = [nvPairs, {'timestamps', seconds(data.Time), 'data' dataV}];
            
            elseif isa(data, 'timeseries')
                neuroData = feval(fcn, 'data', data.Data, ...
                    'timestamps', data.Time, nvPairs{:});

            elseif isa(data, 'duration')
                time = seconds(data);
                data = 1:numel(data);
                neuroData = feval(fcn, 'data', data, 'timestamps', time, nvPairs{:});

            else
                % Anything else is handed to the type as its data, with the
                % metadata supplying whatever else the type needs. Data
                % that carries no time of its own has to be given one, so
                % the metadata must name either timestamps or a starting
                % time and rate.
                if ~hasTimeReference(metadata)
                    error('nansen:nwb:missingTimeReference', ...
                        ['%s data has no time information of its own, so ', ...
                         'the metadata must supply it. Set either ', ...
                         '"timestamps", or both "starting_time" and ', ...
                         '"starting_time_rate".'], class(data))
                end
                neuroData = feval(fcn, 'data', data, nvPairs{:});
            end
    end
    
    % Get custom conversion function

    % Neurodata type
    % nwbData = feval(sprintf('types.core.%s', neuroDataType), nvPairs{:});
end

function tf = hasTimeReference(metadata)
%hasTimeReference - True if the metadata says when the samples were taken

    hasTimestamps = isfield(metadata, 'timestamps') && ~isempty(metadata.timestamps);
    hasStartingTime = isfield(metadata, 'starting_time') && ...
        isfield(metadata, 'starting_time_rate');

    tf = hasTimestamps || hasStartingTime;
end
