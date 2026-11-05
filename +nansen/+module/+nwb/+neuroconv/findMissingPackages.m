function missingNames = findMissingPackages(packageNames, action)
%findMissingPackages - List the Python packages that are not installed
%   MISSINGNAMES = findMissingPackages(PACKAGENAMES) returns the names in
%   PACKAGENAMES that have no installed distribution in the Python MATLAB
%   is configured to use. Names are distribution names, as pip installs
%   them, such as "roiextractors" or "pillow".
%
%   MISSINGNAMES = findMissingPackages(PACKAGENAMES,"Refresh") checks
%   again instead of using the answers cached for the MATLAB session.
%   Call it after installing packages.
%
%   It loads Python if this session has not, so call it after
%   hasNeuroconv reports a working interpreter.
%
%   Example: Ask which of the TIFF converter's packages are missing
%       missing = nansen.module.nwb.neuroconv.findMissingPackages( ...
%           ["roiextractors", "tifffile"])
%
%   See also nansen.module.nwb.neuroconv.hasNeuroconv

    arguments
        packageNames (1,:) string
        action (1,1) string {mustBeMember(action, ["Check", "Refresh"])} = "Check"
    end

    % Reading package metadata is a round trip to Python for each name,
    % and the configurator asks for every row it draws.
    persistent isInstalledByName

    if isempty(isInstalledByName) || action == "Refresh"
        isInstalledByName = dictionary(string.empty, logical.empty);
    end

    isMissing = false(size(packageNames));
    for i = 1:numel(packageNames)
        name = packageNames(i);
        if ~isKey(isInstalledByName, name)
            isInstalledByName(name) = isInstalled(name);
        end
        isMissing(i) = ~isInstalledByName(name);
    end

    missingNames = packageNames(isMissing);
end

function tf = isInstalled(packageName)
%isInstalled - Whether Python has a distribution of this name installed

    metadata = py.importlib.import_module("importlib.metadata");
    try
        metadata.version(packageName);
        tf = true;
    catch exception
        % importlib.metadata raises PackageNotFoundError for a name with no
        % installed distribution. Any other failure is not an answer.
        if ~contains(exception.message, "PackageNotFoundError")
            rethrow(exception)
        end
        tf = false;
    end
end
