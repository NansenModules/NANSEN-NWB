function varargout = manageNwbFiles(sessionObject, options)

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