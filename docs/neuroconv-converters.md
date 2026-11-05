# NeuroConv converters

The configurator offers [NeuroConv](https://neuroconv.readthedocs.io/) data interfaces as converters. They run in the Python environment that [python-setup.md](python-setup.md) sets up.

With the versions in `python/requirements.txt`, the NeuroConv converters behave as follows:

| Converter | With these versions |
|---|---|
| `NeuroConvAbfInterface` | Converts. Set `IcephysExperimentType` in the item's converter arguments to `current_clamp`, `voltage_clamp` or `izero`: NeuroConv cannot read the clamp mode from an ABF 2 file with a protocol and fails on it without the argument, while a file without command data is written as izero. NeuroConv 0.10 deprecates `AbfInterface` and removes it in 0.12, so each conversion prints a `FutureWarning`. |
| `NeuroConvTiffImagingInterface` | Converts. |
| `NeuroConvImageInterface` | Fails. NeuroConv 0.10.2 cannot append an image to an existing NWB file (`'chunks' must have same rank as dataset shape`), and `writeNwbFile` always appends. |
| `NeuroConvScanImageImagingInterface`, `NeuroConvSuite2pSegmentationInterface`, `NeuroConvDeepLabCutInterface` | Their packages are installed; no conversion has been checked with these versions. |
