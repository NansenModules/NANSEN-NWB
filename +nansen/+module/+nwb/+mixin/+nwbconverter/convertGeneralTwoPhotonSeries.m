function convertGeneralTwoPhotonSeries(metadata, data, nwbFilePath)
    
    % Todo: How to inject metadata?

    assert( isa(data, 'nansen.stack.ImageStack'), ...
        'Data must be of type ''nansen.stack.ImageStack''')
    
    S = nansen.stack.processor.NWBExporter.getDefaultOptions();
    
    % Compute this based on num pixels per frame..
    % Should perhaps be numMBPerPart

    S.Run.numFramesPerPart = 10000;


    S.NWBExporter.NWBFilePath = nwbFilePath;

    nansen.stack.processor.NWBExporter(data, S)

end