function testRunNWBConfigurator()
    S = createNWBTestConfiguration();
    nansen.module.nwb.gui.NWBConfigurator(S)
end