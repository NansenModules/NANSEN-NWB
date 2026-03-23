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

    properties (Access = private) % UI Components
        SaveButton
        SaveAndCloseButton
    end

    properties (Constant, Access = private)
        SAVE_BUTTON_HEIGHT = 40
        SAVE_BUTTON_MARGIN = 10
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

            obj.Figure.CloseRequestFcn = @(s,e) obj.onFigureClosed;
            obj.hLayout.MainPanel.SizeChangedFcn = @(s,e) obj.updateLayoutPositions();

            if ~nargout; clear obj; end
        end
        
    end

    methods (Access = protected) % Layout overrides

        function updateLayoutPositions(obj)
            panelPosition = getpixelposition(obj.hLayout.MainPanel);
            panelWidth = panelPosition(3);
            panelHeight = panelPosition(4);

            buttonBottomY = obj.SAVE_BUTTON_MARGIN + 10;
            buttonWidth = 200;
            buttonSpacing = 15;
            totalButtonsWidth = 2 * buttonWidth + buttonSpacing;
            leftButtonX = (panelWidth - totalButtonsWidth) / 2;
            rightButtonX = leftButtonX + buttonWidth + buttonSpacing;

            tabGroupHeight = panelHeight ...
                - obj.SAVE_BUTTON_HEIGHT ...
                - 2 * obj.SAVE_BUTTON_MARGIN;

            obj.hLayout.TabGroup.Units = 'pixels';
            obj.hLayout.TabGroup.Position = [0, ...
                obj.SAVE_BUTTON_HEIGHT + 2 * obj.SAVE_BUTTON_MARGIN, ...
                panelWidth, ...
                tabGroupHeight];

            if ~isempty(obj.SaveButton) && isvalid(obj.SaveButton)
                obj.SaveButton.Position = [leftButtonX, buttonBottomY, buttonWidth, obj.SAVE_BUTTON_HEIGHT];
            end
            if ~isempty(obj.SaveAndCloseButton) && isvalid(obj.SaveAndCloseButton)
                obj.SaveAndCloseButton.Position = [rightButtonX, buttonBottomY, buttonWidth, obj.SAVE_BUTTON_HEIGHT];
            end
        end

        function createComponents(obj)
            obj.createTabPages()
            obj.SaveButton = uicontrol( ...
                'Parent', obj.hLayout.MainPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Save Configuration', ...
                'FontSize', 14, ...
                'Tooltip', 'Save NWB configuration', ...
                'Callback', @(s,e) obj.saveNwbConfigurationData());
            obj.SaveAndCloseButton = uicontrol( ...
                'Parent', obj.hLayout.MainPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Save and Close', ...
                'FontSize', 14, ...
                'Tooltip', 'Save NWB configuration and close', ...
                'Callback', @(s,e) obj.onSaveAndCloseButtonPushed());
            obj.updateLayoutPositions()
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

            % Update original table data to last saved version
            obj.DataVariableConfigurator.markClean()

            msgbox('NWB configuration saved successfully.', 'Save Successful', 'help')
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

        function onSaveAndCloseButtonPushed(obj)
            obj.saveNwbConfigurationData()
            delete(obj.Figure)
        end

        function onFigureClosed(obj)
            
            [hasMissingConfigurations, details] = obj.DataVariableConfigurator.hasMissingConfigurations();


            if hasMissingConfigurations
                varNameList = string({details.VariableName});
                varNameList = strjoin(" - " + varNameList, newline);
                message = sprintf('The following variables are not fully configured (Please ensure each variable in the list is assigned a group name and a neurodata type):\n%s\n\nAre you sure you want to quit?', varNameList);
                title = 'Confirm Quit';

                answer = questdlg(message, title, 'Yes', 'No', 'Cancel', 'Yes');
                switch answer

                    case 'Yes'
                        % continue
                    case 'No'
                        return
                    otherwise
                        return
                end
            end
            
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