classdef NWBVideoExporter < nansen.stack.ImageStackProcessor

    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'NWB ImageStack Exporter'
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class'))
    end

    properties (Constant)
        DATA_SUBFOLDER = ""	% defined in nansen.processing.DataMethod
        VARIABLE_PREFIX	= "" % defined in nansen.processing.DataMethod
    end

    properties (Constant, Access = private)
        TYPE_PACKAGE_PREFIX = "types.core"
    end

    properties
        SemanticDataType (1,1) string ...
            {mustBeMember(SemanticDataType, {'Acquired', 'MotionCorrected'})} = "Acquired"
    end

    properties (Constant)
        Dependency = 'NWB'
    end

    properties (Access = private)
        PathName % Path name for NWB file
        NWBObject % Object representing NWB file
        Device
        ImagingPlanes cell % Cell array (numPlanes x numChannels) of objects.
        DataPipeObject cell % Cell array (numPlanes x numChannels) of objects.
    
        %Device
        %OpticalChannel
        %ImagingPlane
    end

    methods (Static)
    
        function S = getDefaultOptions()
            % Get default options for the deep interpolation denoiser.
            S.NWBExporter.NWBFilePath = '';
            S.NWBExporter.CompressionLevel = 3;
            S.NWBExporter.ChunkSize = nan;
            S.NWBExporter.LongDimension = 'T';
            S.NWBExporter.LongDimension_ = {'T', 'Z'};
            S.NWBExporter.GroupName = 'acquisition';
            S.NWBExporter.GroupName_ = {'acquisition', 'processing'};
            S.NWBExporter.NeuroDataType = 'TwoPhotonSeries';
            S.NWBExporter.NeuroDataType_ = {'TwoPhotonSeries', 'OnePhotonSeries', 'ImageSeries'}; % Todo...
        
            S.NWBMetadata.DeviceDescription = '';
            S.NWBMetadata.DeviceManufacturer = '';
            S.NWBMetadata.ExcitationWavelength = [];
            S.NWBMetadata.IndicatorNames = ''; % List of strings.
            S.NWBMetadata.RecordingLocation = '';

            className = mfilename('class');
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
        end
    end

    methods % Constructor
        
        function obj = NWBVideoExporter(sourceStack, varargin)

            % Todo:
            % assert(isInstalled('matnwb'))

            obj@nansen.stack.ImageStackProcessor(sourceStack, varargin{:})

            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
    end

    methods (Access = protected) % Override ImageStackProcessor methods

        function onInitialization(obj)
        %onInitialization Custom code to run on initialization.

            if isempty(obj.Options.NWBExporter.NWBFilePath)
                sourceFilePath = obj.SourceStack.FileName;
                [folder, fileName, ~] = fileparts(sourceFilePath);
                obj.PathName = fullfile(folder, [fileName, '.nwb']);
            else
                obj.PathName = obj.Options.NWBExporter.NWBFilePath;
            end

            if strcmp(obj.Options.NWBExporter.GroupName, 'processing')
                obj.SemanticDataType = "MotionCorrected";
            end

            wasInitialized = obj.initializeNWBFile();

            obj.initializeGroups() % Device / opticalchannel / imagingplanes

            % Todo: Check if datapipe/dataset for writing already exists
            obj.initializeDataPipes()

            %if wasInitialized
            nwbExport(obj.NWBObject, obj.PathName);
            %end
        end
    end

    methods (Access = protected) % Method for processing each part

        function [Y, results] = processPart(obj, Y, ~)

            % Todo: Use indexing into data pipe object?? This would be
            % necessary if the operation is canceled and restarted.

            obj.DataPipeObject{obj.CurrentPlane, obj.CurrentChannel}.append(Y); % append the loaded data
            results = struct.empty;
        end
    end

    methods (Access = private)

        function wasInitialized = initializeNWBFile(obj)
            if isfile(obj.PathName)
                delete(obj.PathName)
                obj.initializeNWBFile()
            end

            if isfile(obj.PathName)
                obj.NWBObject = nwbRead(obj.PathName);
                wasInitialized = false;
            else
                obj.NWBObject = NwbFile(...
                    identifier='test',...
                    session_description='test', ...
                    session_start_time=datetime('now'));
                wasInitialized = true;
            end
        end

        function initializeGroups(obj)
            % Create a device
            obj.Device = obj.createDevice();
            obj.NWBObject.general_devices.set('WhiskerCamera', obj.Device);

            obj.StackIterator.reset()
        end

        function initializeDataPipes(obj)

            %compressionLevel = obj.Options.NWBExporter.CompressionLevel;
            %chunkSize = obj.Options.NWBExporter.ChunkSize;
            %obj.Options.NWBExporter.LongDimension = 'T';

            import types.untyped.datapipe.properties.DynamicFilter
            import types.untyped.datapipe.dynamic.Filter
            import types.untyped.datapipe.properties.Shuffle

            zstdProperty = DynamicFilter(Filter.ZStandard);            
            zstdProperty.parameters = 4; % compression level.
            ShuffleProperty = Shuffle();
            dynamicProperties = [ShuffleProperty zstdProperty];

            dataSize = [...
                obj.SourceStack.ImageHeight, ...
                obj.SourceStack.ImageWidth, ...
                obj.SourceStack.NumTimepoints ];

            obj.DataPipeObject = cell(obj.SourceStack.NumPlanes, obj.SourceStack.NumChannels);

            obj.StackIterator.reset()
            for i = 1:obj.StackIterator.NumIterations
                [iZ, iC] = obj.StackIterator.next();

                % Compress the data
                obj.DataPipeObject{iZ, iC} = types.untyped.DataPipe(...
                    'maxSize', dataSize, ...
                    'dataType', obj.SourceStack.DataType, ...
                    'axis', 3, ...
                    'filters', dynamicProperties);

                imageSeries = types.core.ImageSeries( ...
                    'starting_time', 0.0, ...
                    'starting_time_rate', obj.SourceStack.MetaData.SampleRate, ...
                    'data', obj.DataPipeObject{iZ, iC}, ...
                    'data_unit', 'lumens', ...
                    'device', obj.Device);
                
                name = sprintf('whisker');
                obj.addImageSeriesToNwb(name, imageSeries)
            end
        end
        
        function device = createDevice(obj)
            device = types.core.Device();

            if ~isempty(obj.Options.NWBMetadata.DeviceDescription)
                device.description = obj.Options.NWBMetadata.DeviceDescription;
            else
                device.description = 'Whisker camera';
            end

            if ~isempty(obj.Options.NWBMetadata.DeviceManufacturer)
                device.manufacturer = obj.Options.NWBMetadata.DeviceManufacturer;
            else
                device.manufacturer = 'N/A'; % todo: obj.resolveManufacturer();
            end
        end
        
        function addImageSeriesToNwb(obj, name, twoPhotonSeries)
            
            % Add the two photon series to the acquisition group.
            name = sprintf('original_%s', name);
            obj.NWBObject.acquisition.set(name, twoPhotonSeries);
        end
    end
end
