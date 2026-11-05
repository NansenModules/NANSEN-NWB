# NANSEN-NWB

A [NANSEN](https://github.com/VervaekeLab/NANSEN) module for converting the sessions of a NANSEN project to [NWB](https://www.nwb.org/) files. You configure once per project which data variables go into the NWB file and how they are converted, then write one file per session.

## Requirements

- MATLAB R2022b or later
- [NANSEN](https://github.com/VervaekeLab/NANSEN)
- [matnwb](https://github.com/NeurodataWithoutBorders/matnwb)
- [entity-table](https://github.com/ehennestad/entity-table), at the commit pinned in `requirements.txt`
- Optional: Python with the packages in `python/requirements.txt`, for the NeuroConv-based converters and the NWB Inspector check (see [Python](#python))

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/NansenModules/NANSEN-NWB.git
   ```

2. In MATLAB, add the repository folder to the path and install entity-table:

   ```matlab
   addpath("path/to/NANSEN-NWB")
   matbox.installRequirements("path/to/NANSEN-NWB")
   ```

   NANSEN lists every `+nansen/+module` package on the MATLAB path as a module.

3. In NANSEN, open **Nansen ▸ Configure ▸ Modules...** and select **NANSEN-NWB** for your project.

## Getting started

1. **Define data variables.** The configurator lists the project's data variables, so the project needs at least one (**Nansen ▸ Configure ▸ Variables...**).
2. **Configure the conversion.** Open **Tools ▸ Nwb ▸ Configure Nwb File**. For each data variable, pick a converter, where its output goes in the NWB file, and the metadata the converter takes. The configuration is saved as `nwb_conversion_configuration.json` in the project's `nwb` configuration folder.
3. **Add project-wide metadata (optional).** Put a `nwb_metadata_defaults.json` in the same folder to fill fields that no session carries:

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

## Python

The NeuroConv converters and the NWB Inspector check after each write run through MATLAB's Python interface. Everything else works without Python.

Create a virtual environment and install the packages listed in `python/requirements.txt` of the cloned NANSEN-NWB repository (commands for macOS and Linux):

```bash
cd path/to/NANSEN-NWB
python -m venv ~/.venvs/nansen-nwb
~/.venvs/nansen-nwb/bin/pip install -r python/requirements.txt
```

Then point MATLAB at that environment and check that NeuroConv is found:

```matlab
pyenv(Version="~/.venvs/nansen-nwb/bin/python", ExecutionMode="OutOfProcess")
[isAvailable, report] = nansen.module.nwb.neuroconv.hasNeuroconv()
```

When `isAvailable` is false, `report.Message` says what is missing.

## Custom converters

The configurator offers the converters in `+nansen/+module/+nwb/+conversion/+builtin`, the NeuroConv data interfaces, and any converter you register from your own folder:

```matlab
nansen.module.nwb.registerConverterFolder("/lab/code/nwbconverters")
```

[docs/converters.md](docs/converters.md) describes how to write a converter.

## License

MIT. See [LICENSE](LICENSE).
