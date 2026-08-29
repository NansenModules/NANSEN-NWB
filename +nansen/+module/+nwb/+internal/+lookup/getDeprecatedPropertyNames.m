function names = getDeprecatedPropertyNames()
%getDeprecatedPropertyNames - Properties to leave out of a metadata form
%   NAMES = getDeprecatedPropertyNames() returns the names of neurodata
%   type properties that the schema has deprecated.
%
%   The list is hardcoded. Attributes of a deprecated dataset become
%   properties of the generated class without carrying the deprecation
%   with them, so it cannot be read back from the schema.
%
%   See also nansen.module.nwb.internal.getTypeMetadataStruct

% Need these hardcoded because of the way attributes of potentially
% deprecated datasets are added as properties.

    names = ["manifold", "manifold_conversion", "manifold_unit"];
end
