function addMetadataObject(nwbFile, name, nwbObject)
% addMetadataObject - Add metadata-like neurodata types to NWB file
%
%   This will add a metadata-like neurodata types to the correct location in an 
%   NWB file, typically in the general group. Some metadata types, like
%   Device, ImagingPlane or ElectrodeGroup should be placed in a specific
%   location of an NWB file. This is a utility function that adds a type to
%   it's default location in the NWB file.
%   
%   Note: In MatNWB, all the groups and subgroups of an NwbFile object are 
%   flattened and names are concatenated using underscores.
%
%   Input arguments:
%       nwbFile   : An instance of an NWB File object
%       name      : The name which will be used for adding an object to the
%                   NWB file
%       nwbObject : An NWB object (i.e metadata type) to add to the NWB
%                   file.

%   Todo: 
%       [ ] Programmatically generate a mapping from type to general based on 
%           file schema
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

    % Todo: Generate this programmatically:
    D = dictionary(...
                         "types.core.Device", "general_devices", ...
                   "types.core.ImagingPlane", "general_optophysiology", ...
                 "types.core.ElectrodeGroup", "general_extracellular_ephys", ...
         "types.core.IntracellularElectrode", "general_intracellular_ephys", ...
                    "types.core.LabMetaData", "general", ...
        "types.core.OptogeneticStimulusSite", "general_optogenetics" ...
        );
    

    if isKey(D, class(nwbObject))
        propertyName = D(class(nwbObject));
        nwbFile.(propertyName).set(name, nwbObject);
    else
        if isa(nwbObject, "matnwb.types.hdmf_common.DynamicTable")
            switch name
                case "ElectrodesTable"
                    nwbFile.general_extracellular_ephys_electrodes = nwbObject;
                otherwise
                    error('Unhandled dynamic table')
            end
        else
            error('Unhandled neurodata type')
        end
    end
end
