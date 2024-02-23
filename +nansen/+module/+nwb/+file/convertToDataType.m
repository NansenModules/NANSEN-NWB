function neuroData = convertToDataType(metadata, data, neuroDataType)
% convertToDataType - Create an NWB "data" object
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
        metadata = metadata{1};

        [metadata, name] = utility.struct.popfield(metadata, 'name');

        % todo: recursive:
        neuroData = nansen.module.nwb.file.convertToDataType(metadata, data, neuroDataType);

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
                %assert(isContainerType)
                variables = data.Properties.VariableNames;

                time = seconds( data.Time );

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
                    neuroData = feval(fcn, 'data', data, 'timestamps', time, nvPairs{:});
                end

                %dataV = data{:,1};
                %nvPairs = [nvPairs, {'timestamps', seconds(data.Time), 'data' dataV}];
            
            elseif isa(data, 'timeseries')

            elseif isa(data, 'duration')
                time = seconds(data);
                data = 1:numel(data);
                neuroData = feval(fcn, 'data', data, 'timestamps', time, nvPairs{:});
            else
                
            end
    end
    
    % Get custom conversion function
    
    % Neurodata type
    % nwbData = feval(sprintf('types.core.%s', neuroDataType), nvPairs{:});
end
