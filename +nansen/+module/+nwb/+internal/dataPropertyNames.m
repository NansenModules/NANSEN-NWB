function propertyNames = dataPropertyNames()
%dataPropertyNames - Properties that hold data rather than metadata
%
%   propertyNames = dataPropertyNames() returns a struct whose fields are
%   neurodata type names and whose values are the properties of that type
%   that carry data. getTypeMetadataStruct excludes them, so that what is
%   left is the metadata a user fills in.
%
%   The list is maintained by hand. The NWB schemas do not mark which
%   properties are data.
%
%   See also: nansen.module.nwb.internal.customPropertyDefaults

    propertyNames = struct();
    propertyNames.TimeSeries = ["data", "timestamps", "control"];
    propertyNames.Image = "order_of_images";
    propertyNames.DynamicTable = ["colnames", "vectordata"];
    propertyNames.RoiResponseSeries = "rois";
end
