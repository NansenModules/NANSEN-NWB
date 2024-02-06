classdef NWBDataConfiguration < handle

    properties
        PrimaryGroupName (1,1) nansen.module.nwb.enum.PrimaryGroupName
        NeuroDataType (1,1) nansen.module.nwb.enum.NeuroDataType
        DataName (1,1) string
    end

    properties
        ProcessingModuleName (1,1) string % Or make some standard types?
    end

    properties (Dependent)
        IsProcessing
    end
end