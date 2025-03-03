function addProcessingModule(nwbFile, name, description)
% addProcessingModule - Adds a processing module to the NWB file.
%
% Syntax:
%   addProcessingModule(nwbFile, type, description)
%
% Input Arguments:
%   nwbFile       - The NWB file to which the processing module will be added.
%   name          - A string specifying the name of the processing module. 
%   description   - An optional string describing the processing module. 
%                   If not provided, a default description will be used.
%
% Output Arguments:
%   None

    arguments
        nwbFile
        name (1,1) string
        description (1,1) string = missing
    end

    defaultDescriptions = dictionary( ...
        'ophys', 'Processed optical physiology data', ...
        'ecephys', 'Processed electrophysiology data', ...
        'behavior', 'Processed behavioral data', ...
        'icehys', '' ...
        );
    
    if ismissing(description)
        if isKey(defaultDescriptions, name)
            description = defaultDescriptions(name);
        else
            error('Description is required')
        end
    end

    processingModule = types.core.ProcessingModule(...
        "description", char(description));

    nwbFile.processing.set(name, processingModule);
end
