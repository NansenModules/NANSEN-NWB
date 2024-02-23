classdef UIDynamicTableRegionSelector < uiw.abstract.AppWindow
% UIDynamicTableRegionSelector - A dialog app for selecting a region of a
% dynamic table.

%   Todo: 
%     [ ] Should there be a description field here or elsewhere?
%     [ ] Should there be a dialog in the constructor to select table, or
%       should this be handles before opening this app.?

    properties(Constant, Access=protected)
        AppName = 'Dynamic Table Region Selector'
    end
    
    properties
        DynamicTable % Dynamic table to select region (rows) from
        Selection
    end

    properties (Access = private) % UI Components 
        UIDynamicTable
        SelectRowsButton
        InstructionTextbox
    end

    properties (Access = private)
        Data
    end

    methods %Constructor

        function [app, data] = UIDynamicTableRegionSelector(dynamicTable)
            
            app.DynamicTable = dynamicTable;

            app.createLayout()
            app.createComponents()

            app.Figure.SizeChangedFcn = @(s,e) app.updatePanelPositions;
            app.Figure.WindowStyle = 'modal';
            data = containers.Map;
            data('State') = "Incomplete";
            app.Data = data;
            if ~nargout; clear app; end
        end
    end

    methods 
        function uiwait(app)
            uiwait(app.Figure)
        end

        function selectedRows = getSelection(app)
            selectedRows = app.UIDynamicTable.getRowSelection();
        end

        function setSelection(app, selectedRows)
             app.UIDynamicTable.setRowSelection(selectedRows);
        end
    end

    methods (Access = private) % Creation

        function createLayout(app)
        % createLayout - Create the panels for the app layout
            app.hLayout.HeaderPanel = uipanel('Parent', app.Figure, 'Tag', 'Header Panel');
            app.hLayout.HeaderPanel.BorderType = 'none';

            app.hLayout.MainPanel = uipanel('Parent', app.Figure, 'Tag', 'Main Panel');
            app.hLayout.MainPanel.BorderType = 'none';
            
            app.hLayout.FooterPanel = uipanel('Parent', app.Figure, 'Tag', 'Footer Panel');
            app.hLayout.FooterPanel.BorderType = 'none';
            
            app.updatePanelPositions()
        end

        function createComponents(app)
    
            app.createHeaderText()
            
            app.createFinishButton()
            
            tableName = app.DynamicTable.Properties.DimensionNames{1};
            app.UIDynamicTable = nansen.module.nwb.gui.UIDynamicTable(...
                app.DynamicTable, 'TableName', tableName, ...
                'Parent', app.hLayout.MainPanel, ...
                'SelectionMode', 'discontiguous');
        end

        function createHeaderText(app)
            %app.hLayout.HeaderPanel.BackgroundColor = ones(1,3)*0.6;
            app.InstructionTextbox = uicontrol(app.hLayout.HeaderPanel , 'Style', 'text');
            app.InstructionTextbox.String = 'Select one or more rows to represent a region of the dynamic table and press "Use Row Selection" when done.';
            app.InstructionTextbox.HorizontalAlignment = 'left';
            app.InstructionTextbox.FontSize = 14;
            app.InstructionTextbox.Units = 'normalized';
            app.InstructionTextbox.Position = [0,0,1,1];
        end
        
        function createFinishButton(app)
            % Create buttons
            buttonProps = {'Style', uim.style.buttonLightMode, ...
                'HorizontalTextAlignment', 'center'};
            
            app.SelectRowsButton = uim.control.Button_(app.hLayout.FooterPanel, 'Text', 'Use Row Selection', buttonProps{:});
            app.SelectRowsButton.TooltipYOffset = 10;
            app.SelectRowsButton.Size = [250, 30];
            app.SelectRowsButton.HorizontalAlignment = 'center';
            app.SelectRowsButton.VerticalAlignment = 'middle';
            app.SelectRowsButton.Location = 'center';
            app.SelectRowsButton.FontSize = 14;
            app.SelectRowsButton.FontWeight = 'b';
            app.SelectRowsButton.Callback = @app.onUseRowSelectionButtonClicked;
        end
    end

    methods (Access = private) % Update
        
        function updatePanelPositions(app)
        % updatePanelPositions - Update the layout (panel positions)

            persistent T1 T2

            MARGIN = [30,30,30,40];

            figurePosition = getpixelposition(app.Figure);
            
            totalWidth = figurePosition(3)-MARGIN(1)-MARGIN(3);
            totalHeight = figurePosition(4)-MARGIN(2)-MARGIN(4);

            % h+w of autocomplete and buttons:
            componentHeight = [50, 1, 50]; % Bottom up
            
            % Calculate position:
            [y, h] = uim.utility.layout.subdividePosition(MARGIN(2), ...
                totalHeight, componentHeight, 15);

            x = MARGIN(1);
            
            footerPanelPosition = [x,y(1),totalWidth,h(1)];
            mainPanelPosition = [x,y(2),totalWidth,h(2)];
            headerPanelPosition = [x,y(3),totalWidth,h(3)];

            positionArray = [headerPanelPosition; mainPanelPosition; footerPanelPosition];
            uim.utility.setpixelpositionnonscalar(struct2array(app.hLayout), positionArray)
        end
    
        function tf = assertRowsSelected(app)

            selectedRows = app.UIDynamicTable.getRowSelection();
            tf = ~isempty(selectedRows);

            if ~tf
                msgbox('Please select one or more rows.','Selection Required', 'error')
            end
        end
    end

    methods (Access = private) % Callbacks

        function onUseRowSelectionButtonClicked(app, src, evt)
            
            % Check that there is a row selection
            tf = app.assertRowsSelected();
            if ~tf; return; end

            % Store on object
            %app.Selection = app.getSelection();
            app.Data('Selection') = app.getSelection();
            app.Data('Table') = app.UIDynamicTable.DynamicTable;
            app.Data('State') = "Saved";
            
            uiresume(app.Figure)
            app.Figure.CloseRequestFcn = []; 
            
            % Disable deletion of class when figure is deleted
            delete(app.Figure)
        end
    end
end