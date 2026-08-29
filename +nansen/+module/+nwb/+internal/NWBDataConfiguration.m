classdef NWBDataConfiguration < handle
    %NWBDataConfiguration - How one data variable maps into an NWB file
    %   OBJ = NWBDataConfiguration() creates an empty configuration. Set
    %   its properties to say where a data variable belongs in the file
    %   and which neurodata type it converts to.
    %
    %   NWBDataConfiguration properties:
    %       PrimaryGroupName     - Top-level NWB group to write into
    %       NeuroDataType        - Neurodata type the variable converts to
    %       DataName             - Name the data is stored under
    %       ProcessingModuleName - Module to use when the group is
    %                              Processing
    %
    %   See also nansen.module.nwb.enum.PrimaryGroupName,
    %   nansen.module.nwb.enum.NeuroDataType

    properties
        PrimaryGroupName (1,1) nansen.module.nwb.enum.PrimaryGroupName % Top-level NWB group to write into
        NeuroDataType (1,1) nansen.module.nwb.enum.NeuroDataType % Neurodata type the variable converts to
        DataName (1,1) string % Name the data is stored under
    end

    properties
        ProcessingModuleName (1,1) string % Module to use when the group is Processing. Todo: standard types?
    end

    properties (Dependent)
        % IsProcessing - Is this a processing module?
        % IsProcessing -  Todo: useful?
    end
end
