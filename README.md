# Nansen-NWB
Development of NWB integration into Nansen (NWB hackaton participation project)

## Requirements and Installation
NANSEN-NWB requires **MATLAB R2022b** or later, [matnwb](https://github.com/NeurodataWithoutBorders/matnwb) and [NANSEN](https://github.com/VervaekeLab/NANSEN).

### Python

Converters backed by [NeuroConv](https://neuroconv.readthedocs.io/) data interfaces, and the NWB Inspector check that `writeNwbFile` runs on each written file, call Python through MATLAB's `py.*` interface. Everything else works without Python.

1. Install a Python version that both NeuroConv and your MATLAB release support. NeuroConv 0.10.2 needs Python 3.10 or later, and MathWorks lists the versions each release supports in [Versions of Python Compatible with MATLAB Products by Release](https://www.mathworks.com/support/requirements/python-compatibility.html). R2024b, for example, supports 3.10, 3.11 and 3.12.

2. Create a virtual environment and install the packages in `python/requirements.txt` into it. From this folder, on macOS or Linux:

   ```bash
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

With the versions in `python/requirements.txt`, the NeuroConv converters behave as follows:

| Converter | With these versions |
|---|---|
| `NeuroConvAbfInterface` | Converts. NeuroConv 0.10 deprecates `AbfInterface` and removes it in 0.12, so each conversion prints a `FutureWarning`. |
| `NeuroConvTiffImagingInterface` | Converts. |
| `NeuroConvImageInterface` | Fails. NeuroConv 0.10.2 cannot append an image to an existing NWB file (`'chunks' must have same rank as dataset shape`), and `writeNwbFile` always appends. |
| `NeuroConvScanImageImagingInterface`, `NeuroConvSuite2pSegmentationInterface`, `NeuroConvDeepLabCutInterface` | Their packages are installed; no conversion has been checked with these versions. |

The configurator's list is drawn by [entity-table](https://github.com/ehennestad/entity-table), pinned in `requirements.txt`; install it with `matbox.installRequirements(<this folder>)`.

## Configuring a conversion

`Tools > NWB > Configure NWB File` in NANSEN opens the configurator, `nansen.module.nwb.gui.NWBConfiguratorApp`: one row per data variable, and a panel for the selected one that sets the converter, where its output goes in the file, and the metadata and arguments the converter takes. Converters come from the registry: the ones in `+conversion/+builtin`, the NeuroConv data interfaces, and any a lab registers from its own folder with `nansen.module.nwb.registerConverterFolder`; `docs/converters.md` says how to write one. What the panel says a conversion would do with an item is what `writeNwbFile` does, since both ask `ConverterRegistry.resolveForItem`.

The configuration is saved as JSON in the project's `nwb` configuration folder, where `nwb_metadata_defaults.json` may hold what every conversion in the project shares: institution, lab, experimenter, keywords, species. A project that still has a pilot `.mat` configuration has it converted when the configurator opens, and the JSON is saved beside it.

Dynamic tables, such as the electrodes table the pilot configurator edited on its Tables page, have no place in the JSON configuration. A converter that needs one builds it, as the ROI converters build the plane segmentation.

`Data > nwb > Write NWB file` converts one session: it fills the file-level metadata from the session, the subject table and the defaults, runs each item's converter, and checks the written file with NWB Inspector when Python has it.

## Project Description

Create a set of classes to interact with NWB data (read/write) from NANSEN. NANSEN is a matlab package for managing, processing and visualizing calcium imaging data: https://github.com/VervaekeLab/NANSEN

## Objectives

<!-- Briefly describe the objectives of your project. What would you like to achieve?-->

1. Objective A: Create a list of data variables with names according to the NWB Schemas
2. Objective B: Create a data input/output interface for NWB files. Read and write specific variables to NWB files.
3. Objective C: Learn more about how other people use NWB and what kind of data readers/writers already exists.

## Approach and Plan

1. Create an abstract VariableFileAdapter class. A class providing methods for a) reading and writing a predefined variable from/to a specified file format and b) specify how to open data for visualization.
2. Create an abstract DataIOModel. Class interface to read/write data from/to different datalocations, using different variable file-adapters
3. Create implementations of VariableFileAdapter for the NWB format
4. Use classes above to read experiment dataset from my phd work and save it to NWB file.
5. Use classes above to read an NWB dataset into a Nansen project.

## Progress and Next Steps

<!--Populate this section as you are making progress before/during/after the hackathon-->
<!--Describe the progress you have made on the project, e.g., which objectives you have achieved and how.-->
<!--Describe the next steps you are planning to take to complete the project.-->

## Materials

<!--If available add links to the materials relevant to the project, e.g., the code generated for the project or data used-->
<!--If available add pictures and links to videos that demonstrate what has been accomplished.-->
<!--![Description of picture](Example2.jpg)-->

See https://github.com/NansenModules/NANSEN-NWB.git for details

## Background and References

<!--Use this space for information that may help people better understand your project, like links to papers, source code, or data ,e.g:-->
<!-- - Source code: https://github.com/YourUser/YourRepository -->
<!-- - Documentation: https://link.to.docs -->
<!-- - Test data: https://link.to.test.data -->
