function S = createNwbTestConfiguration()

    S = struct;
    S.Name = "Processed"; % Use for differentiating different NWB files, i.e raw data for internal use, processed data for sharing
    S.Description = "Processed Data for Sharing";

    % Todo: some preferences / one time configurations
    
    S.DataItems = struct();
    S.DataItems(1).VariableName = 'Eeg';
    S.DataItems(1).NWBVariableName = 'Eeg';
    S.DataItems(1).PrimaryGroupName = 'acquisition';
    S.DataItems(1).NeuroDataType = 'ElectricalSeries';
    S.DataItems(1).Converter = '';
    S.DataItems(1).DefaultMetadata = '';

    S.DataItems(2).VariableName = 'LineScan';
    S.DataItems(2).NWBVariableName = 'LineScan';
    S.DataItems(2).PrimaryGroupName = 'acquisition';
    S.DataItems(2).NeuroDataType = 'ImageSeries';
    S.DataItems(2).Converter = '';
    S.DataItems(2).DefaultMetadata = '';

    S.DataItems(3).VariableName = 'WheelData';
    S.DataItems(3).NWBVariableName = 'WheelData';
    S.DataItems(3).PrimaryGroupName = 'acquisition';
    S.DataItems(3).NeuroDataType = 'SpatialSeries';
    S.DataItems(3).Converter = '';
    S.DataItems(3).DefaultMetadata = '';
end