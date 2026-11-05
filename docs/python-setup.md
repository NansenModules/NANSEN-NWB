# Python setup

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

Not every NeuroConv converter works with the versions in `python/requirements.txt`. [neuroconv-converters.md](neuroconv-converters.md) lists which ones convert.
