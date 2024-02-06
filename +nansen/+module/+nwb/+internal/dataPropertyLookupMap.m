function isData = dataPropertyLookupMap()
    % This map is defined manually. Not sure if there is a way to detect
    % this from the nwb schemas. 

    isData = struct();
    isData.TimeSeries = ["data", "timestamps", "control"];
    isData.Image = "order_of_images";
    isData.DynamicTable = ["colnames", "vectordata"];


    isData.RoiResponseSeries = "rois";

    %isData = dictionary();
    %isData("TimeSeries") = {["data", "timestamps"]};
    
    %jsonencode(isData, 'PrettyPrint', true)
end

