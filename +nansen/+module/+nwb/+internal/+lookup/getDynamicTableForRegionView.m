function dynamicTableName = getDynamicTableForRegionView(type, datasetName)
%GETDYNAMICTABLEFORREGIONVIEW Summary of this function goes here
%   Detailed explanation goes here

    persistent map
    if isempty(map)
        map = dictionary();
        map("Units.electrodes") = "ElectrodesTable";
        map("ElectricalSeries.electrodes") = "ElectrodesTable"; %DynamicTable
        map("RoiResponseSeries.rois") = "PlaneSegmentation";
        map("SpikeEventSeries.electrodes") = "ElectrodesTable";
        map("FeatureExtraction.electrodes") = "ElectrodesTable";
        map("DecompositionSeries.source_channels") = "ChannelsTable"; %%??
        map("SimultaneousRecordingsTable.recordings") = "IntracellularRecordingsTable";
        map("SequentialRecordingsTable.simultaneous_recordings") = "SimultaneousRecordingsTable";
        map("RepetitionsTable.sequential_recordings") = "SequentialRecordingsTable";
        map("ExperimentalConditionsTable.repetitions") = "RepetitionsTable";
    end
    
    type = utility.string.getSimpleClassName(type);
    key = strjoin({char(type), char(datasetName)}, '.');
    dynamicTableName = map(key);
end

