function electrodeGroup = getElectrodesTableGroup()

    import nansen.module.nwb.internal.schemautil.getProcessedClass

    [classInfo, ~] = getProcessedClass('NWBFile');

    isGeneralGroup = strcmp({classInfo.subgroups.name}, 'general');
    generalGroup = classInfo.subgroups(isGeneralGroup);

    isEcephysGroup = strcmp({generalGroup.subgroups.name}, 'extracellular_ephys');
    ecephysGroup = generalGroup.subgroups(isEcephysGroup);

    isElectrodeGroup = strcmp({ecephysGroup.subgroups.name}, 'electrodes');
    electrodeGroup = ecephysGroup.subgroups(isElectrodeGroup);
end
