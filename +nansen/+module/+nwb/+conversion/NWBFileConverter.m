classdef NWBFileConverter < handle
%NWBFileConverter - Build an NWB file for a session, piece by piece
%   OBJ = NWBFileConverter(sessionObject,targetFolder) creates a
%   converter holding a new NWB file for the session, to be written
%   into the given folder. Add content with the methods below, then
%   call export.
%
%   OBJ = NWBFileConverter(...,FilenameSuffix=VALUE) also appends a
%   suffix to the file name, to tell several files for one session
%   apart.
%
%   NWBFileConverter functions:
%       addTrials             - Add a trial table
%       addRois               - Add a segmentation of a ROI group
%       addRoiSignals         - Add the signals extracted from ROIs
%       addFovProjectionImage - Add a projection image of the field
%       addProcessingModule   - Add a processing module
%       addToAcquisition      - Add data to the acquisition group
%       export                - Write the file to disk
%
%   NWBFileConverter properties:
%       NwbFile  - The NWB file being built
%       FilePath - Where export will write it
%
%   See also nansen.module.nwb.conversion.initNWBFile

    properties
        NwbFile (1,1) NwbFile % The NWB file being built
    end
    properties (SetAccess = private)
        FilePath (1,1) string % Where export will write it
    end
    
    methods % Constructor
        function obj = NWBFileConverter(sessionObject, targetFolder, options)

            arguments
                sessionObject
                targetFolder (1,1) string {mustBeFolder}
                options.FilenameSuffix (1,:) string = string.empty
            end
            
            obj.NwbFile = nansen.module.nwb.conversion.initNWBFile(sessionObject);
    
            subjectInfo = sessionObject.getSubject();

            obj.FilePath = createNWBFilePath(targetFolder, ...
                "SubjectID", subjectInfo.SubjectID, ...
                "SessionID", sessionObject.sessionID, ...
                "FilenameSuffix", options.FilenameSuffix);
        end
    end

    methods % Exporter
        function export(obj)
            nwbExport(obj.NwbFile, obj.FilePath)
            fprintf ('Exported file to "%s"\n', obj.FilePath)
        end
    end

    methods
        function addTrials(obj, data)
            % Todo: Generalize this with converter
            if height(data)==0
                return
            end

            trials_table = types.core.TimeIntervals(...
                'colnames', {'start_time', 'stop_time', 'trial_type', 'trial_description'}, ...
                'description', 'Start and stop time for each trial type (Plus, Neutral, Negative)', ...
                'start_time', types.hdmf_common.VectorData(...
                    'data', seconds( data.TrialStartTime ), ...
                    'description', 'Start time of trial, in seconds.'), ...
                'stop_time', types.hdmf_common.VectorData(...
                    'data', seconds( data.TrialEndTime ), ...
                    'description', 'Stop time of trial, in seconds.'), ...
                'trial_type', types.hdmf_common.VectorData(...
                    'data', cellstr(data.TrialType), ...
                    'description', 'Type of trial (Plus, Neutral, Negative).'), ...
                'trial_description', types.hdmf_common.VectorData(...
                    'data', cellstr(data.TrialDescription), ...
                    'description', 'Description of each trial (cue used)'), ...
                'id', types.hdmf_common.ElementIdentifiers(...
                    'data', (1:height(data))' ));
            obj.NwbFile.intervals.set('Trials', trials_table);
        end

        function addRois(obj, roiGroup, isCell, converter)
            arguments
                obj
                roiGroup
                isCell
                converter function_handle = ...
                    @nansen.module.nwb.conversion.ophys.convertRoiGroup
            end
            
            import nansen.module.nwb.conversion.ophys.utility.getOphysTypeName
            
            % Todo: Channels and planes....

            params = struct();
            params.ChannelNumber = 1;
            params.PlaneNumber = 1;
            params.NumPlanes = 1;
            params.NumChannels = 1;
            nvPairs = namedargs2cell(params);

            planeName = getOphysTypeName("ImagingPlane", nvPairs{:});
            planeNames = obj.NwbFile.general_optophysiology.keys();
            isMatch = strcmp(planeNames, planeName);
            thisPlane = obj.NwbFile.general_optophysiology.get(planeNames{isMatch});
            
            planeSegmentation = converter(roiGroup, isCell);
            planeSegmentation.imaging_plane = thisPlane;
        
            imageSegmentation = types.core.ImageSegmentation();
            planeSegmentationName = getOphysTypeName("PlaneSegmentation", nvPairs{:});
            imageSegmentation.planesegmentation.set(planeSegmentationName, planeSegmentation);
            
            if ~isKey(obj.NwbFile.processing, 'ophys')
                obj.addProcessingModule('ophys');
            end
            ophysModule = obj.NwbFile.processing.get('ophys');
            imageSegmentationName = getOphysTypeName("ImageSegmentation", nvPairs{:});
            ophysModule.nwbdatainterface.set(imageSegmentationName, imageSegmentation);
        end

        function addRoiSignals(obj, signalArray, name, type, isCell, converter)
            arguments
                obj
                signalArray
                name
                type (1,1) string {mustBeMember(type, ["Fluorescence", "DeltaFOverF"])} = "Fluorescence"
                isCell (:,1) logical = logical.empty
                converter function_handle = ...
                    @nansen.module.nwb.conversion.ophys.convertRoiResponses
            end
            
            params = struct();
            params.ChannelNumber = 1;
            params.PlaneNumber = 1;
            params.NumPlanes = 1;
            params.NumChannels = 1;
            nvPairs = namedargs2cell(params);

            roiResponseSeries = converter(signalArray);
            nRois = size(roiResponseSeries.data, 1);

            % Find rois
            planeSegmentationNames = obj.NwbFile.processing.get('ophys').nwbdatainterface.get('ImageSegmentation').planesegmentation.keys();
            % Find matches based on plane and channel
            isMatch = 1;
            planeSegmentation = obj.NwbFile.processing.get('ophys').nwbdatainterface.get('ImageSegmentation').planesegmentation.get(planeSegmentationNames{isMatch});
            
            % Todo: What if multiple plane segmentations exist, for multi
            % channel /plane
            roiTableRegion = types.hdmf_common.DynamicTableRegion( ...
                'table', types.untyped.ObjectView(planeSegmentation), ...
                'description', 'all_rois', ...
                'data', (0:nRois-1)');

            roiResponseSeries.rois = roiTableRegion;

            switch type
                case 'Fluorescence'
                    wrapper = @types.core.Fluorescence;
                case 'DeltaFOverF'
                    wrapper = @types.core.DfOverF;
            end

            F = wrapper('RoiResponseSeries', roiResponseSeries);

            if ~isKey(obj.NwbFile.processing, 'ophys')
                obj.addProcessingModule('ophys');
            end
            ophysModule = obj.NwbFile.processing.get('ophys');
            ophysModule.nwbdatainterface.set(name, F);
        end
        
        function addFovProjectionImage(obj, image, name)
            neurodata = types.core.GrayscaleImage(...
                'data', image.getFrameSet(1) );

            % Todo: get or create image collection...
            imageCollectionName = "FovProjectionImages";

            % searchFor and isa take the type as text, so the name is built
            % through the lookup rather than spelled out. Constructor calls
            % below stay as direct class references, which stay checkable.
            imagesType = nansen.module.nwb.internal.lookup.getMatNWBTypeName('core', 'Images');

            result = obj.NwbFile.searchFor(imagesType, 'Name', imageCollectionName);
            if result.Count == 1
                imageCollection = result.values;
                imageCollection = imageCollection{1};
                assert(isa(imageCollection, imagesType))
            else
                assert(result.Count == 0, 'Expected there to be 0 result')
                imageCollection = types.core.Images( ...
                    'description', 'A collection of FOV projection images.'...
                );
                obj.addToProcessing("ophys", imageCollection, imageCollectionName)
            end

            name = sprintf('%sImage', name);

            % NWB 2.9 renamed the Images collection's member property from
            % image to baseimage. The module does not pin a matnwb version,
            % so pick whichever the installed schema defines.
            if isprop(imageCollection, 'baseimage')
                imageCollection.baseimage.set(name, neurodata);
            else
                imageCollection.image.set(name, neurodata);
            end
        end

        function addProcessingModule(obj, name, description)
            arguments
                obj
                name (1,1) string
                description (1,1) string = missing
            end
            nansen.module.nwb.conversion.addProcessingModule(obj.NwbFile, name, description)
        end

        function addToAcquisition(obj, data, converter)
            arguments
                obj
                data
                converter function_handle = ...
                    @nansen.module.nwb.conversion.general.convertTimetable
                    % Todo: mustBeSetConverter?
            end

            converted = converter(data);
            names = converted.keys();

            for i = 1:numel(names)
                obj.NwbFile.acquisition.set(names{i}, converted.get(names{i}));
            end
        end
    end

    methods (Access = private)

        function addToProcessing(obj, moduleName, data, name)
            if ~isKey(obj.NwbFile.processing, moduleName)
                obj.addProcessingModule(moduleName);
            end
            processingModule = obj.NwbFile.processing.get(moduleName);
            if isa(data, nansen.module.nwb.internal.lookup.getMatNWBTypeName('hdmf_common', 'DynamicTable'))
                processingModule.dynamictable.set(name, data);
            else
                processingModule.nwbdatainterface.set(name, data);
            end
        end
    end
end

function nwbFilePath = createNWBFilePath(targetFolder, options)
% createNWBFilePath - Creates a file path for the NWB file based on
% the specified folder and options.
%
% Syntax:
%   nwbFilePath = createNWBFilePath(targetFolder, options)
%
% Input Arguments:
%   targetFolder - The folder path where the NWB file will be saved.
%   options - A structure containing options for file naming.
%     options.SessionID - The session identifier.
%     options.SubjectID - The subject identifier.
%     options.FilenameSuffix - Optional string suffix for the file name.
%
% Output Arguments:
%   nwbFilePath - The constructed path for the NWB file.

    arguments
        targetFolder
        options.SessionID
        options.SubjectID
        options.FilenameSuffix (1,:) string = string.empty
    end

    subjectId = options.SubjectID;
    if startsWith(options.SessionID, subjectId)
        sessionId = replace(options.SessionID, options.SubjectID, '');
        if startsWith(sessionId, '_')
            sessionId = sessionId(2:end);
        end
    else
        sessionId = options.SessionID;
    end
    
    subjectPart = sprintf("sub-%s", subjectId);
    sessionPart = sprintf("ses-%s", sessionId);

    fileName = join([subjectPart, sessionPart, options.FilenameSuffix], "_");
    nwbFilePath = fullfile(targetFolder, fileName+".nwb");
end
