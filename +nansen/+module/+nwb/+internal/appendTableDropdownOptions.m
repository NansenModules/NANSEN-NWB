function S = appendTableDropdownOptions(S, nwbNodeStack)

% Special function for creating a popup menu configuration struct for
% creating a dynamic table for the table property of a DynamicTableRegion
% instance

    arguments
        S (1,1) struct
        nwbNodeStack (1,:) nansen.module.nwb.internal.NwbNode
    end

    import nansen.module.nwb.internal.getMetadataInstances
    import nansen.module.nwb.internal.createNewNwbInstance
    import nansen.module.nwb.internal.lookup.getDynamicTableForRegionView

% Create OBJECT VIEW:

% There should be two cases:
%
%   1) Create a generic dynamic table or a specific dynamic table if it 
%      has a specified type
%   2) Create a singleton "special" dynamic table like e.g the electrodes
%      table. Any other?


    % Todo: Explain why using the second last item of the stack...
    ancestorNeuroDataType = nwbNodeStack(end-1).DefiningType;
    ancestorPropertyName = nwbNodeStack(end-1).PropertyName;
    propertyName = nwbNodeStack(end).PropertyName;
    %propertyType = nwbNodeStack(end).PropertyType; % Not used

    % Use a lookup function to figure out if a special table is going to be
    % created.
    linkedTableName = getDynamicTableForRegionView(ancestorNeuroDataType, ancestorPropertyName);

    % Load existing metadata instances for this neurodata type
    metadataInstances = nansen.module.nwb.internal.getMetadataInstances(linkedTableName);
    metadataInstances = cellstr(metadataInstances);
    
    % Specify custom configuration for a dropdown control.

    % Todo: Need a custom creation function for creating new tables...
    if isempty(metadataInstances)
        dropdownConfig = struct(...
            'AllowNoSelection', false, ...
            'CreateNewItemFcn', @(item, nwbNodes) ...
                nansen.module.nwb.internal.createNewDynamicTable(item, nwbNodeStack), ...
            'ItemName', linkedTableName );

        % Prepend the dropdown configuration to the list of instances. 
        % The structeditor will expect this config as the first cell of the
        % cell array.
        metadataInstances = {dropdownConfig}; %#ok<AGROW>
    end


    if isfield(S, propertyName)
        % Add _ to the end of the link name to create the "config" name
        configName = sprintf('%s_', propertyName);
        S.(configName) = metadataInstances;
        if isempty(S.(propertyName))
            % Make sure empty value is a char
            if ~isa(metadataInstances{1}, 'struct')
                % Select the first instance...
                S.(propertyName) = metadataInstances{1};
            else
                S.(propertyName) = '';
            end
        end
    else
        % I guess this should not happen so throw error if it does
        error('No field for linked type with name ''%s''', propertyName)
    end
end
