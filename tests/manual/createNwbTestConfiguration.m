function S = createNwbTestConfiguration()

    S = nansen.module.nwb.config.NwbFileConfiguration().toStruct();
    S.Name = "Processed"; % Use for differentiating different NWB files, i.e raw data for internal use, processed data for sharing
    S.Description = "Processed Data for Sharing";

    % Todo: some preferences / one time configurations
    
    defaultItem = nansen.module.nwb.file.getDefaultFileConfigurationItem();
    S.DataItems = repmat(defaultItem, 1, 3);

    S.DataItems(1).VariableName = 'Eeg';
    S.DataItems(1).NWBVariableName = 'Eeg';
    S.DataItems(1).PrimaryGroup = 'Acquisition';
    S.DataItems(1).TargetNwbType = 'ElectricalSeries';

    S.DataItems(2).VariableName = 'LineScan';
    S.DataItems(2).NWBVariableName = 'LineScan';
    S.DataItems(2).PrimaryGroup = 'Acquisition';
    S.DataItems(2).TargetNwbType = 'ImageSeries';

    S.DataItems(3).VariableName = 'WheelData';
    S.DataItems(3).NWBVariableName = 'WheelData';
    S.DataItems(3).PrimaryGroup = 'Acquisition';
    S.DataItems(3).TargetNwbType = 'SpatialSeries';
end
