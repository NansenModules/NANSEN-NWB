function nwbFile = placeNeurodata(nwbFile, neuroData, placement, defaultName)
%placeNeurodata Place converted MatNWB objects in the configured location.

    arguments
        nwbFile (1,1) NwbFile
        neuroData
        placement (1,1) struct
        defaultName (1,1) string = ""
    end

    if isstruct(neuroData) && all(isfield(neuroData, {'name', 'data'}))
        for i = 1:numel(neuroData)
            nwbFile = nansen.module.nwb.conversion.placeNeurodata( ...
                nwbFile, neuroData(i).data, placement, string(neuroData(i).name));
        end
        return
    end

    name = defaultName;
    if isfield(placement, "Name") && strlength(string(placement.Name)) > 0
        name = string(placement.Name);
    end
    if strlength(name) == 0
        error("NansenNwb:MissingNwbObjectName", ...
            "A name is required when placing converted NWB data.")
    end

    primaryGroup = getPlacementValue(placement, "PrimaryGroup", "Acquisition");
    switch primaryGroup
        case "Acquisition"
            nwbFile.acquisition.set(char(name), neuroData);

        case "Processing"
            moduleName = getPlacementValue(placement, "NwbModule", "");
            if strlength(moduleName) == 0
                error("NansenNwb:MissingProcessingModule", ...
                    "NwbModule is required when placing data in the Processing group.")
            end
            moduleDescription = sprintf("Processing module for %s", moduleName);
            processingModule = nansen.module.nwb.file.getProcessingModule( ...
                nwbFile, moduleName, moduleDescription);
            if isa(neuroData, "types.hdmf_common.DynamicTable")
                processingModule.dynamictable.set(char(name), neuroData);
            else
                processingModule.nwbdatainterface.set(char(name), neuroData);
            end

        case "Intervals"
            nwbFile.intervals.set(char(name), neuroData);

        case "Analysis"
            nwbFile.analysis.set(char(name), neuroData);

        case "Stimulus"
            nwbFile.stimulus_presentation.set(char(name), neuroData);

        otherwise
            error("NansenNwb:UnsupportedPrimaryGroup", ...
                "Unsupported NWB primary group: %s", primaryGroup)
    end
end

function value = getPlacementValue(placement, fieldName, defaultValue)
    fieldName = char(fieldName);
    if isfield(placement, fieldName) && ~isempty(placement.(fieldName))
        value = string(placement.(fieldName));
    else
        value = string(defaultValue);
    end
end
