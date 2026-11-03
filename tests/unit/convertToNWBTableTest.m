classdef convertToNWBTableTest < matlab.unittest.TestCase
%convertToNWBTableTest - Tests for convertToNWBTable
%
%   Tests nansen.module.nwb.internal.dtable.convertToNWBTable, which turns
%   a stored MATLAB table into the DynamicTable subclass an NWB file
%   requires for it.
%
%   These tests need matnwb on the MATLAB path with generated core types
%   that include ElectrodesTable (NWB schema 2.9.0 or later), and the
%   NANSEN utility packages. They are filtered when either is unavailable.
%
%   See also: nansen.module.nwb.internal.dtable.convertToNWBTable

    methods (TestClassSetup)

        function addModuleToPath(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(repositoryRoot()))
        end

        function assumeMatnwbIsAvailable(testCase)
            testCase.assumeNotEmpty(which("misc.getMatnwbDir"), ...
                "matnwb is not on the MATLAB path.")
            testCase.assumeNotEmpty(which("types.core.ElectrodesTable"), ...
                "matnwb core types do not include ElectrodesTable.")
            testCase.assumeNotEmpty(which("utility.string.getSimpleClassName"), ...
                "The NANSEN utility packages are not on the MATLAB path.")
        end
    end

    methods (Test)

        function electrodesTableGetsItsOwnType(testCase)
            [electrodesTable, ~] = createElectrodesTableWithOneRow();

            nwbTable = convertNamed(electrodesTable, "ElectrodesTable");

            testCase.verifyClass(nwbTable, "types.core.ElectrodesTable")
            testCase.verifyEqual(sort(string(nwbTable.colnames)), ...
                sort(string(electrodesTable.Properties.VariableNames)))
        end

        function otherTablesStayPlainDynamicTables(testCase)
            trials = table([0; 1], [1; 2], 'VariableNames', {'start', 'stop'});

            nwbTable = convertNamed(trials, "TrialsTable");

            testCase.verifyClass(nwbTable, "types.hdmf_common.DynamicTable")
        end

        function electrodesTableIsAcceptedByNwbFileAndExports(testCase)
            % The type matters because NwbFile validates the electrodes
            % property, so the converted table is placed on a file and the
            % file written, the two steps the metadata resolver performs.
            [electrodesTable, nwbFile] = createElectrodesTableWithOneRow();
            nwbTable = convertNamed(electrodesTable, "ElectrodesTable");

            nansen.module.nwb.file.addMetadataObject( ...
                nwbFile, "ElectrodesTable", nwbTable);

            testCase.verifySameHandle( ...
                nwbFile.general_extracellular_ephys_electrodes, nwbTable)

            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            filePath = fullfile(folder, "electrodes.nwb");
            nwbExport(nwbFile, filePath);

            testCase.verifyTrue(isfile(filePath))
        end
    end
end

function nwbTable = convertNamed(matlabTable, tableName)
    nwbTable = nansen.module.nwb.internal.dtable.convertToNWBTable( ...
        matlabTable, tableName);
end

function [electrodesTable, nwbFile] = createElectrodesTableWithOneRow()
% createElectrodesTableWithOneRow - An electrodes table as the resolver sees it
%
%   The editor stores an ElectrodeGroup object in the "group" column. The
%   metadata resolver adds that group to the file and swaps the column for
%   ObjectView references before converting, and this mirrors that state.

    nwbFile = NwbFile( ...
        'identifier', 'convertToNWBTableTest', ...
        'session_description', 'Electrodes table conversion test', ...
        'session_start_time', datetime(2026, 1, 1, 'TimeZone', 'local'));

    device = types.core.Device('description', 'Test probe');
    nwbFile.general_devices.set('probe', device);

    electrodeGroup = types.core.ElectrodeGroup( ...
        'description', 'Test shank', ...
        'location', 'CA1', ...
        'device', types.untyped.SoftLink(device));
    nwbFile.general_extracellular_ephys.set('shank1', electrodeGroup);

    electrodesTable = nansen.module.nwb.internal.dtable.initializeElectrodesTable();
    electrodesTable(1, :) = {'', electrodeGroup, "shank1", 0, "CA1", "", ...
        0, 0, 0, 0, 0, 0};
    electrodesTable.group = types.untyped.ObjectView(electrodeGroup);
end

function folderPath = repositoryRoot()
    folderPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
