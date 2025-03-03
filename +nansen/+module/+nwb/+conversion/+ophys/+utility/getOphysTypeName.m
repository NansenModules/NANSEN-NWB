function name = getOphysTypeName(neurodataType, options)

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
