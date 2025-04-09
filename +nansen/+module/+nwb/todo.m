% 1) NWB configurator can be run on project level and session level.
%
% 2) If run on session, those specific changes are saved to a json and used
%    instead of project setting on conversion.
%
% 3) Make conversion functions for the main neurodata types..
%
% Biggest challenges: 
% 1) How to deal with types with many dependency types,
%    like two-photon-series with device, imaging-plane and optical-channel
% 2) How to deal with dynamic tables. How the fuck to deal with electrodes
% table where the group name is depending on the group in a different
% column..
%  


% Todo: 
% [?] Linked /embedded metadata should have a special format. ?
%    name
%    neurodata_type
%    metadata

% [ ] Object views. Link to table + rows / ids of table...
%     - Use case example: Electrical Series / Electrodes. 
%       [ ] In ElectricalSeries / Electrodes, the option for electrode 
%           should be Edit DynamicTableRegion
%       [ ] The table should be prefilled, and be a pointer to the
%           electrodes dynamic table
%       [ ] DynamicTableRegion names are not added to nwb, but needed
%           internally to keep track of different views... Give default
%           name? I.e ElectrodeDynamicTableView
%
% [ ] "Dynamic Table" UI class.
%       [v] "Just" a table where rows and columns can be added or removed
%
% [ ] Add "trials" table and ability to switch between tables...
% [ ] Serialize dynamic tables, dont save nwb instances, but their uuids or
%     names?
%
% [ ] Have help/doc for types in addition to help for properties...
%
% [ ] Some types are "singletons", i.e the electrode

% 
% NWB Configurator. 
%    [v] Multi tab 
%    [v]  - Tables 
%    [v]  - DataVariables

% % % - -   - - Create dynamic tables - - - -  
%
% 1) Select the <Create dynamic table region> from a dropdown
%
% 2) Select table (sometimes this should be autoselected)
%
% 3) Open table

% How to do this:
%   2) Need to resolve which table from an inventory of tables
%        Need an inventory of tables
%      Sometimes the table type is given, but not very explicitly, i.e
%      electrodes table...
%   3) Question: Open table in NWB configurator or popup window?
%       Popup. Have a "dialog-like" app. 
%       Imagine if users can edit entries in that popup table. Then that
%       needs to be saved back to a catalog, and there should be an
%       event/notification system to update other tables of the same
%       instance that might be open...
%   
%   

% % - - - - - Electrodes table
% [ ] How to make the electrodes table a singleton that updates everywhere 
%     when changed?
%    
%       1) Create singleton file catalog with events
%       2) create singleton nwb configurator
%   ->  3) Hardcoded shit
% 
% [ ] Remove config flags before saving metadata!
% 

