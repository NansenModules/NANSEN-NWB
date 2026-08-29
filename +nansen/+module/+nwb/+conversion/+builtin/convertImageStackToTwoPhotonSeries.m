function result = convertImageStackToTwoPhotonSeries(context)
%convertImageStackToTwoPhotonSeries - Stream an ImageStack to the NWB file
%   RESULT = convertImageStackToTwoPhotonSeries(CONTEXT) writes the
%   ImageStack in CONTEXT.Data to the NWB file at CONTEXT.FilePath as a
%   two-photon image series, and reports that it wrote the file itself.
%
%   Imaging stacks are far larger than memory, so this converter streams
%   the data to disk chunk by chunk rather than building a neurodata
%   object the runner would place. That is why it runs as an external
%   converter and owns its own placement.
%
%   See also nansen.module.nwb.mixin.nwbconverter.convertGeneralTwoPhotonSeries,
%   nansen.module.nwb.conversion.NWBFileConverter

    arguments
        context (1,1) struct
    end

    nansen.module.nwb.mixin.nwbconverter.convertGeneralTwoPhotonSeries( ...
        context.Metadata, context.Data, context.FilePath);

    result = struct("DidWriteFile", true);
end
