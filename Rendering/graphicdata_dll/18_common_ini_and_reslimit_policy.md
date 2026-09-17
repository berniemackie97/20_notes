# `GraphicData.dll` — `common.ini` tuning and resource-limit policy files

This document captures verified behavior for:

- `GameDataSet_LoadCommonIniTuning` (`0x10003790`)
- `GameDataSet_LoadResLimitDatabases` (`0x10029E80`)
- `GameDataSet_ApplyResLimitByLod` (`0x10029D40`)
- `ResLimitPolicy_IsValueAllowedForCategory` (`0x1002A2D0`)
- `IniFile_TryReadSectionInt32Value` (`0x1002D830`)

## Initialization order linkage

Within `GameDataSet_Initialize` (`0x10003190`), verified call order is:

1. `GameDataSet_LoadCommonIniTuning(this)` at `0x1000327E`
2. `SetResLimitInterface(this + 0x8)` at `0x1000328F`
3. `GameDataSet_LoadResLimitDatabases(this)` at `0x1000329A`

Return values of `GameDataSet_LoadCommonIniTuning` and `GameDataSet_LoadResLimitDatabases` are not checked by `GameDataSet_Initialize`; startup continues.

## `common.ini` loader semantics

`GameDataSet_LoadCommonIniTuning` chooses one memory-profile section based on `GlobalMemoryStatus().dwTotalPhys`:

- `< 0x0B71B000` -> section `"MEM128"`
- `< 0x17D78400` -> section `"MEM256"`
- otherwise -> section `"MEM512"`

It reads from path literal `ini/common.ini` using `IniFile_TryReadSectionInt32Value` and updates:

- `3DMotionLife` -> `this + 0x17C`
- `3DTextureLife` -> `this + 0x180`
- `3DEffectLife` -> `this + 0x184`
- `ReadThreadPriority` -> `this + 0x18C`

Default values are set earlier by `GameDataSet_Initialize`:

- `this + 0x178/+0x17C/+0x180/+0x184/+0x188` = `0x7530` (`30000`)
- `this + 0x18C` = `0`

`ReadThreadPriority` normalization:

- `-1` keeps `-1`
- `0` keeps `0`
- `1` keeps `1`
- any other parsed value maps to `0`

### INI integer read helper

`IniFile_TryReadSectionInt32Value`:

- opens file in text mode (`"r"`),
- scans tokens via `fscanf("%s\n", token)`,
- matches section token `[SectionName]` via `_stricmp`,
- builds key pattern with `sprintf("%s=%s\n", keyName, "%d")`,
- parses signed int via `sscanf(token, keyPattern, outValuePtr)`.

If key is missing:

- `logAsError != 0` -> error logger path
- `logAsError == 0` -> warning/info logger path

## Resource-limit interface shape

`GraphicData.dll` provides a vtable at `g_ResLimitInterfaceVtable` (`0x10030160`) and passes an object pointer (`this + 0x8`) to `graphic.dll` via `SetResLimitInterface`.

Verified wrapper slots:

- slot `0` -> `ResLimitPolicy_IsFileSizeAllowed` -> category index `0`
- slot `1` -> `ResLimitPolicy_IsFrameCountAllowed` -> category index `2`
- slot `2` -> `ResLimitPolicy_IsBoneCountAllowed` -> category index `1`
- slot `8` -> `ResLimitPolicy_IsPhyChunkCountAllowed` -> category index `8`

Other category wrappers exist for indices `3,4,5,6,7,9,10` but are not yet mapped to stable semantic names in this build.

## `ResLimit.dat` format (`ini/ResLimit.dat`)

`GameDataSet_LoadResLimitDatabases` reads this binary format:

```c
u32 version_a;          // must be 1000
u32 profile_count;
u32 version_b;          // must be 1000
repeat profile_count {
    i32 lod_level_key;
    i32 category_thresholds[11]; // 0x2C bytes
}
```

Per-profile threshold vectors are stored in the internal `lod_level -> threshold[11]` map rooted at `this + 0x3A8`.

## `ResLimitExclude.dat` format (`ini/ResLimitExclude.dat`)

`GameDataSet_LoadResLimitDatabases` reads:

```c
u32 version;            // must be 1000
u32 category_group_count;
repeat category_group_count {
    u32 category_index; // must be < 11
    u32 excluded_path_count;
    repeat excluded_path_count {
        u32 path_byte_length;
        char path[path_byte_length]; // not null-terminated on disk
    }
}
```

Each path is inserted into the category-specific string set array rooted at `this + 0x3BC` (11 buckets, stride `0x10` per bucket).

## Runtime allow/deny rule

`ResLimitPolicy_IsValueAllowedForCategory` implements:

1. if active threshold vector pointer (`this + 0x3A4`) is null -> allow.
2. if `value <= thresholds[category_index]` -> allow.
3. otherwise, allow only when `resourcePath` exists in that category's exclude set.
4. if not excluded -> deny.

`GameDataSet_ApplyResLimitByLod` selects the active threshold vector:

- exact lod hit -> applies selected profile
- miss -> attempts default profile (first map entry)
- if no default profile -> clears active thresholds (no limits applied)

## Real 5517 clean-client file presence note

In `00_clean/clean/5517/ini/`:

- `Common.ini` exists.
- `ResLimit.dat` and `ResLimitExclude.dat` are absent.

This matches the tolerant startup behavior (loader failure does not abort `GameDataSet_Initialize`).
