function value = getConverterArg(args, name, defaultValue)
%getConverterArg - Read one converter argument, or its default
%   VALUE = getConverterArg(ARGS,NAME,defaultValue) returns the field NAME
%   of the converter argument struct ARGS. When the field is absent or
%   empty, defaultValue is returned instead.
%
%   Converter arguments reach a converter merged from descriptor defaults
%   and per-item overrides, so any individual field may be missing.
%
%   Example: Read an optional plane name
%       planeName = nansen.module.nwb.conversion.getConverterArg( ...
%           context.ConverterArgs, "ImagingPlaneName", "ImagingPlane");
%
%   See also nansen.module.nwb.conversion.NWBConverterDescriptor,
%   nansen.module.nwb.conversion.NWBFileConverter

    arguments
        args (1,1) struct
        name (1,1) string
        defaultValue = []
    end

    if isfield(args, name) && ~isempty(args.(name))
        value = args.(name);
    else
        value = defaultValue;
    end
end
