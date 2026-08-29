function electrodeGroup = getElectrodesTableGroup()
%getElectrodesTableGroup - Get the schema group for the electrodes table
%   electrodeGroup = getElectrodesTableGroup() returns the schema entry
%   for the electrodes table, found by walking NWBFile down through
%   general and extracellular_ephys.
%
%   From NWB 2.9 the group carries the ElectrodesTable type rather than
%   the columns themselves, so its datasets are empty. Read the columns
%   from the type instead.
%
%   See also nansen.module.nwb.internal.dtable.initializeElectrodesTable

    import nansen.module.nwb.internal.schemautil.getProcessedClass

    [classInfo, ~] = getProcessedClass('NWBFile');

    isGeneralGroup = strcmp({classInfo.subgroups.name}, 'general');
    generalGroup = classInfo.subgroups(isGeneralGroup);

    isEcephysGroup = strcmp({generalGroup.subgroups.name}, 'extracellular_ephys');
    ecephysGroup = generalGroup.subgroups(isEcephysGroup);

    isElectrodeGroup = strcmp({ecephysGroup.subgroups.name}, 'electrodes');
    electrodeGroup = ecephysGroup.subgroups(isElectrodeGroup);
end
