classdef NWBFile < NwbFile
% NWB File - A class representing an NWB File
%
%   This class inherits from the matnwb's NwbFile but adds some convenience
%   methods


    methods % Constructor
        function obj = NWBFile(varargin)
            
            if ~isempty(varargin)
                if ischar(varargin{1}) || isstring(varargin{1})
                    if isfile( varargin{1} )
                        filePath = varargin{1};
                        varargin = nansen.module.nwb.file.NWBFile.getFileProps(filePath);
                    end
                end
            end
            
            obj = obj@NwbFile(varargin{:});
        end
    end

    methods % Access = public

        function processingModule = getProcessingModule(obj, name, description)
        % getProcessingModule - Get (or create) a processing module

            arguments (Input)
                obj (1,1) nansen.module.nwb.file.NWBFile
                name (1,1) string        % Name of processing module
                description (1,1) string = missing % Description for processing module
            end

            % If a processing module exists, return it
            if obj.processing.isKey(name)
                processingModule = obj.processing.get(name);
            
            % Otherwise create a new processing module
            else
                processingModule = obj.createProcessingModule(name, description);
            end
        end

        function processingModule = createProcessingModule(obj, name, description) % Private?
            arguments (Input)
                obj (1,1) nansen.module.nwb.file.NWBFile
                name (1,1) string                   % Name of processing module
                description (1,1) string = missing  % Description for processing module
            end

            if ismissing(description)
                error( ['A processing module with name "%s" does not ', ...
                       'exist. Please provide a description as a second ', ...
                       'argument to create a new processing module.'], ...
                       name )
            end

            processingModule = matnwb.types.core.ProcessingModule( ...
                'description', char(description));
            obj.processing.set(name, processingModule);
        end

    end

    methods (Access = private)
        
        function initializeElectrodesTable(obj)
            
            obj.general_extracellular_ephys_electrodes = ...
                util.createElectrodeTable();
        end
    end

    methods (Static)
        function fileProps = getFileProps(filePath)

            nwbFile = nwbRead(filePath);

            propNames = properties(nwbFile);
            propValues = cellfun(@(n) nwbFile.(n), propNames, 'uni', 0);
            
            fileProps = cat(1, propNames', propValues');
            fileProps = reshape(fileProps, 1, []);
        end
    end
end

function mustBePresent(description)
    if ismissing(description)
        error('Description is missing, please provide a description')
    end    
end