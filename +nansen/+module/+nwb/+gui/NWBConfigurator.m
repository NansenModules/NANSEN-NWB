classdef NWBConfigurator < applify.MultiPageApp
    %NWBConfigurator - App for configuring how a project converts to NWB
    %   OBJ = NWBConfigurator(nwbConfigurationData) opens the configurator
    %   on a configuration struct, with a page for data variables and a
    %   page for dynamic tables.
    %
    %   OBJ = NWBConfigurator(...,FilePath=VALUE) also sets the file the
    %   configuration is saved to. Without it, saving asks where to write.
    %
    %   NWBConfigurator functions:
    %       saveNWBConfigurationData - Save the configuration to file
    %
    %   NWBConfigurator properties:
    %       FilePath             - File the configuration is saved to
    %       NWBConfigurationData - The configuration being edited
    %
    %   See also nansen.module.nwb.file.initializeNWBFileConfiguration,
    %   nansen.module.nwb.file.checkNWBConfiguration

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
        FilePath (1,1) string = missing % File the configuration is saved to
        NWBConfigurationData % The configuration being edited. Todo: a "file" object?
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
                % options.?nansen.module.nwb.gui.NWBConfigurator
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
                'Callback', @(s,e) obj.saveNWBConfigurationData());
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

        function saveNWBConfigurationData(obj)
        %saveNWBConfigurationData - Save the configuration to file
        %   saveNWBConfigurationData(OBJ) writes the configuration to
        %   FilePath, marks the data variable page clean, and reports any
        %   problems it finds without blocking the save.

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

            % Warn about any configuration issues (non-blocking)
            obj.warnIfConfigurationIssues(dataItems)

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
            obj.saveNWBConfigurationData()
            delete(obj.Figure)
        end

        function onFigureClosed(obj)

            isDirty = obj.DataVariableConfigurator.IsDirty || obj.DynamicTableConfigurator.isDirty();

            if isDirty
                message = 'Save changes to NWB Configuration?';
                title = 'Confirm Save';

                answer = questdlg(message, title, 'Yes', 'No', 'Cancel', 'Yes');

                switch answer
                    case 'Yes'
                        % The configurator can be constructed without a
                        % file path, in which case ask where to save before
                        % closing. Treat a cancelled prompt like a
                        % cancelled close, leaving the figure open.
                        if ismissing(obj.FilePath) && ~obj.promptForFilePath()
                            return
                        end

                        obj.saveNWBConfigurationData()
                        obj.DynamicTableConfigurator.deactivate()
                    case 'No'
                        % discard changes
                    otherwise
                        return
                end
            end

            delete(obj.Figure)
        end

        function wasSelected = promptForFilePath(obj)
        % promptForFilePath - Ask where to save the configuration
        %
        %   Returns true if a location was chosen and assigned to FilePath,
        %   false if the user dismissed the dialog. The configuration is
        %   written with save, so the file is a MAT-file.

            [fileName, folderPath] = uiputfile( ...
                '*.mat', 'Save NWB Configuration', 'nwbConfiguration.mat');

            wasSelected = ~isequal(fileName, 0);

            if wasSelected
                obj.FilePath = string( fullfile(folderPath, fileName) );
            end
        end

        function warnIfConfigurationIssues(~, dataItems)
        % warnIfConfigurationIssues - Show a warning dialog for any issues
        %   found in the configuration. The save is not blocked — this is
        %   informational only.

            if isempty(dataItems)
                return
            end

            warnings = nansen.module.nwb.file.checkNWBConfiguration(dataItems);

            if isempty(warnings)
                return
            end

            % Build message: one bullet per warning
            bulletLines = strjoin( cellfun(@(w) sprintf('  \x2022 %s', w), ...
                warnings, 'UniformOutput', false), newline );

            message = sprintf( ...
                ['The configuration was saved, but the following issues ', ...
                 'were found:\n\n%s\n\n', ...
                 'Please review before writing NWB files.'], bulletLines);

            warndlg(message, 'NWB Configuration Warnings', 'modal')
        end
    end
end

function subs = getSubsFromKey(key)
    nestedFieldNames = strsplit(key, '_');
    subs = struct('type', '.', 'subs', cellstr(nestedFieldNames));
end
