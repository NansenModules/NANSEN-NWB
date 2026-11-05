# NANSEN-NWB

A [NANSEN](https://github.com/VervaekeLab/NANSEN) module for converting the sessions of a NANSEN project to [NWB](https://www.nwb.org/) files. You configure once per project which data variables go into the NWB file and how they are converted, then write one file per session.

## Requirements

- MATLAB R2022b or later
- [NANSEN](https://github.com/VervaekeLab/NANSEN)
- [matnwb](https://github.com/NeurodataWithoutBorders/matnwb)
- [entity-table](https://github.com/ehennestad/entity-table), at the commit pinned in `requirements.txt`
- [MatBox](https://github.com/ehennestad/matbox), to install entity-table from `requirements.txt`. NANSEN requires MatBox as well, so it is normally installed already.
- Optional: Python with the packages in `python/requirements.txt`, for the NeuroConv-based converters and the NWB Inspector check

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/NansenModules/NANSEN-NWB.git
   ```

2. In MATLAB, add the repository folder to the path and install entity-table with MatBox:

   ```matlab
   addpath("path/to/NANSEN-NWB")
   matbox.installRequirements("path/to/NANSEN-NWB")
   ```

   `matbox.toolboxversion` prints the installed MatBox version. If MATLAB cannot find it, install MatBox as the [MatBox README](https://github.com/ehennestad/matbox#installation) describes.

   NANSEN lists every `+nansen/+module` package on the MATLAB path as a module.

3. In NANSEN, open **Nansen ▸ Configure ▸ Modules...** and select **NANSEN-NWB** for your project.

4. Optional: to use the NeuroConv-based converters and the NWB Inspector check, set up Python as [docs/python-setup.md](docs/python-setup.md) describes.

## Getting started

1. **Define data variables.** The configurator lists the project's data variables, so the project needs at least one (**Nansen ▸ Configure ▸ Variables...**).
2. **Configure the conversion.** Open **Tools ▸ Nwb ▸ Configure Nwb File**. For each data variable, pick a converter, where its output goes in the NWB file, and the metadata the converter takes. The configuration is saved as `nwb_conversion_configuration.json` in `<project folder>/configurations/nwb`. To get that path in MATLAB:

   ```matlab
   project = nansen.getCurrentProject();
   project.getConfigurationFolder(Subfolder="nwb")
   ```

3. **Add project-wide metadata (optional).** Create `nwb_metadata_defaults.json` in `<project folder>/configurations/nwb`, next to the conversion configuration, to fill fields that no session carries:

   ```json
   {
     "SubjectMetadata": { "species": "Mus musculus" },
     "GeneralMetadata": {
       "institution": "University of Oslo",
       "lab": "Example lab",
       "experimenter": ["Lastname, Firstname"],
       "keywords": ["two-photon", "hippocampus"]
     }
   }
   ```

   Values from the session take precedence over these defaults.
4. **Write the files.** Select sessions in the session table and run **Data ▸ Nwb ▸ Write Nwb File**. Each session gets `sub-<subjectID>_ses-<sessionID>.nwb` in its session folder, with session, subject and file metadata filled from the session table, the project's Subject table if it has one, and the defaults.

## Custom converters

The configurator offers the converters in `+nansen/+module/+nwb/+conversion/+builtin`, the NeuroConv data interfaces ([docs/neuroconv-converters.md](docs/neuroconv-converters.md) lists which ones work), and any converter you register from your own folder:

```matlab
nansen.module.nwb.registerConverterFolder("/lab/code/nwbconverters")
```

[docs/converters.md](docs/converters.md) describes how to write a converter.

## License

MIT. See [LICENSE](LICENSE).
