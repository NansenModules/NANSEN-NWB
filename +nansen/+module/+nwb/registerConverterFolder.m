function registerConverterFolder(folderPath)
%registerConverterFolder - Add a folder of custom converters
%   registerConverterFolder(folderPath) adds folderPath to the MATLAB
%   path and registers every converter in it, so the configurator offers
%   them alongside the ones this module ships with.
%
%   A converter in such a folder is an ordinary function that also
%   returns its own descriptor when called with the single argument
%   "descriptor":
%
%       function result = convertMyData(context)
%           if nargin == 1 && isequal(context, "descriptor")
%               result = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
%                   Name="MyData", AcceptedClasses="mylab.MyData", ...
%                   ProducesNWBType="TimeSeries", Function=@convertMyData);
%               return
%           end
%           ...
%       end
%
%   Files in the folder that do not answer that way are left alone, so
%   helper functions can live beside the converters.
%
%   Registration lasts for the MATLAB session. Call it from a project
%   startup file to have a lab's converters always available.
%
%   Example: Register a lab's own converters
%       nansen.module.nwb.registerConverterFolder("/lab/code/nwbconverters")
%
%   See also nansen.module.nwb.conversion.ConverterRegistry,
%   nansen.module.nwb.conversion.NWBConverterDescriptor,
%   nansen.module.nwb.refreshConverters

    arguments
        folderPath (1,1) string {mustBeFolder}
    end

    registry = nansen.module.nwb.conversion.ConverterRegistry.instance();
    registry.registerFolder(folderPath)
end
