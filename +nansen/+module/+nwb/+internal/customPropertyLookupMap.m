function map = customPropertyLookupMap()
    % This map is defined manually. Not sure if there is a way to detect
    % this from the nwb schemas. 

    map = struct();
    map.TimeSeries = struct("data_continuity", categorical("continuous", ["continuous", "instantaneous", "step"]));
    map.ImageSeries = struct("format", categorical("raw", ["raw", "external_file"]));

    
    %isData = dictionary();
    %isData("TimeSeries") = {["data", "timestamps"]};
    
    %jsonencode(isData, 'PrettyPrint', true)
end

