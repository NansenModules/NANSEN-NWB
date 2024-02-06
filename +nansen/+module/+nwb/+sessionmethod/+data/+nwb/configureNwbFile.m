function varargout = configureNwbFile(sessionObject, options)
% configureNwbFile - Configure an NWB file for a session
%
%   Customize the configuration of an NWB file for an individual or multiple
%   sessions

% Todo: make batch...

import nansen.session.SessionMethod


% % % % % % % % % % % % CONFIGURATION CODE BLOCK % % % % % % % % % % % % 
% Create a struct of default parameters (if applicable) and specify one or 
% more attributes (see nansen.session.SessionMethod.setAttributes) for 
% details. You can use the local function "getDefaultParameters" at the 
% bottom of this file to define default parameters.

    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'queueable'};
    
    % Todo: Provide each of the configured NWB files as alternatives
    % nwbFiles = getNwbFileNames();
    % ATTRIBUTES = [ATTRIBUTES, {'Alternatives', nwbFiles}];
    

% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % % 
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - - 
   
    % % % Initialization block for a session method function.

    if ~nargin && nargout > 0
        fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
        varargout = {fcnAttributes};   return
    end
    
    params.Alternative = datalocationNames{1}; % Set a default value.

    % % % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, true, varargin);
    
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % 
% Sketch for session method
% Sketch for session method

    % options: 
    % - File (if there are multiple configurations)
    % - Mode : append, rewrite 

    %% Initialize configurations

    % Load default NWB Conversion settings

    % Load session specific NWB conversion setting

    % Merge

    % Create filepath

    %% Open or create NWB file depending on if file exists.

    %% Loop through each variable of the NWB configuration
       
    % Get the data
    data = sessionObject.loadData(variableName);

    % Get the appropriate conversion function.


    %% Export the file



end

function params = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    params = struct();
end