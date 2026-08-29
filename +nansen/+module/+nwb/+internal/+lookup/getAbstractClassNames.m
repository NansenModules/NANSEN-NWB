function names = getAbstractClassNames()
% getAbstractClassNames - Get names of abstract neurodata type classes.
%
%   Names of the NWB types that are not instantiated directly but appear as
%   the declared type of a property. getMetadataClassNames, in the same
%   namespace, lists the concrete metadata classes.
    
    names = [...
        "NWBContainer"
        "NWBDataInterface"
        "ProcessingModule" ];
end
