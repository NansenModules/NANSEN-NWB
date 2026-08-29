classdef NeuroDataType < handle
    %NeuroDataType - Enumeration of the NWB neurodata types
    %   NeuroDataType lists the neurodata types a data variable can be
    %   converted to. The configuration table offers these as the choices
    %   in its neurodata type column.
    %
    %   The list is maintained by hand and mirrors the NWB core schema. It
    %   is not read from the loaded schema, so a type added upstream does
    %   not appear until it is added here.
    %
    %   See also PrimaryGroupName, ProcessingModule

    enumeration
        AbstractFeatureSeries
        AnnotationSeries
        BehavioralEpochs
        BehavioralEvents
        BehavioralTimeSeries
        ClusterWaveforms
        Clustering
        CompassDirection
        CorrectedImageStack
        CurrentClampSeries
        CurrentClampStimulusSeries
        DecompositionSeries
        Device
        DfOverF
        ElectricalSeries
        ElectrodeGroup
        EventDetection
        EventWaveform
        ExperimentalConditionsTable
        EyeTracking
        FeatureExtraction
        FilteredEphys
        Fluorescence
        GrayscaleImage
        IZeroClampSeries
        Image
        ImageMaskSeries
        ImageReferences
        ImageSegmentation
        ImageSeries
        Images
        ImagingPlane
        ImagingRetinotopy
        IndexSeries
        IntervalSeries
        IntracellularElectrode
        IntracellularElectrodesTable
        IntracellularRecordingsTable
        IntracellularResponsesTable
        IntracellularStimuliTable
        LFP
        LabMetaData
        MotionCorrection
        NWBContainer
        NWBData
        NWBDataInterface
        NWBFile
        OnePhotonSeries
        OpticalChannel
        OpticalSeries
        OptogeneticSeries
        OptogeneticStimulusSite
        PatchClampSeries
        PlaneSegmentation
        Position
        ProcessingModule
        PupilTracking
        RGBAImage
        RGBImage
        RepetitionsTable
        RoiResponseSeries
        ScratchData
        SequentialRecordingsTable
        SimultaneousRecordingsTable
        SpatialSeries
        SpikeEventSeries
        Subject
        SweepTable
        TimeIntervals
        TimeSeries
        TimeSeriesReferenceVectorData
        TwoPhotonSeries
        Units
        VoltageClampSeries
        VoltageClampStimulusSeries
    end
end
