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

Converters backed by [NeuroConv](https://neuroconv.readthedocs.io/) data interfaces, and the NWB Inspector check that `writeNwbFile` runs on each written file, call Python through MATLAB's `py.*` interface. Everything else works without Python.

1. Install a Python version that both NeuroConv and your MATLAB release support. NeuroConv 0.10.2 needs Python 3.10 or later, and MathWorks lists the versions each release supports in [Versions of Python Compatible with MATLAB Products by Release](https://www.mathworks.com/support/requirements/python-compatibility.html). R2024b, for example, supports 3.10, 3.11 and 3.12.

2. Create a virtual environment and install the packages listed in `python/requirements.txt` of the cloned NANSEN-NWB repository. On macOS or Linux:

   ```bash
   cd path/to/NANSEN-NWB
   python3.12 -m venv ~/.venvs/nansen-nwb
   ~/.venvs/nansen-nwb/bin/pip install -r python/requirements.txt
   ```

   On Windows the environment's programs are in `Scripts` rather than `bin`, for example `%USERPROFILE%\.venvs\nansen-nwb\Scripts\pip.exe`.

3. Point MATLAB at the environment's Python before anything in the session has loaded Python:

   ```matlab
   pyenv(Version="~/.venvs/nansen-nwb/bin/python", ExecutionMode="OutOfProcess")
   ```

   MATLAB saves this setting, so later sessions use the same Python. Once a session has loaded Python, `pyenv` cannot switch to another: restart MATLAB, or, when Python runs out of process, call `terminate(pyenv)` first.

4. Check that MATLAB can run NeuroConv:

   ```matlab
   [isAvailable, report] = nansen.module.nwb.neuroconv.hasNeuroconv("Refresh")
   ```

   `report.Message` says what is missing when `isAvailable` is false. `hasNeuroconv` keeps its result for the MATLAB session, and `"Refresh"` checks again.

Not every NeuroConv converter works with the versions in `python/requirements.txt`. [docs/neuroconv-converters.md](docs/neuroconv-converters.md) lists which ones convert.

## Custom converters

The configurator offers the converters in `+nansen/+module/+nwb/+conversion/+builtin`, the NeuroConv data interfaces, and any converter you register from your own folder:

```matlab
nansen.module.nwb.registerConverterFolder("/lab/code/nwbconverters")
```

[docs/converters.md](docs/converters.md) describes how to write a converter.

## License

MIT. See [LICENSE](LICENSE).
