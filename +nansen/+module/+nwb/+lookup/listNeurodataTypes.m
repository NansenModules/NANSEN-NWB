function [typeNames, descriptions] = listNeurodataTypes(options)
%listNeurodataTypes - List the neurodata types a variable can convert to
%   typeNames = listNeurodataTypes() returns every neurodata type defined
%   by the loaded NWB core schema, sorted by name.
%
%   typeNames = listNeurodataTypes(Module=NAME) returns only the types
%   the named module defines, for example "ophys" or "behavior".
%
%   typeNames = listNeurodataTypes(Producible=true) returns only the
%   types a registered converter names as its output. That is the list
%   worth offering first, since choosing any other type leaves the
%   generic path to build it from metadata alone. Converters that decide
%   their type at conversion time do not count towards it, or every type
%   would qualify.
%
%   [typeNames,DESCRIPTIONS] = listNeurodataTypes(...) also returns the
%   schema's description of each type, in the same order.
%
%   The list comes from the schema loaded with matnwb, so a type added
%   upstream appears without this module being changed. It replaces the
%   hand-maintained enumeration that had to be edited to keep up.
%
%   Example: Types the ophys module defines
%       types = nansen.module.nwb.lookup.listNeurodataTypes(Module="ophys");
%
%   See also nansen.module.nwb.internal.schemautil.getTypesForModule,
%   nansen.module.nwb.internal.schemautil.getNWBModules,
%   nansen.module.nwb.conversion.ConverterRegistry

    arguments
        options.Module (1,1) string = ""
        options.Producible (1,1) logical = false
    end

    import nansen.module.nwb.internal.schemautil.getNWBModules
    import nansen.module.nwb.internal.schemautil.getTypesForModule

    if strlength(options.Module) > 0
        moduleNames = options.Module;
    else
        moduleNames = getNWBModules();
    end

    typeNames = string.empty(0, 1);
    descriptions = string.empty(0, 1);

    for i = 1:numel(moduleNames)
        [moduleTypes, moduleDescriptions] = getTypesForModule(moduleNames(i));
        typeNames = [typeNames; string(moduleTypes(:))]; %#ok<AGROW>
        descriptions = [descriptions; string(moduleDescriptions(:))]; %#ok<AGROW>
    end

    % A type defined in one module and referenced from another would
    % otherwise be listed twice.
    [typeNames, keptIndices] = unique(typeNames, "stable");
    descriptions = descriptions(keptIndices);

    if options.Producible
        [typeNames, descriptions] = keepProducible(typeNames, descriptions);
    end

    [typeNames, order] = sort(typeNames);
    descriptions = descriptions(order);
end

function [typeNames, descriptions] = keepProducible(typeNames, descriptions)
%keepProducible - Keep only types a converter names as its output
%
%   Converters that decide their type at conversion time, the generic
%   path among them, are left out of the calculation. Counting them would
%   mark every type producible and leave the caller no better off than
%   the full list.

    registry = nansen.module.nwb.conversion.ConverterRegistry.instance();
    descriptors = registry.list();

    if isempty(descriptors)
        typeNames = string.empty(0, 1);
        descriptions = string.empty(0, 1);
        return
    end

    producedTypes = [descriptors.ProducesNWBType];
    producedTypes = producedTypes(producedTypes ~= "*");

    isProducible = ismember(typeNames, producedTypes);
    typeNames = typeNames(isProducible);
    descriptions = descriptions(isProducible);
end
