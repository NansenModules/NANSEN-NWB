classdef PrimaryGroupName < handle
%PrimaryGroupName - Enumeration of the top-level NWB file groups
%   PrimaryGroupName lists the groups of an NWB file a converted data
%   variable can be written into. The configuration table offers these
%   as the choices in its primary group column.
%
%   See also NeuroDataType, ProcessingModule

    enumeration
        Acquisition
        Processing
        Analysis
        Intervals
        Stimulus
    end
end
