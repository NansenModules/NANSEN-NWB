function nwbFile = placeNeurodata(nwbFile, neuroData, placement, defaultName)
%placeNeurodata - Put converted neurodata in its configured group
%   nwbFile = placeNeurodata(nwbFile,neuroData,PLACEMENT) adds neuroData
%   to nwbFile in the group PLACEMENT names, and returns the file.
%   PLACEMENT is a struct with fields Name, PrimaryGroup and NWBModule.
%
%   nwbFile = placeNeurodata(...,defaultName) also gives the name to use
%   when PLACEMENT does not carry one.
%
%   neuroData may be a single neurodata object, or a struct array with
%   name and data fields, in which case each element is placed under its
%   own name.
%
%   Errors:
%     nansen:nwb:missingNeurodataName - neither PLACEMENT nor defaultName
%                     supplies a name.
%     nansen:nwb:missingProcessingModule - the Processing group was named
%                     without a module to put the data in.
%     nansen:nwb:unsupportedPrimaryGroup - PLACEMENT names a group this
%                     function cannot write to.
%
%   See also nansen.module.nwb.conversion.resolvePlacement,
%   nansen.module.nwb.file.getProcessingModule

    arguments
        nwbFile (1,1) NwbFile
        neuroData
        placement (1,1) struct
        defaultName (1,1) string = ""
    end

    % A converter may return several named objects from one data item.
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
        error("nansen:nwb:missingNeurodataName", ...
            ['Converted data has no name to be stored under. Set ', ...
             'NWBVariableName on the data item.'])
    end

    primaryGroup = getPlacementValue(placement, "PrimaryGroup", "Acquisition");

    switch primaryGroup
        case "Acquisition"
            nwbFile.acquisition.set(char(name), neuroData);

        case "Processing"
            moduleName = getPlacementValue(placement, "NWBModule", "");
            if strlength(moduleName) == 0
                error("nansen:nwb:missingProcessingModule", ...
                    ['''%s'' is configured for the Processing group but ', ...
                     'names no module. Set NWBModule on the data item, for ', ...
                     'example to "ophys" or "behavior".'], name)
            end
            moduleDescription = sprintf("Processing module for %s", moduleName);
            processingModule = nansen.module.nwb.file.getProcessingModule( ...
                nwbFile, moduleName, moduleDescription);

            % Dynamic tables live in their own map on a processing module.
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
            error("nansen:nwb:unsupportedPrimaryGroup", ...
                ['''%s'' is not an NWB group this module writes to. Use ', ...
                 'one of: Acquisition, Processing, Analysis, Intervals, ', ...
                 'Stimulus.'], primaryGroup)
    end
end

function value = getPlacementValue(placement, fieldName, defaultValue)
%getPlacementValue - Read a placement field, or its default

    if isfield(placement, fieldName) && ~isempty(placement.(fieldName))
        value = string(placement.(fieldName));
    else
        value = string(defaultValue);
    end
end
