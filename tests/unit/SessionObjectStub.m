classdef SessionObjectStub < handle
%SessionObjectStub - Test double for a NANSEN session object
%
%   Holds the session table's columns as properties, as a NANSEN session
%   object does, where NWBSessionConfigBuilderTest's struct stub holds
%   them as fields. The builder reads a property of an object and a field
%   of a struct differently, so both are tested.

    properties
        subjectID = 'mouse01'
        sessionID = '20260510'
        Date = datetime(2026, 5, 10)
        Time = '14:30:00'
        Description = 'A test session'
        Experiment = 'Visual cortex imaging'
        Protocol = 'Protocol A'
        cell_id = "170518_1"
        cell_without_value = string(missing)
        sweep_numbers = [1, 2, 3]
    end

    methods
        function folderPath = getSessionFolder(~, varargin)
            folderPath = '/data/session';
        end

        function data = loadData(~, varargin)
            data = timetable();
        end

        function [filePath, variableInfo] = getDataFilePath(~, variableName)
            filePath = fullfile('/data/session', [char(variableName) '.mat']);
            variableInfo = struct("DataType", "timetable", "FileAdapter", "Default");
        end
    end
end
