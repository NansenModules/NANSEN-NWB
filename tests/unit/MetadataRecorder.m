classdef MetadataRecorder < handle
%MetadataRecorder - Test double for the runner's metadata resolver
%
%   Stands in for nansen.module.nwb.internal.resolveMetadata: records
%   what the runner asked it to resolve, marks every text field as
%   resolved so the converter can show what it received, and counts the
%   entries of the instance map it was handed, so a test can see that the
%   runner started afresh after an external converter.

    properties
        TypeNames (1,:) string = strings(1, 0)
        Files cell = {}
        MapSizes (1,:) double = []
        MetadataSeenByConverter struct = struct()
    end

    methods
        function [metadata, instanceMap] = resolve(obj, metadata, typeName, nwbFile, instanceMap)
            obj.TypeNames(end+1) = string(typeName);
            obj.Files{end+1} = nwbFile;
            if isConfigured(instanceMap)
                obj.MapSizes(end+1) = numEntries(instanceMap);
            else
                obj.MapSizes(end+1) = 0;
            end

            fieldNames = fieldnames(metadata);
            for i = 1:numel(fieldNames)
                value = metadata.(fieldNames{i});
                if ischar(value) || isstring(value)
                    metadata.(fieldNames{i}) = "resolved:" + string(value);
                end
            end

            if ~isConfigured(instanceMap)
                instanceMap = dictionary(string.empty, cell.empty);
            end
            instanceMap(string(typeName)) = {nwbFile};
        end
    end
end
