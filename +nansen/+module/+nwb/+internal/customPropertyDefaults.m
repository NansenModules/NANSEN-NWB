function defaults = customPropertyDefaults()
%customPropertyDefaults - Default values that override the schema default
%
%   defaults = customPropertyDefaults() returns a struct whose fields are
%   neurodata type names and whose values are structs of property defaults.
%   getTypeMetadataStruct uses these in place of the value the generated
%   class would supply, which is how a property gets offered as a fixed set
%   of choices rather than free text.
%
%   The list is maintained by hand. The NWB schemas do not express the
%   permitted values in a form the generated classes carry.
%
%   See also: nansen.module.nwb.internal.dataPropertyNames

    defaults = struct();
    defaults.TimeSeries = struct("data_continuity", ...
        categorical("continuous", ["continuous", "instantaneous", "step"]));
    defaults.ImageSeries = struct("format", ...
        categorical("raw", ["raw", "external_file"]));
    defaults.SpatialSeries = struct("data_unit", ...
        categorical("meters", ["meters", "degrees"]));
end
