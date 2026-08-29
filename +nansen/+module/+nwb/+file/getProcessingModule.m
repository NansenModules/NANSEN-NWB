function processingModule = getProcessingModule(nwbFile, name, description)
% getProcessingModule - Get (or create) a processing module on an NWB file
%
%   Syntax:
%     processingModule = nansen.module.nwb.file.getProcessingModule(nwbFile, name)
%     processingModule = nansen.module.nwb.file.getProcessingModule(nwbFile, name, description)
%
%   Input Arguments:
%     nwbFile     - An NWB file object. Type: NwbFile
%     name        - Name of the processing module. Type: string
%     description - Description used when creating a new module. If the
%                   module does not exist and description is not provided,
%                   an error is thrown. Default: missing
%
%   Output Arguments:
%     processingModule - The processing module object.
%
%   See also: NwbFile

    arguments
        nwbFile     (1,1) NwbFile
        name        (1,1) string
        description (1,1) string = missing
    end

    if nwbFile.processing.isKey(name)
        processingModule = nwbFile.processing.get(name);
    else
        if ismissing(description)
            error('nansen:nwb:missingDescription', ...
                ['A processing module with name "%s" does not exist. ', ...
                 'Provide a description as a third argument to create it.'], ...
                name)
        end
        processingModule = feval( ...
            nansen.module.nwb.internal.lookup.getMatNwbTypeName('core', 'ProcessingModule'), ...
            'description', char(description));
        nwbFile.processing.set(name, processingModule);
    end
end
