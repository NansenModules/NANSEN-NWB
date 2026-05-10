# NWB Converter Contract

This document describes the current converter contract used by NANSEN-NWB.

The contract is intentionally small. A converter handles one configured data item and either mutates the current `NwbFile` object or owns the write-to-disk step itself.

## Descriptor

Converters are registered with `nansen.module.nwb.conversion.NwbConverterDescriptor`.

Required fields:

```matlab
descriptor = nansen.module.nwb.conversion.NwbConverterDescriptor( ...
    "Name", "TimetableTimeSeries", ...
    "Description", "Convert each timetable variable to an NWB TimeSeries.", ...
    "AcceptedTypes", ["timetable", "matlab.timetable"], ...
    "ProducesNwbType", "TimeSeries", ...
    "PrimaryGroup", "Acquisition", ...
    "Function", @convertTimetableToTimeSeries);
```

Important fields:

- `Name`: stable registry key.
- `DisplayName`: optional GUI label. Defaults to `Name`.
- `Source`: `builtin`, `custom`, or `neuroconv`.
- `AcceptedTypes`: source evidence matched against `SourceInfo`.
- `ProducesNwbType`: produced NWB type, or `*` when the converter controls several concrete objects.
- `PrimaryGroup`: default NWB group.
- `NwbModuleTags`: module/domain tags used by the modern GUI, for example `ophys` or `behavior`.
- `ExecutionMode`: `mutate` or `external`.
- `PlacementPolicy`: `config` or `converter`.
- `AllowsPlacementOverride`: whether a result-level `PlacementOverride` is honored.
- `DefaultConverterArgs`: default converter-specific arguments merged with per-item `ConverterArgs`.
- `Function`: function handle accepting one `context` argument, or `varargin`.

The registry validates descriptor shape, name/display-name uniqueness, placement policy, produced type, metadata schema shape, and function signature.

## Context

The runner calls:

```matlab
result = descriptor.Function(context);
```

The context is a scalar struct:

```matlab
context.Config        % NwbFileConfiguration
context.DataItem      % NwbDataItemConfig
context.Descriptor    % NwbConverterDescriptor
context.NwbFile       % current NwbFile, or [] for some external writers
context.FilePath      % target NWB file path
context.Data          % loaded data variable when descriptor.NeedsData is true
context.Metadata      % per-item metadata
context.ConverterArgs % descriptor defaults merged with item overrides
context.Placement     % configured/default placement
```

Converters should read from `context` and return a result. They should not load NANSEN data directly; the runner uses its `DataResolver` when `NeedsData` is true.

## Results

MatNWB mutating converters can return the mutated file directly:

```matlab
function nwbFile = convertExample(context)
    nwbFile = context.NwbFile;
    % mutate nwbFile
end
```

or:

```matlab
result = struct("NwbFile", nwbFile);
```

Converters can also return an NWB object for the runner to place:

```matlab
result = struct("NeuroData", timeSeries);
```

or:

```matlab
result = struct("NwbObject", timeSeries);
```

External writers must return:

```matlab
result = struct("DidWriteFile", true);
```

They may also include `FilePath`, but the runner only requires `DidWriteFile=true`.

## Placement Policy

By default, placement is config-owned. The runner passes:

```matlab
context.Placement.Name
context.Placement.PrimaryGroup
context.Placement.NwbModule
```

If a converter returns `NeuroData` or `NwbObject`, the runner places it according to `context.Placement`.

Converters may return:

```matlab
result.PlacementOverride = struct( ...
    "Name", "CustomName", ...
    "PrimaryGroup", "Processing", ...
    "NwbModule", "ophys");
```

The override is honored only when the descriptor sets:

```matlab
"AllowsPlacementOverride", true
```

Otherwise the override is ignored and config placement remains authoritative.

NeuroConv-backed converters are converter-owned because NeuroConv controls placement internally.

## SourceInfo Matching

The registry matches converters using `SourceInfo` before loading data. Supported evidence fields are:

```matlab
SourceInfo.DataType
SourceInfo.ClassName
SourceInfo.Format
SourceInfo.SourceFormat
SourceInfo.Modality
SourceInfo.FileExtension
SourceInfo.Path
SourceInfo.FilePath
```

`Path` and `FilePath` contribute their file extension to matching. Matching is case-insensitive and ignores dots, so `.tif`, `tif`, and `TIF` match the same accepted type.

Example:

```matlab
sourceInfo = struct("FileExtension", ".tif");
descriptors = registry.findBySourceInfo(sourceInfo);
```

## Custom Converter Example

```matlab
function result = myTimetableConverter(varargin)
    if nargin > 0 && string(varargin{1}) == "descriptor"
        result = nansen.module.nwb.conversion.NwbConverterDescriptor( ...
            "Name", "MyTimetableConverter", ...
            "Source", "custom", ...
            "Description", "Write timetable data as TimeSeries.", ...
            "AcceptedTypes", ["timetable", "matlab.timetable"], ...
            "ProducesNwbType", "TimeSeries", ...
            "PrimaryGroup", "Acquisition", ...
            "Function", @myTimetableConverter);
        return
    end

    context = varargin{1};
    result = nansen.module.nwb.conversion.builtin.convertTimetableToTimeSeries(context);
end
```

Register the folder containing the converter:

```matlab
nansen.module.nwb.registerConverterFolder("/path/to/converters")
```

## External Writer Example

Use `ExecutionMode="external"` for converters that write or append directly to the NWB file:

```matlab
descriptor = nansen.module.nwb.conversion.NwbConverterDescriptor( ...
    "Name", "MyExternalWriter", ...
    "Source", "custom", ...
    "AcceptedTypes", "external-file", ...
    "ProducesNwbType", "*", ...
    "ExecutionMode", "external", ...
    "PlacementPolicy", "converter", ...
    "NeedsData", false, ...
    "Function", @myExternalWriter);
```

```matlab
function result = myExternalWriter(context)
    % Write or append to context.FilePath.
    result = struct("DidWriteFile", true, "FilePath", context.FilePath);
end
```

