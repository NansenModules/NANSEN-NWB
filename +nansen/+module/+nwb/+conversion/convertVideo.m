function convertVideo(nwbReference, videoFilePath, videoName, nwbFileOptions, deviceOptions)

    arguments
        nwbReference (1,1) {mustBeNwbFileReference} 
        videoFilePath (1,:) string {mustBeFile}
        videoName (1,1) string
        
        nwbFileOptions.module (1,1) string = 'acquisition'
        nwbFileOptions.processingModule (1,1) string = 'acquisition'
        
        deviceDescription 
        deviceManufacturer
    end

    keyboard



end