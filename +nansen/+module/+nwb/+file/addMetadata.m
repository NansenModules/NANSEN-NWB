function addMetadata(nwbFile, name, nwbObject)
% addMetadata - Add metadata to NWB file
%
%   This will add a metadata type to the correct location in an nwb file,
%   typically in the general group. Note: In matnwb, all the groups and
%   subgroups of an NwbFile object are flattened and names are concatenated
%   using underscores.
%
%   Input arguments:
%       nwbFile   : An instance of an NWB File object
%       name      : The name which will be used for adding an object to the
%                   NWB file
%       nwbObject : An NWB object (i.e metadata type) to add to the NWB
%                   file.

%   Todo: 
%       [ ] Generate a mapping from type to general based on file schema
%
%   Notes: 
%       1) nwbFile.{prop}.set() will output the created set, so remember 
%          to add a semicolon.
%       2) Name for ElectrodesTable should be reconsidered, this is
%          currently hardcoded throughout

    arguments
        nwbFile (1,1) matnwb.types.core.NWBFile
        name (1,1) string
        nwbObject (1,1) matnwb.types.hdmf_common.Container
    end
    
    switch class(nwbObject)
            
        case "matnwb.types.core.Device"
            nwbFile.general_devices.set(name, nwbObject);

        case "matnwb.types.core.ImagingPlane"
            nwbFile.general_optophysiology.set(name, nwbObject);

        case "matnwb.types.hdmf_common.DynamicTable"
            switch name
                case "ElectrodesTable"
                    nwbFile.general_extracellular_ephys_electrodes = nwbObject;
                otherwise
                    error('Unhandled dynamic table')
            end

        otherwise
            error('Unhandled neurodata type')
    end
end
