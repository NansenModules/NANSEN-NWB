# Writing an NWB converter

A converter turns one data variable into one or more entries in an NWB file. It is a plain MATLAB function plus a descriptor saying what it accepts, what it produces, and how it wants to be run.

Converters come from three places, and nothing downstream distinguishes them: the ones this module ships with, the NeuroConv data interfaces reached through Python, and the ones a lab registers from its own folder.

## The function

A converter takes one argument, the conversion context, and returns the mutated file or a result struct:

```matlab
function nwbFile = convertMyData(context)
    myObject = types.core.TimeSeries( ...
        'data', context.Data.values, ...
        'timestamps', seconds(context.Data.Time), ...
        'data_unit', 'volts');

    nwbFile = nansen.module.nwb.conversion.placeNeurodata( ...
        context.NwbFile, myObject, context.Placement);
end
```

An `NwbFile` is a handle, so a converter may also mutate `context.NwbFile` and return nothing.

### The context

| Field | What it holds |
|---|---|
| `NwbFile` | The file being built, or empty for a converter that writes the file itself |
| `FilePath` | Where the NWB file is being written |
| `Data` | The data variable, resolved through the runner's data resolver |
| `Metadata` | Metadata for this item, to be written into the file |
| `ConverterArgs` | Options the converter needs, not written into the file |
| `Placement` | Where the output belongs: `Name`, `PrimaryGroup`, `NWBModule` |
| `DataItem` | The configured item, for anything the fields above do not cover |
| `Descriptor` | The converter's own descriptor |
| `Config` | The whole file configuration |

`Data` is whatever the resolver returns. For large data that is a lazy object such as a `nansen.stack.ImageStack`, not a materialized array. **A converter must not force a full load unless its descriptor says it does**; one that streams large data to disk should be an external converter and read the source itself.

`Metadata` is what gets written into the NWB file. `ConverterArgs` is what the converter needs to do its job. Keeping them apart is why a channel index or a plane name does not end up in the file as if it were experimental metadata.

### The result

| Return | Meaning |
|---|---|
| An `NwbFile` | The mutated file |
| Nothing | The context's file was mutated in place |
| `struct("DidWriteFile", true)` | The converter wrote the file itself |
| `struct("NeuroData", obj)` | The runner places `obj` according to `Placement` |
| `struct(..., "PlacementOverride", p)` | Honored only if the descriptor allows it |

## The descriptor

```matlab
descriptor = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
    Name="MyLabRecording", ...
    DisplayName="My lab recording", ...
    Description="Convert a MyLab recording to an ElectricalSeries.", ...
    AcceptedClasses="mylab.Recording", ...
    AcceptedFormats="mylab-binary", ...
    ProducesNWBType="ElectricalSeries", ...
    PrimaryGroup="Acquisition", ...
    NWBModuleTags="ecephys", ...
    Function=@convertMyLabRecording);
```

The constructor validates the descriptor, so an inconsistent one fails where it is written rather than partway through a conversion.

| Field | Purpose |
|---|---|
| `Name` | Registry key. Required |
| `DisplayName` | Label in the configurator. Defaults to `Name` |
| `Source` | `builtin`, `neuroconv` or `custom`. Set for you when registered from a folder |
| `AcceptedClasses` | MATLAB classes the converter takes. `"*"` for anything |
| `AcceptedFormats` | Source formats it reads |
| `ProducesNWBType` | Neurodata type it creates, or `"*"` if chosen at conversion time |
| `RequiresNWBTypes` | Types that must already exist in the file |
| `PrimaryGroup` | Default group: Acquisition, Processing, Analysis, Intervals, Stimulus |
| `NWBModuleTags` | Processing modules the converter suits |
| `ExecutionMode` | `mutate` (default) or `external` |
| `PlacementPolicy` | `config` (default) or `converter` |
| `AllowsPlacementOverride` | Whether a result may move its own output |
| `RequiresPython` | Whether the converter needs Python |
| `NeedsData` | Whether the runner should resolve the data at all |
| `MetadataSchema` | Fields and defaults for the metadata form |
| `DefaultConverterArgs` | Arguments merged under the item's own |
| `Function` | Handle taking one context. Required |

### Why classes and formats are separate

Most converters that read a file take a path, so a converter declaring "I accept a file path" would match every file-backed variable in the session. That is exactly where the configurator most needs to discriminate.

The registry ranks matches instead: a converter naming the variable's **format** beats one accepting its **class**, which beats one matching only the **file extension**, which beats one accepting **anything**. Declare a format when your converter reads a particular kind of file, and a class when it takes a MATLAB object.

## Registering a lab's converters

A converter in a registered folder returns its own descriptor when asked for one:

```matlab
function result = convertMyLabRecording(context)
    if nargin == 1 && (isstring(context) || ischar(context)) && string(context) == "descriptor"
        result = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
            Name="MyLabRecording", ...
            AcceptedClasses="mylab.Recording", ...
            ProducesNWBType="ElectricalSeries", ...
            Function=@convertMyLabRecording);
        return
    end

    % ... convert, as above
end
```

Then, once per MATLAB session:

```matlab
nansen.module.nwb.registerConverterFolder("/lab/code/nwbconverters")
```

Files that do not answer the descriptor request are left alone, so helpers can live beside the converters. After editing a converter, `nansen.module.nwb.refreshConverters()` picks up the change; registered folders survive the refresh.

## Converters that write the file themselves

A converter that streams data too large to hold in memory, or hands the work to another tool, declares itself external:

```matlab
descriptor = nansen.module.nwb.conversion.NWBConverterDescriptor( ...
    Name="MyLargeRecording", ...
    AcceptedClasses="mylab.Recording", ...
    ProducesNWBType="ElectricalSeries", ...
    ExecutionMode="external", ...
    PlacementPolicy="converter", ...
    Function=@convertMyLargeRecording);
```

An external converter must declare `PlacementPolicy="converter"`, because by the time it returns, the runner has nothing left to place. It must return `struct("DidWriteFile", true)`.

The runner writes everything it is holding in memory to disk before an external converter runs, and reads the file back afterwards. An external converter can therefore rely on the file existing and on it containing everything converted so far.

## How the runner treats a conversion

1. It creates the NWB file and writes the session, subject and general metadata. Exactly one writer owns the file-level metadata, and it is not a converter.
2. It orders items so a converter producing a type runs before one requiring it. ROI signals index the plane segmentation's rows, so the masks are converted first whatever order the configuration lists them in.
3. It runs each converter, resolving data only for converters that asked for it.
4. It writes the file once at the end, and before each external converter.

That last point is not only an optimization. `NwbFile.export` appends an entry to `file_create_date` on every call and rewrites the whole file, so exporting per item both mis-stamps the file and makes a conversion quadratic in the data already written.

## Reporting problems

Fail with a message that names the data item and says what to change:

```matlab
error("nansen:nwb:invalidConverterInput", ...
    ['The My Lab converter needs a mylab.Recording, but ''%s'' is %s. ', ...
     'Choose a converter that accepts %s.'], ...
    context.DataItem.VariableName, class(context.Data), class(context.Data))
```

Do not substitute a default for missing metadata. A file that claims a subject or a sampling rate nobody supplied is worse than one that failed to convert.
