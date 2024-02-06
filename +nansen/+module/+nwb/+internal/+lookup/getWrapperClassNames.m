function names = getWrapperClassNames()
% getWrapperClassNames - Get name of data wrapper classes.
%   Names for a set of classes that just wraps various timeseries objects/types
    
    names = [...
        "BehavioralEpochs"
        "BehavioralEvents"
        "BehavioralTimeSeries"
        "CompassDirection"
        "DfOverF"
        "EventWaveform"
        "EyeTracking"
        "FilteredEphys"
        "Fluorescence"
        "LFP"
        "Position"
        "PupilTracking" ];
end