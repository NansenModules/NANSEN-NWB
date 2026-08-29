function name = getOphysTypeName(neurodataType, options)
%getOphysTypeName - Build a name for an optophysiology type instance
%   NAME = getOphysTypeName(neurodataType) returns the type name
%   unchanged, which is what a single-plane, single-channel recording
%   needs.
%
%   NAME = getOphysTypeName(...,NumPlanes=VALUE,PlaneNumber=VALUE) appends
%   a plane suffix when the recording has more than one plane, so that
%   instances of the same type stay distinguishable within a file.
%
%   NAME = getOphysTypeName(...,NumChannels=VALUE,ChannelNumber=VALUE)
%   appends a channel suffix on the same terms.
%
%   Example: A plane in a two-plane recording
%       getOphysTypeName("ImagingPlane",NumPlanes=2,PlaneNumber=1)
%
%   See also nansen.module.nwb.conversion.ophys.initGeneralOptophysiology

    arguments
        neurodataType (1,1) string
        options.PlaneNumber = 1
        options.ChannelNumber = 1
        options.NumPlanes = 1
        options.NumChannels = 1
    end
    name = neurodataType;

    if options.NumPlanes > 1
        name = sprintf("%s_Plane%02d", name, options.PlaneNumber);
    end
    if options.NumChannels > 1
        name = sprintf("%s_Channel%02d", name, options.ChannelNumber);
    end
end
