function converterArgs = mergeConverterArgs(defaultArgs, itemArgs)
%mergeConverterArgs - Lay a data item's converter arguments over the defaults
%   converterArgs = mergeConverterArgs(defaultArgs,itemArgs) returns
%   defaultArgs, a converter descriptor's DefaultConverterArgs, with every
%   field of itemArgs, a data item's ConverterArgs, put in its place.
%
%   An argument the item sets replaces the default of the same name
%   whole, even when both are structs: an item that gives
%   ElectrodeMetadata gives all of it. This is the rule the conversion
%   runner applies, and anything that has to predict the arguments a
%   converter receives uses this function so the two agree.
%
%   Example: Override one default
%       args = nansen.module.nwb.internal.mergeConverterArgs( ...
%           struct("Gain", 1, "Units", "mV"), struct("Gain", 5));
%       % args.Gain is 5 and args.Units is "mV"
%
%   See also nansen.module.nwb.conversion.NWBFileConverter,
%   nansen.module.nwb.internal.deepMerge

    arguments
        defaultArgs (1,1) struct
        itemArgs (1,1) struct
    end

    converterArgs = defaultArgs;
    for fieldName = string(fieldnames(itemArgs))'
        converterArgs.(fieldName) = itemArgs.(fieldName);
    end
end
