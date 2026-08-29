classdef ProcessingModule < handle
%ProcessingModule - Enumeration of the NWB processing modules
%   ProcessingModule lists the processing modules a converted data
%   variable can be placed in, one per recording modality. It applies
%   when the variable's primary group is Processing.
%
%   Note: types.core.ProcessingModule is matnwb's class for a module
%   itself; this enumeration only names them
%
%   See also NeuroDataType, PrimaryGroupName

    enumeration
        ecephys % extracellular electrophysiology
        icephys % intracellular electrophysiology
        ophys % optical physiology
        behavior % behavior
    end
end
