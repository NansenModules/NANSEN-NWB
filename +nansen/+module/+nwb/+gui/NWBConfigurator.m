classdef NWBConfigurator < applify.MultiPageApp

% Todo:
% 
%   [x] Load/save NWB configuration data from this class.
%   [ ] Set/get relevant pieces of configuration data to subcomponents
%   [ ] How to increase margins?

    properties (Constant, Access = protected)
        AppName = 'NWB Configurator'
    end

    properties (Constant, Access = protected)
        PageTitles = ["Data Variables", "Tables"]
    end

    properties (SetAccess = private)
        FilePath (1,1) string = missing
        NWBConfigurationData % Todo: Should this be a "file" object?
    end

    % Page modules are added as dependent properties to make them more
    % explicitly expressed within this subclass.
    properties (Dependent, Access = private)
        DataVariableConfigurator
        DynamicTableConfigurator
    end
    
    methods % Constructor
    
        function obj = NWBConfigurator(nwbConfigurationData, options)
            arguments
                nwbConfigurationData
                %options.?nansen.module.nwb.gui.NWBConfigurator
                options.FilePath (1,1) string = missing 
            end

            % Assign input to properties
            obj.NWBConfigurationData = nwbConfigurationData;
            
            if ~ismissing(options.FilePath)
                obj.FilePath = options.FilePath;
            end

            obj.initializeModules()

            %obj.Figure.SizeChangedFcn = @(s,e) obj.updateSize;
            obj.Figure.CloseRequestFcn = @(s,e) obj.onFigureClosed;

            if ~nargout; clear obj; end
        end
        
    end

    methods % Set/Get

        function value = get.DataVariableConfigurator(obj)
            value = obj.PageModules{"Data Variables"};
        end
        function value = get.DynamicTableConfigurator(obj)
            value = obj.PageModules{"Tables"};
        end
    end

    methods 
        
        function saveNwbConfigurationData(obj)
        % saveNwbConfigurationData - Save NWB configuration to file

            nwbConfigurationData = obj.NWBConfigurationData;

            % Get current table data from the Datavariable module.
            dataItems = table2struct(obj.DataVariableConfigurator.Data);
            nwbConfigurationData.DataItems = dataItems;

            % Dynamic tables:
            if isConfigured(obj.DynamicTableConfigurator.DynamicTable)
                keys = obj.DynamicTableConfigurator.DynamicTable.keys();
                for key = keys
                    thisTable = obj.DynamicTableConfigurator.DynamicTable(key).Data;
                    subs = getSubsFromKey(key);
                    nwbConfigurationData = subsasgn(nwbConfigurationData, subs, thisTable);
                end
            end
            save(obj.FilePath, 'nwbConfigurationData')

            % Update original table data to last saved
            % version
            obj.DataVariableConfigurator.markClean()
        end
    end

    methods (Access = protected) % Creation
        function module = createPageModule(app, hTabContainer)

            switch hTabContainer.Title
                case "Data Variables"
                    module = nansen.module.nwb.gui.DataVariableConfigTable(...
                        hTabContainer, app.NWBConfigurationData);
                case "Tables"
                    module = nansen.module.nwb.gui.DynamicTableCollection(...
                        hTabContainer, app.NWBConfigurationData);
                otherwise
                    module = [];
            end
        end
    end

    methods (Access = private) % Internal callbacks

        function onFigureClosed(obj)
            
            isDirty = obj.DataVariableConfigurator.IsDirty || obj.DynamicTableConfigurator.isDirty();

            if isDirty
                message = sprintf('Save changes to NWB Configuration?');%, obj.NWBConfigurationData.PipelineName);
                title = 'Confirm Save';

                answer = questdlg(message, title, 'Yes', 'No', 'Cancel', 'Yes');

                switch answer

                    case 'Yes'
                        if ismissing(obj.FilePath)
                            error('Filepath is not set')
                            % Todo:
                            [filename, folder] = uigetfile('.m')
                        else
                            obj.saveNwbConfigurationData()
                            obj.DynamicTableConfigurator.deactivate()
                        end
                    case 'No'

                    otherwise
                        return
                end
            end
            
            delete(obj.Figure)
        end
    end
    
end


function subs = getSubsFromKey(key)                
    nestedFieldNames = strsplit(key, '_');
    subs = struct('type', '.', 'subs', cellstr(nestedFieldNames));
end