function result = convertImageStackToTwoPhotonSeries(context)
%convertImageStackToTwoPhotonSeries Let the ImageStack NWB exporter write data.

    arguments
        context (1,1) struct
    end

    nansen.module.nwb.mixin.nwbconverter.convertGeneralTwoPhotonSeries( ...
        context.Metadata, context.Data, context.FilePath);

    result = struct("DidWriteFile", true);
end
