classdef ConverterRegistry < handle
%ConverterRegistry - Registry of built-in, NeuroConv and custom converters
%   OBJ = ConverterRegistry() creates a registry holding the converters
%   that ship with this module. Most callers want the shared registry
%   from ConverterRegistry.instance instead of a private one.
%
%   OBJ = ConverterRegistry(IncludeBuiltin=false) creates an empty
%   registry instead, for a caller that wants only the converters it adds
%   itself.
%
%   The registry answers which converters can handle a given data
%   variable, and which can produce a given neurodata type. It is the one
%   abstraction the configurator, the runner and the session layer share.
%
%   Matching is ranked rather than boolean. A converter that names the
%   variable's source format is a better answer than one that merely
%   accepts its MATLAB class, which in turn beats one that accepts
%   anything. Callers get matches best-first and can show the whole list.
%
%   ConverterRegistry functions:
%       add                - Register one converter descriptor
%       get                - Look up a converter by name
%       list               - Return every registered descriptor
%       names              - Return every registered converter name
%       findForSourceInfo  - Rank converters against source evidence
%       findByDataType     - Find converters accepting a MATLAB class
%       findByNWBType      - Find converters producing a neurodata type
%       findByNWBModule    - Find converters suited to a processing module
%       registerFolder     - Register every converter in a folder
%
%   See also nansen.module.nwb.conversion.NWBConverterDescriptor,
%   nansen.module.nwb.registerConverterFolder,
%   nansen.module.nwb.conversion.NWBFileConverter

    properties (Constant, Access = private)
        % Match strength, best first. A format is the strongest evidence
        % because it names the thing the converter actually reads; a
        % MATLAB class is weaker because many converters share one class;
        % a file extension is weaker still because it is guessed from a
        % path; a wildcard means the converter did not discriminate.
        RANK_FORMAT = 4
        RANK_CLASS = 3
        RANK_EXTENSION = 2
        RANK_WILDCARD = 1
        RANK_NONE = 0
    end

    properties (SetAccess = private)
        %Descriptors - Registered converter descriptors
        Descriptors (:,1) nansen.module.nwb.conversion.NWBConverterDescriptor = ...
            nansen.module.nwb.conversion.NWBConverterDescriptor.empty(0, 1)

        %ConverterFolders - Folders registered with registerFolder
        ConverterFolders (1,:) string = strings(1, 0)
    end

    methods
        function obj = ConverterRegistry(options)
            arguments
                options.IncludeBuiltin (1,1) logical = true
            end

            if options.IncludeBuiltin
                obj.registerBuiltinConverters()
            end
        end

        function add(obj, descriptor)
            %add - Register one converter descriptor
            %   add(OBJ,DESCRIPTOR) registers DESCRIPTOR, which may be an
            %   NWBConverterDescriptor or a struct in the same shape.
            %
            %   Errors:
            %     nansen:nwb:duplicateConverter - the name or display name
            %                     is already registered.

            descriptor = nansen.module.nwb.conversion.NWBConverterDescriptor...
                .fromAny(descriptor);

            if any(obj.registeredNames() == descriptor.Name)
                error("nansen:nwb:duplicateConverter", ...
                    ['A converter named ''%s'' is already registered. ', ...
                     'Give this converter a different Name.'], descriptor.Name)
            end

            % Display names reach the user in a dropdown, where two
            % identical entries are indistinguishable.
            isSameLabel = obj.registeredDisplayNames() == descriptor.DisplayName;
            if any(isSameLabel)
                existing = obj.Descriptors(isSameLabel);
                error("nansen:nwb:duplicateConverter", ...
                    ['The display name ''%s'' is already used by converter ', ...
                     '''%s''. Give this converter a different DisplayName.'], ...
                    descriptor.DisplayName, existing(1).Name)
            end

            obj.Descriptors(end+1, 1) = descriptor;
        end

        function descriptor = get(obj, converterName)
            %get - Look up a converter by name
            %   DESCRIPTOR = get(OBJ,converterName) returns the descriptor
            %   registered under converterName.
            %
            %   Errors:
            %     nansen:nwb:unknownConverter - no such converter.

            converterName = string(converterName);
            if ismissing(converterName) || strlength(strtrim(converterName)) == 0
                error("nansen:nwb:unknownConverter", ...
                    ['No converter name was given. Set ConverterName on the ', ...
                     'data item, or choose a converter in the configurator.'])
            end

            isMatch = obj.registeredNames() == converterName;
            if ~any(isMatch)
                error("nansen:nwb:unknownConverter", ...
                    ['There is no converter named ''%s''. Available ', ...
                     'converters: %s.'], converterName, strjoin(obj.names(), ", "))
            end

            descriptor = obj.Descriptors(find(isMatch, 1));
        end

        function descriptors = list(obj)
            %list - Return every registered descriptor
            %   DESCRIPTORS = list(OBJ) returns all descriptors, in
            %   registration order.

            descriptors = obj.Descriptors;
        end

        function converterNames = names(obj)
            %names - Return every registered converter name
            %   converterNames = names(OBJ) returns the names in sorted
            %   order, suitable for an error message or a listing.

            converterNames = sort(obj.registeredNames());
        end

        function [descriptors, ranks] = findForSourceInfo(obj, sourceInfo)
            %findForSourceInfo - Rank converters against source evidence
            %   DESCRIPTORS = findForSourceInfo(OBJ,sourceInfo) returns the
            %   converters that can handle a variable described by
            %   sourceInfo, best match first. sourceInfo is the struct on
            %   NWBDataItemConfig, carrying MatlabClass, Format, Modality
            %   and Path.
            %
            %   [DESCRIPTORS,RANKS] = findForSourceInfo(...) also returns
            %   the match strength of each, so a caller can separate exact
            %   matches from converters that merely accept anything.
            %
            %   With no evidence at all every converter is returned, since
            %   there is nothing to discriminate on.

            arguments
                obj
                sourceInfo (1,1) struct
            end

            allDescriptors = obj.list();
            ranks = zeros(numel(allDescriptors), 1);
            for i = 1:numel(allDescriptors)
                ranks(i) = obj.matchRank(allDescriptors(i), sourceInfo);
            end

            isMatch = ranks > obj.RANK_NONE;
            descriptors = allDescriptors(isMatch);
            ranks = ranks(isMatch);

            % sort is stable, so converters of equal rank keep registration
            % order and the listing does not shuffle between calls.
            [ranks, order] = sort(ranks, "descend");
            descriptors = descriptors(order);
        end

        function descriptors = findByDataType(obj, dataType)
            %findByDataType - Find converters accepting a MATLAB class
            %   DESCRIPTORS = findByDataType(OBJ,dataType) returns the
            %   converters whose AcceptedClasses cover dataType.

            sourceInfo = nansen.module.nwb.config.NWBDataItemConfig.emptySourceInfo();
            sourceInfo.MatlabClass = string(dataType);
            descriptors = obj.findForSourceInfo(sourceInfo);
        end

        function descriptors = findByNWBType(obj, nwbType)
            %findByNWBType - Find converters producing a neurodata type
            %   DESCRIPTORS = findByNWBType(OBJ,nwbType) returns the
            %   converters that produce nwbType, including those that
            %   produce a type chosen at conversion time.

            allDescriptors = obj.list();
            nwbType = string(nwbType);
            isMatch = false(numel(allDescriptors), 1);
            for i = 1:numel(allDescriptors)
                producedType = allDescriptors(i).ProducesNWBType;
                isMatch(i) = producedType == "*" || producedType == nwbType;
            end
            descriptors = allDescriptors(isMatch);
        end

        function descriptors = findByNWBModule(obj, moduleName)
            %findByNWBModule - Find converters suited to a processing module
            %   DESCRIPTORS = findByNWBModule(OBJ,moduleName) returns the
            %   converters tagged for moduleName, plus those that carry no
            %   module tags and so suit any module.

            allDescriptors = obj.list();
            moduleName = lower(string(moduleName));
            isMatch = false(numel(allDescriptors), 1);
            for i = 1:numel(allDescriptors)
                tags = lower(allDescriptors(i).NWBModuleTags);
                isMatch(i) = isempty(tags) || any(tags == "*" | tags == moduleName);
            end
            descriptors = allDescriptors(isMatch);
        end

        function registerFolder(obj, folderPath)
            %registerFolder - Register every converter in a folder
            %   registerFolder(OBJ,folderPath) adds folderPath to the
            %   search path and registers every function in it that
            %   returns a converter descriptor.

            arguments
                obj
                folderPath (1,1) string {mustBeFolder}
            end

            obj.ConverterFolders(end+1) = folderPath;
            addpath(folderPath)

            files = dir(fullfile(folderPath, "*.m"));
            for i = 1:numel(files)
                functionName = erase(string(files(i).name), ".m");
                descriptor = obj.tryLoadCustomDescriptor(functionName);
                if ~isempty(descriptor)
                    descriptor.Source = "custom";
                    obj.add(descriptor)
                end
            end
        end
    end

    methods (Static)
        function registry = instance(options)
            %instance - Return the shared registry
            %   REGISTRY = instance() returns the registry shared by the
            %   configurator, the runner and the session layer, creating
            %   it on first use.
            %
            %   REGISTRY = instance(Refresh=true) discards the shared
            %   registry and builds a new one, picking up converter files
            %   that changed during this MATLAB session. Folders that were
            %   registered are registered again on the new registry, so a
            %   refresh does not quietly remove a lab's own converters.

            arguments
                options.Refresh (1,1) logical = false
            end

            persistent registryInstance

            needsBuilding = isempty(registryInstance) || ~isvalid(registryInstance);
            if ~options.Refresh && ~needsBuilding
                registry = registryInstance;
                return
            end

            previousFolders = strings(1, 0);
            if ~needsBuilding
                previousFolders = registryInstance.ConverterFolders;
            end

            registryInstance = nansen.module.nwb.conversion.ConverterRegistry();
            for i = 1:numel(previousFolders)
                if isfolder(previousFolders(i))
                    registryInstance.registerFolder(previousFolders(i))
                end
            end

            registry = registryInstance;
        end
    end

    methods (Access = private)
        function converterNames = registeredNames(obj)
            %registeredNames - Names of the registered converters
            %
            %   Indexing into an empty object array yields [], not an
            %   empty string array, so an empty registry is special-cased.

            if isempty(obj.Descriptors)
                converterNames = strings(1, 0);
            else
                converterNames = [obj.Descriptors.Name];
            end
        end

        function labels = registeredDisplayNames(obj)
            %registeredDisplayNames - Display names of registered converters

            if isempty(obj.Descriptors)
                labels = strings(1, 0);
            else
                labels = [obj.Descriptors.DisplayName];
            end
        end

        function rank = matchRank(obj, descriptor, sourceInfo)
            %matchRank - Score one descriptor against source evidence

            formats = obj.normalizeMatchText(descriptor.AcceptedFormats);
            classes = obj.normalizeMatchText(descriptor.AcceptedClasses);

            sourceFormat = obj.normalizeMatchText(getEvidence(sourceInfo, "Format"));
            sourceClass = obj.normalizeMatchText(getEvidence(sourceInfo, "MatlabClass"));

            if ~isempty(sourceFormat) && any(ismember(formats, sourceFormat))
                rank = obj.RANK_FORMAT;
                return
            end

            if ~isempty(sourceClass) && any(ismember(classes, sourceClass))
                rank = obj.RANK_CLASS;
                return
            end

            % A path only suggests a format, so it ranks below a format the
            % session actually recorded.
            extensions = obj.pathExtensions(getEvidence(sourceInfo, "Path"));
            if ~isempty(extensions) && any(ismember(formats, extensions))
                rank = obj.RANK_EXTENSION;
                return
            end

            if any(formats == "*") || any(classes == "*")
                rank = obj.RANK_WILDCARD;
                return
            end

            % No evidence at all cannot rule anything out.
            if isempty(sourceFormat) && isempty(sourceClass) && isempty(extensions)
                rank = obj.RANK_WILDCARD;
                return
            end

            rank = obj.RANK_NONE;
        end

        function descriptor = tryLoadCustomDescriptor(~, functionName)
            %tryLoadCustomDescriptor - Ask a function for its descriptor

            descriptor = [];
            try
                descriptor = feval(functionName, "descriptor");
            catch
                % A converter function that does not implement the
                % descriptor request is simply not a converter; the folder
                % may hold helpers alongside them.
                try
                    descriptor = feval(functionName);
                catch
                    descriptor = [];
                end
            end

            isDescriptor = isa(descriptor, ...
                "nansen.module.nwb.conversion.NWBConverterDescriptor") || isstruct(descriptor);
            if ~isempty(descriptor) && ~isDescriptor
                descriptor = [];
            end
        end

        function registerBuiltinConverters(obj)
            %registerBuiltinConverters - Register the converters we ship

            import nansen.module.nwb.conversion.NWBConverterDescriptor
            import nansen.module.nwb.conversion.builtin.*

            obj.add(NWBConverterDescriptor( ...
                "Name", "TimetableTimeSeries", ...
                "DisplayName", "Timetable to TimeSeries", ...
                "Description", "Convert each timetable variable to an NWB TimeSeries.", ...
                "AcceptedClasses", "timetable", ...
                "ProducesNWBType", "TimeSeries", ...
                "PrimaryGroup", "Acquisition", ...
                "NWBModuleTags", ["behavior", "misc"], ...
                "Function", @nansen.module.nwb.conversion.builtin.convertTimetableToTimeSeries))

            obj.add(NWBConverterDescriptor( ...
                "Name", "TimetableTimeIntervals", ...
                "DisplayName", "Timetable to trials or epochs", ...
                "Description", "Convert a timetable with one row per interval to a TimeIntervals table.", ...
                "AcceptedClasses", "timetable", ...
                "ProducesNWBType", "TimeIntervals", ...
                "PrimaryGroup", "Intervals", ...
                "NWBModuleTags", ["behavior", "misc"], ...
                "Function", @nansen.module.nwb.conversion.builtin.convertTimetableToTimeIntervals))

            obj.add(NWBConverterDescriptor( ...
                "Name", "ProjectionImages", ...
                "DisplayName", "Projection images to Images", ...
                "Description", "Store field of view projection images in the ophys module.", ...
                "AcceptedClasses", ["nansen.stack.ImageStack", "double", "single", "uint8", "uint16", "struct"], ...
                "ProducesNWBType", "Images", ...
                "PrimaryGroup", "Processing", ...
                "NWBModuleTags", "ophys", ...
                "PlacementPolicy", "converter", ...
                "Function", @nansen.module.nwb.conversion.builtin.convertProjectionImages))

            obj.add(NWBConverterDescriptor( ...
                "Name", "GenericNeurodataType", ...
                "DisplayName", "Generic: build a neurodata type", ...
                "Description", "Create the configured neurodata type and place it in the configured group.", ...
                "AcceptedClasses", "*", ...
                "ProducesNWBType", "*", ...
                "PrimaryGroup", "Acquisition", ...
                "NWBModuleTags", "*", ...
                "Function", @nansen.module.nwb.conversion.builtin.convertGenericNeurodataType))

            obj.add(NWBConverterDescriptor( ...
                "Name", "TwoPhotonImageStack", ...
                "DisplayName", "ImageStack to TwoPhotonSeries", ...
                "Description", "Export a NANSEN ImageStack as a two-photon image series.", ...
                "AcceptedClasses", "nansen.stack.ImageStack", ...
                "ProducesNWBType", "TwoPhotonSeries", ...
                "PrimaryGroup", "Acquisition", ...
                "NWBModuleTags", "ophys", ...
                "ExecutionMode", "external", ...
                "PlacementPolicy", "converter", ...
                "Function", @nansen.module.nwb.conversion.builtin.convertImageStackToTwoPhotonSeries))

            obj.add(NWBConverterDescriptor( ...
                "Name", "RoiGroupPlaneSegmentation", ...
                "DisplayName", "ROI group to PlaneSegmentation", ...
                "Description", "Convert an ROI group to a PlaneSegmentation in the ophys module.", ...
                "AcceptedClasses", ["nansen.roi.RoiGroup", "RoiGroup"], ...
                "AcceptedFormats", "suite2p", ...
                "ProducesNWBType", "PlaneSegmentation", ...
                "PrimaryGroup", "Processing", ...
                "NWBModuleTags", "ophys", ...
                "PlacementPolicy", "converter", ...
                "Function", @nansen.module.nwb.conversion.builtin.convertRoiGroupToPlaneSegmentation))

            obj.add(NWBConverterDescriptor( ...
                "Name", "RoiSignals", ...
                "DisplayName", "ROI signals to RoiResponseSeries", ...
                "Description", "Convert ROI signal arrays to an NWB RoiResponseSeries.", ...
                "AcceptedClasses", ["double", "single", "struct"], ...
                "AcceptedFormats", "roisignals", ...
                "ProducesNWBType", "RoiResponseSeries", ...
                "RequiresNWBTypes", "PlaneSegmentation", ...
                "PrimaryGroup", "Processing", ...
                "NWBModuleTags", "ophys", ...
                "PlacementPolicy", "converter", ...
                "Function", @nansen.module.nwb.conversion.builtin.convertRoiSignals))

            obj.registerNeuroconvConverters()
        end

        function registerNeuroconvConverters(obj)
            %registerNeuroconvConverters - Register the NeuroConv interfaces

            import nansen.module.nwb.conversion.NWBConverterDescriptor

            % Each entry is one NeuroConv DataInterface. The lookup grows
            % as interfaces are tested; see docs/converters.md.
            interfaces = { ...
                "NeuroConvDataInterface", "Advanced: raw NeuroConv interface", ...
                    "Run any NeuroConv data interface named in the converter arguments.", ...
                    strings(1, 0), "*", "Acquisition", "*", struct(); ...
                "NeuroConvImageInterface", "NeuroConv: image sequence", ...
                    "Run the NeuroConv ImageInterface over a folder of images.", ...
                    ["image", "imagesequence"], "Images", "Acquisition", "ophys", ...
                    struct("InterfaceClassName", "ImageInterface", ...
                        "SourceArgumentName", "file_paths", "SourcePathMode", "fileList"); ...
                "NeuroConvTiffImagingInterface", "NeuroConv: TIFF imaging", ...
                    "Run the NeuroConv TiffImagingInterface over a TIFF file.", ...
                    ["tif", "tiff"], "TwoPhotonSeries", "Acquisition", "ophys", ...
                    struct("InterfaceClassName", "TiffImagingInterface", ...
                        "SourceArgumentName", "file_path", "SourcePathMode", "file"); ...
                "NeuroConvScanImageImagingInterface", "NeuroConv: ScanImage imaging", ...
                    "Run the NeuroConv ScanImageImagingInterface over a ScanImage TIFF.", ...
                    "scanimage", "TwoPhotonSeries", "Acquisition", "ophys", ...
                    struct("InterfaceClassName", "ScanImageImagingInterface", ...
                        "SourceArgumentName", "file_path", "SourcePathMode", "file"); ...
                "NeuroConvSuite2pSegmentationInterface", "NeuroConv: Suite2p segmentation", ...
                    "Run the NeuroConv Suite2pSegmentationInterface over a Suite2p folder.", ...
                    "suite2p", "PlaneSegmentation", "Processing", "ophys", ...
                    struct("InterfaceClassName", "Suite2pSegmentationInterface", ...
                        "SourceArgumentName", "folder_path", "SourcePathMode", "parentFolder"); ...
                "NeuroConvDeepLabCutInterface", "NeuroConv: DeepLabCut pose", ...
                    "Run the NeuroConv DeepLabCutInterface over a DeepLabCut output file.", ...
                    ["deeplabcut", "dlc"], "PoseEstimation", "Processing", "behavior", ...
                    struct("InterfaceClassName", "DeepLabCutInterface", ...
                        "SourceArgumentName", "file_path", "SourcePathMode", "file"); ...
                "NeuroConvAbfInterface", "NeuroConv: ABF patch clamp", ...
                    "Run the NeuroConv AbfInterface over the ABF files of a session.", ...
                    "abf", "PatchClampSeries", "Acquisition", "icephys", ...
                    struct("InterfaceClassName", "AbfInterface", ...
                        "SourceArgumentName", "file_paths", "SourcePathMode", "siblingFiles", ...
                        "UseInterfaceMetadata", true)};

            for i = 1:size(interfaces, 1)
                obj.add(NWBConverterDescriptor( ...
                    "Name", interfaces{i, 1}, ...
                    "DisplayName", interfaces{i, 2}, ...
                    "Source", "neuroconv", ...
                    "Description", interfaces{i, 3}, ...
                    "AcceptedClasses", "*", ...
                    "AcceptedFormats", interfaces{i, 4}, ...
                    "ProducesNWBType", interfaces{i, 5}, ...
                    "PrimaryGroup", interfaces{i, 6}, ...
                    "NWBModuleTags", interfaces{i, 7}, ...
                    "ExecutionMode", "external", ...
                    "PlacementPolicy", "converter", ...
                    "RequiresPython", true, ...
                    "NeedsData", false, ...
                    "DefaultConverterArgs", interfaces{i, 8}, ...
                    "Function", @nansen.module.nwb.conversion.builtin.convertWithNeuroconv))
            end
        end
    end

    methods (Static, Access = private)
        function extensions = pathExtensions(paths)
            %pathExtensions - Extract normalized extensions from paths

            extensions = strings(1, 0);
            paths = string(paths);
            paths = paths(~ismissing(paths) & paths ~= "");
            if isempty(paths)
                return
            end

            [~, ~, extensions] = fileparts(paths);
            extensions = nansen.module.nwb.conversion.ConverterRegistry...
                .normalizeMatchText(extensions);
        end

        function values = normalizeMatchText(values)
            %normalizeMatchText - Case-fold and strip dots for comparison

            values = lower(strtrim(string(values)));
            values = erase(values, ".");
            values = reshape(values(values ~= "" & ~ismissing(values)), 1, []);
        end
    end
end

function value = getEvidence(sourceInfo, fieldName)
%getEvidence - Read one evidence field, tolerating an older struct

    if isfield(sourceInfo, fieldName)
        value = sourceInfo.(fieldName);
    else
        value = strings(1, 0);
    end
end
