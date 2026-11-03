function interface = createInterface(interfaceClassName, sourceArg)
%createInterface - Instantiate a NeuroConv data interface
%   INTERFACE = createInterface(interfaceClassName,sourceArg) imports the
%   named class from neuroconv.datainterfaces and constructs it with the
%   fields of sourceArg as keyword arguments.
%
%   See also nansen.module.nwb.neuroconv.runConversion,
%   nansen.module.nwb.neuroconv.readSessionStartTime

    arguments
        interfaceClassName (1,1) string
        sourceArg (1,1) struct
    end

    import nansen.module.nwb.neuroconv.internal.structToPyargs

    dataInterfaces = py.importlib.import_module("neuroconv.datainterfaces");
    interfaceClass = py.getattr(dataInterfaces, char(interfaceClassName));

    sourceNvPairs = structToPyargs(sourceArg);
    interface = interfaceClass(pyargs(sourceNvPairs{:}));
end
