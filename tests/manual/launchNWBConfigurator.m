function app = launchNWBConfigurator(options)
%launchNWBConfigurator - Open the NWB configurator on a demo configuration
%   APP = launchNWBConfigurator() opens the configurator on a configuration
%   of three demo variables, saved to a temporary JSON file, with the
%   shared converter registry. No NANSEN project is needed.
%
%   APP = launchNWBConfigurator(ListBackend="uitable") draws the list with
%   the uitable backend instead of the HTML one.
%
%   See also nansen.module.nwb.gui.NWBConfiguratorApp

    arguments
        options.ListBackend (1,1) string {mustBeMember(options.ListBackend, ["html", "uitable"])} = "html"
    end

    import nansen.module.nwb.config.NWBDataItemConfig

    speedInfo = NWBDataItemConfig.emptySourceInfo();
    speedInfo.MatlabClass = "timetable";

    roiInfo = NWBDataItemConfig.emptySourceInfo();
    roiInfo.Format = "roisignals";
    roiInfo.MatlabClass = "double";

    config = nansen.module.nwb.config.NWBFileConfiguration(DataItems=[ ...
        NWBDataItemConfig(VariableName="RunningSpeed", NWBVariableName="RunningSpeed", ...
            SourceInfo=speedInfo), ...
        NWBDataItemConfig(VariableName="RoiSignals", NWBVariableName="RoiSignals", ...
            SourceInfo=roiInfo)]);

    filePath = fullfile(tempname(), "nwb_conversion_configuration.json");
    app = nansen.module.nwb.gui.NWBConfiguratorApp(config, ...
        FilePath=filePath, ...
        VariableNames=["RunningSpeed", "RoiSignals", "PupilDiameter", "TwoPhotonStack"], ...
        ListBackend=options.ListBackend);

    fprintf("Configurator open; Save writes %s\n", filePath)
end
