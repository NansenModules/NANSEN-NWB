function dynamicTableName = getDynamicTableForRegionView(type, datasetName)
%getDynamicTableForRegionView - Get the table a region view points into
%   dynamicTableName = getDynamicTableForRegionView(TYPE,datasetName)
%   returns the name of the dynamic table that a DynamicTableRegion on the
%   given neurodata type refers to. A region view names the rows it selects
%   but not the table those rows belong to, so the pairing is kept here.
%
%   TYPE is a neurodata type name, with or without its package prefix.
%   datasetName is the property on that type holding the region view.
%
%   The pairings are maintained by hand. A combination that is not listed
%   raises rather than returning empty.
%
%   See also nansen.module.nwb.internal.getDynamicTableByName

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
