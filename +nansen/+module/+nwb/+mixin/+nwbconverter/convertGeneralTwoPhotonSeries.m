function convertGeneralTwoPhotonSeries(~, data, nwbFilePath)
%convertGeneralTwoPhotonSeries - Write an image stack as a TwoPhotonSeries
%   convertGeneralTwoPhotonSeries(METADATA,DATA,nwbFilePath) exports an
%   ImageStack to the NWB file at the given path as a TwoPhotonSeries.
%   It writes to the file and returns nothing.
%
%   METADATA is accepted for the converter calling convention and is not
%   used. DATA must be a nansen.stack.ImageStack.
%
%   See also nansen.module.nwb.conversion.NWBVideoExporter
    
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
