function names = getWrapperClassNames()
%getWrapperClassNames - Get name of data wrapper classes.
%   Names of the classes that only wrap timeseries objects or types
    
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
