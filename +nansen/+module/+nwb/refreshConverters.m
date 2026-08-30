function refreshConverters()
%refreshConverters - Rebuild the shared converter registry
%   refreshConverters() discards the registry shared by the configurator
%   and the conversion runner, and builds it again. Use it after editing
%   a converter or its descriptor, so the change is picked up without
%   restarting MATLAB.
%
%   Folders registered with registerConverterFolder are registered again
%   on the new registry, so a refresh does not remove them.
%
%   See also nansen.module.nwb.registerConverterFolder,
%   nansen.module.nwb.conversion.ConverterRegistry

    nansen.module.nwb.conversion.ConverterRegistry.instance(Refresh=true);
end
