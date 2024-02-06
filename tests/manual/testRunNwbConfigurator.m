function testRunNwbConfigurator()
    S = createNwbTestConfiguration();
    nansen.module.nwb.gui.NWBConfigurator(S)
end