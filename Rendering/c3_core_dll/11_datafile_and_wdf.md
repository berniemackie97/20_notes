# DataFile System and WDF Archive Format

The C3 engine uses a 3-layer resource I/O architecture to load assets from proprietary `.wdf` archive files.

## Architecture Overview

```
Layer 3 - c3_core_dll.dll   DataFile_* / Common_*     thin wrappers (exported API)
Layer 2 - c3_core_dll.dll   function-pointer table     indirect calls to TqPackage
Layer 1 - TqPackageWdf.dll  TqPackages* / TqF*         actual archive I/O implementation
```

### Registration Flow (re-verified 2026-09-02, Binary Ninja)

`conquer.exe` does **not** read `ini/package.ini` — it contains no `package.ini` and no `.wdf`
string. The startup registration driver lives in `GraphicData.dll`:

| Site | Symbol | Verified behavior |
|---|---|---|
| `conquer.exe 0x5AA87C` | `(*GameDataSetQuery()->vtbl[0])()` | slot `+0x00` of `g_IGameDataSet_BaseVtbl` (`GraphicData.dll 0x10030190`) holds `0x10003190` |
| `GraphicData.dll 0x10003190` | `GameDataSet_Initialize` | `CGameDataSet::Init` |
| `GraphicData.dll 0x10003277` | `call GraphicData_OpenPackagesFromPackageIni` | package registration happens here, immediately after `GameDbPack_LoadAndUpdateC3Wdb` |
| `GraphicData.dll 0x1001A390` | `GraphicData_OpenPackagesFromPackageIni` | the `ini/package.ini` reader |
| `conquer.exe 0x5AA8A3` | `(*GameDataSetQuery()->vtbl[+0x98])()` | `GameDataSet_IsInitialized` (`0x10009FE0`, vtable entry at `0x10030228`); zero -> `"CGameDataSet Init Fail"` message box and `PostQuitMessage(0)` at `0x5AA989`, `InitInstance` returns `FALSE` |

Package registration cannot influence that fatal gate: `GraphicData_OpenPackagesFromPackageIni`
returns void, and `GameDataSet_Initialize` neither checks it nor records anything from it.

`GraphicData_OpenPackagesFromPackageIni` (`0x1001A390`), exact:

| Site | Instruction | Verified behavior |
|---|---|---|
| `0x1001A3A1` | `fopen("ini/package.ini", "r")` | text mode, relative to process CWD |
| `0x1001A3AE` -> `0x1001A3B0` | `jne` / log path | on `NULL` logs `"open file ini/package.ini failed."` (`0x1002DC30`) and **returns** — non-fatal, zero packages registered |
| `0x1001A3F7` | `fscanf(stream, "%s\n", buf)` | whitespace-delimited tokens into a `0x400`-byte stack buffer; **not** an INI section/key parse |
| `0x1001A3FC` | `cmp eax, -1` | loop terminates on `EOF` only |
| `0x1001A406` | `call TqPackagesOpen(buf)` | **return value is discarded** — a failed package is tolerated |
| `0x1001A40E` | `fclose` | — |

`TqPackagesOpen` (`TqPackageWdf.dll 0x10003D30`), exact:

| Site | Instruction | Verified behavior |
|---|---|---|
| `0x10003D5D` | `WdfHash_NormalizePath(buf, arg1)` | lowercase ASCII `A-Z`, `\` -> `/` |
| `0x10003D86` | `strrchr(buf, '.')` | **last** `.`, not the first |
| `0x10003DB4` | `strncpy(prefix, buf, dotIndex)` | prefix = normalized name with the final extension stripped; guarded by `dotIndex < 0x104` (`0x10003DA4`) |
| `0x10003DC6` | copy loop | when there is **no** `.`, the whole normalized name becomes the prefix |
| `0x10003DE1` | `sub_10003CD0(WdfHash_Core(prefix))` | linear scan of the registered-package vector (`data_1000C168`..`data_1000C16C`) comparing `pkg->prefixHash` at `+4` |
| `0x10003DEF` | `jne` | **duplicate prefix -> returns immediately without registering.** First registration wins; no error, no replacement |
| `0x10003E0C` | `operator new(0x44)` + `sub_10001000` | package object |
| `0x10003E4B` | `sub_100014F0(pkg, normalizedName)` | stores prefix hash at `pkg+4` (`0x10001616`) and calls handler `vtable+0x0C` = open (`0x10001620`) |
| `0x10003F5C` | `mov result, 0` | `TqPackagesOpen` returns `0` on **every** path |

`sub_100014F0` **ignores the handler's open result** (`0x10001620` discards the return value and the
function falls through to `return 0` at `0x1000162F`). Consequence for `data3.wdf`, which is listed
in retail `ini/package.ini` but not shipped: `WdfHandler_OpenFile` (`0x10002C50`) returns `4` at
`0x10002D20` because `fopen` fails, but the package object is still registered under prefix
`data3` with a zero-entry index. Every later `data3/...` lookup therefore routes to that package
and misses. **Missing packages are non-fatal and do not abort startup.**

### File Lookup Flow (re-verified 2026-09-02)

1. Caller uses `Common_OpenRes("c3/mesh/file.c3", &size, 1)` or `DataFile_Load("c3/0003/560/130.C3", &data, &size)`
2. Path is normalized — `WdfHash_NormalizePath` (`0x10009890`): lowercase ASCII `A-Z`, `\` -> `/`, everything
   else byte-for-byte. No `.`/`..`/empty-segment collapsing, no length rejection.
3. Package selection: `sub_10003C80` (`0x10003C80`) -> `sub_10003C30` (`0x10003C30`) copies characters
   **up to the first `/`** (lowercasing as it goes) and `WdfHash_Core`s that. So the routing key is the
   **first path segment**, matched against the package base name with its extension stripped:
   `data/...` -> `data.wdf`, `c3/...` -> `c3.wdf`, `data3/...` -> `data3.wdf`.
   A path with no `/` hashes the whole string; an empty path yields hash `0` (`0x10003CB0`).
4. `sub_10003CD0` (`0x10003CD0`) linearly scans the registered-package vector and returns the **first**
   package whose `+4` prefix hash matches, else `NULL`.
5. Full normalized path hashed via `WdfHash_NormalizeAndHash` (`0x100099D0`) -> `WdfEntryTree_BinarySearch`
   (`0x10003A10`) inside `WdfHandler_Search` (`0x10002BD0`). Note the entry UID is the hash of the
   **whole** virtual path including its `data/` or `c3/` prefix.
6. Precedence is **per-entry-point, not global** — see "Fallback Behavior" below. `TqFDump`/`TqFCheck(mode 0)`
   are loose-file-first; `TqFOpen` is package-only.

## Layer 3: c3_core_dll Exported API

### DataFile Functions

| Function | Address | Wraps | Description |
|----------|---------|-------|-------------|
| `DataFile_Open(path)` | `0x10001CE0` | `TqPackagesOpen(path)` | Register a WDF archive |
| `DataFile_Close()` | `0x10001CF0` | `TqPackagesClose(nullptr)` | Close all packages |
| `DataFile_Load(path, &data, &size)` | `0x10001D60` | `TqFDump(path, &data, &size)` | Load entire file into malloc'd buffer |
| `DataFile_Free(&data)` | `0x10001D80` | `TqFUndump(data)` | Free buffer from DataFile_Load |
| `DataFileCheck(path)` | `0x10001D40` | `TqFCheck(path, 0)` | Check if file exists (loose first, then package) |
| `DataFile_UnpackSearch(path)` | `0x10001D00` | `TqFCheck(path, 1)` | Check if loose file exists |
| `DataFile_Search(path)` | `0x10001D20` | `TqFCheck(path, 2)` | Check if file exists in package only |

### Common Resource I/O Functions

| Function | Address | Wraps | Description |
|----------|---------|-------|-------------|
| `Common_OpenRes(path, &size, flag)` | `0x10001D90` | `TqFOpen` + `TqFGetLen` | Open resource, return handle + file size |
| `Common_CloseRes(handle)` | `0x10001DD0` | `TqFClose` | Close resource handle |
| `Common_ReadRes(handle, buf, count)` | `0x10001E00` | `TQFRead(buf, 1, count, handle)` | Read bytes from resource |
| `Common_SeekRes(handle, offset, mode)` | `0x10001E20` | `TqFSeek` | Seek within resource |
| `Common_GetSeek(handle)` | `0x10001E60` | `TqFTell` | Get current position |
| `Common_GetChunk(handle, &header)` | `0x10001DE0` | `TQFRead(&header, 1, 8, handle)` | Read 8-byte chunk header |
| `Common_IsEofRes(handle)` | `0x10001E40` | `TqFIsEof` | Check EOF |

## Layer 2: Function Pointer Table (c3_core_dll)

The TqPackage functions are loaded at runtime from `TqPackageWdf.dll` via delay-load imports. The function pointers are stored in the `.data` section:

| Pointer Address | Target Symbol | Demangled |
|-----------------|---------------|-----------|
| `0x100A1170` | `TqPackagesOpen` | `TQPRESULT(const char*)` |
| `0x100A1174` | `TqPackagesClose` | `void(const char*)` |
| `0x100A1178` | `TqFCheck` | `bool(const char*, FILETYPE)` |
| `0x100A117C` | `TqFDump` | `TQPRESULT(const char*, void*&, unsigned long&)` |
| `0x100A1180` | `TqFUndump` | `TQPRESULT(void*)` |
| `0x100A1184` | `TqFGetLen` | `long(void*)` |
| `0x100A1188` | `TqFOpen` | `TQPRESULT(const char*, void*&)` |
| `0x100A118C` | `TqFClose` | `TQPRESULT(void*)` |
| `0x100A1190` | `TQFRead` | `long(void*, unsigned long, unsigned long, void*)` |
| `0x100A1194` | `TqFSeek` | `bool(void*, long, TQSEEKMODE)` |
| `0x100A1198` | `TqFIsEof` | `bool(void*)` |
| `0x100A119C` | `TqFTell` | `unsigned long(void*)` |

### TqPackage FILETYPE Mapping (verified in `TqPackage.dll`, 2026-02-27)

`TqFCheck(path, mode)` dispatches by mode:

- `0`: both (checks loose path first, then package)
- `1`: loose file only
- `2`: package only

This matches C3 wrappers:

- `DataFileCheck(path)` -> mode `0`
- `DataFile_UnpackSearch(path)` -> mode `1`
- `DataFile_Search(path)` -> mode `2`

## Layer 1: TqPackageWdf.dll Implementation

### WDF File Format (verified via Binja + hex dump 2026-02-27)

```
File Layout:
  Offset    Size              Description
  ------    ----              -----------
  0x00      4                 Magic: "PFDW" (0x50, 0x46, 0x44, 0x57)
  0x04      4                 Entry count (uint32 LE)
  0x08      4                 Entry table offset (uint32 LE) — points near end of file
  0x0C      (table_offset-12) Packed file data (contiguous, no per-file headers)
  table_offset  count×16      Entry table (sorted by UID ascending)
```

### Entry Format (16 bytes)

```c
struct WdfEntry {
    uint32_t uid;       // Hash of normalized file path (sorted ascending for binary search)
    uint32_t offset;    // Absolute byte offset of file data within the WDF
    uint32_t size;      // Size of file data in bytes
    uint32_t reserved;  // Always 0
};
```

### Known WDF Files

| File | Entries | Size | Contents |
|------|---------|------|----------|
| `c3.wdf` | 10,274 | 359 MB | C3 meshes (MAXFILE), DDS textures (5,747), motion data |
| `data.wdf` | 14,739 | 392 MB | Bitmap icons, sprites, UI assets |
| `data3.wdf` | — | Missing from disk | Listed in `package.ini` but not shipped. Still registered under prefix `data3` with an empty index (`sub_100014F0` discards `WdfHandler_OpenFile`'s `4`); non-fatal |

### File Signatures Inside WDF

| Signature | Type | Description |
|-----------|------|-------------|
| `MAXFILE C3 00001` | C3 mesh/motion | 16-byte header followed by PHY or MOTI chunks |
| `DDS ` | DDS texture | DirectDraw Surface texture |
| `BM` | BMP | Bitmap image |

### Path Normalization (`WdfHash_NormalizeAndHash` in TqPackageWdf.dll)

Before hashing, file paths are normalized:
1. Uppercase ASCII letters (A-Z, 0x41-0x5A) are converted to lowercase (+0x20)
2. Backslash `\` (0x5C) is replaced with forward slash `/` (0x2F)
3. All other characters are preserved

Example: `C3\Mesh\File.C3` -> `c3/mesh/file.c3`

### UID Hash Function (`WdfHash_Core` in TqPackageWdf.dll)

Implementation note (verified at `0x100098F9`/`0x100099BC`): `WdfHash_Core` is **not** reentrant —
it `strncpy`s the input into a single process-global 256-byte buffer (`data_1000C188`) under a
critical section (`data_1000C2A0`) and writes the two sentinel dwords into that same buffer.
`strncpy` with `n = 0x100` zero-pads, which is what makes the "count non-zero dwords" step
(`0x10009921`, capped at `0x40`) well defined. Paths of 256 bytes or longer are silently truncated.

The hash function operates on the normalized path string treated as a sequence of little-endian uint32 dwords:

```
Input:  Normalized path string in a 256-byte zero-padded buffer
Output: 32-bit unsigned hash (UID)

Algorithm:
  1. Interpret buffer as 64 little-endian uint32 dwords
  2. Count non-zero dwords -> count
  3. Append two sentinel dwords at positions [count] and [count+1]:
     - dwords[count]   = 0x9BE74448
     - dwords[count+1] = 0x66F42C48
  4. Initialize state:
     - accum = 0xF4FA8928
     - esi   = 0x37A8470E
     - edi   = 0x7758B42B
  5. For each of (count + 2) dwords:
     a. accum = ROL32(accum, 1)
     b. ebx = 0x267B0B11 ^ accum
     c. esi ^= dword[i]
     d. edi ^= dword[i]
     e. mult1 = ((ebx + edi) | 0x02040801) & 0xBFEF7FDF
        product = esi × mult1 (64-bit unsigned)
        lo = product[31:0], hi = product[63:32]
        cf = (hi != 0) ? 1 : 0
        sum = lo + hi + cf
        cf2 = (sum > 0xFFFFFFFF) ? 1 : 0
        esi_new = (sum & 0xFFFFFFFF) + cf2
     f. mult2 = ((ebx + esi_old) | 0x00804021) & 0x7DFEFBFF
        product = edi × mult2 (64-bit unsigned)
        lo = product[31:0], hi = product[63:32]
        hi2 = hi × 2
        cf_add = (hi2 > 0xFFFFFFFF) ? 1 : 0
        hi2 &= 0xFFFFFFFF
        sum = lo + hi2 + cf_add
        cf3 = (sum > 0xFFFFFFFF) ? 1 : 0
        sum &= 0xFFFFFFFF
        if cf3: sum += 2
        edi_new = sum
     g. esi = esi_new, edi = edi_new
  6. Return esi ^ edi
```

**Critical detail:** In step 5f, `esi_old` is the value of esi AFTER the XOR in step 5c but BEFORE the multiply update in step 5e. The `mov esi, eax` that stores esi_new happens between the two multiplies (at `0x1000999B`).

### Verified Hash Examples

| Path | UID |
|------|-----|
| `c3/0003/560/130.C3` | `0x048AEF45` |
| `c3/0003/611/130.C3` | `0x35302C75` |
| `c3/0003/741/130.C3` | `0xDE9758F1` |
| `c3/0003/500/130.C3` | `0xEE52708E` |
| `c3/0003/410/130.C3` | `0x050B1174` |

### TqPackageWdf.dll Key Functions

| Address | Name | Description |
|---------|------|-------------|
| `0x10003D30` | `TqPackagesOpen` | Opens WDF: extracts prefix, reads header+entries, registers package |
| `0x10004050` | `TqPackagesClose` | Closes package by prefix |
| `0x100042B0` | `TqFOpen` | Opens file: normalizes path, finds package, hashes path, searches entries |
| `0x10004320` | `TqFClose` | Closes file handle |
| `0x10004340` | `TQFRead` | Reads data: dispatches to `fread` or in-memory read |
| `0x10004380` | `TqFSeek` | Seeks within file |
| `0x100043B0` | `TqFTell` | Returns current position |
| `0x100043D0` | `TqFIsEof` | Checks if at end of file |
| `0x100043F0` | `TqFGetLen` | Returns file length |
| `0x10004220` | `TqFDump` | Loads entire file into malloc'd buffer |
| `0x10004290` | `TqFUndump` | Frees dumped buffer |
| `0x100041C0` | `TqFCheck` | Checks file existence (with FILETYPE: 0=both, 1=loose, 2=package) |
| `0x100098F0` | (hash core) | Core hash function — dword-based custom hash |
| `0x100099D0` | (normalize+hash) | Normalizes path + calls hash core |
| `0x10009890` | (normalize path) | Copies path with lowercase + backslash normalization |
| `0x10002860` | (WDF handler ctor) | Creates WDF-specific handler object (0x44C bytes, vtable at `0x1000A11C`) |
| `0x10002C50` | (WDF open file) | WDF vtable[3]: reads WDF header, entry table, builds sorted tree |
| `0x10002BD0` | (WDF search) | WDF vtable[1]: hashes path, binary searches entry tree |
| `0x10003A10` | (tree search) | Binary search in sorted entry tree by UID |

### WDF Handler Vtable (`0x1000A11C`)

| Index | Offset | Address | Purpose |
|-------|--------|---------|---------|
| 0 | +0x00 | `0x10002BC0` | Destructor |
| 1 | +0x04 | `0x10002BD0` | File search (hash + tree lookup) |
| 2 | +0x08 | `0x10003030` | (shared with index 6) |
| 3 | +0x0C | `0x10002C50` | Open/load WDF file (reads header + entries) |
| 4 | +0x10 | `0x10002E90` | Unknown |
| 5 | +0x14 | `0x10002F40` | Unknown |
| 6 | +0x18 | `0x10003030` | Unknown |
| 7 | +0x1C | `0x10003050` | Unknown |

### TQFRead Dispatch Logic (`TQFRead_DispatchRead`)

The read function dispatches based on the file handle's source type (field at offset +0x20):

| Type | Value | Behavior |
|------|-------|----------|
| Loose file | 1 | Calls `fread(buf, 1, count, file_handle)` directly |
| WDF entry | 2 | Reads from WDF via `WdfRead_AtEntryOffset` (seeks to entry offset + current position, reads from archive FILE*) |

### Fallback Behavior (re-verified 2026-09-02 — precedence is per-entry-point)

`TqFDump_Inner` (`0x10001AC0`, `arg5` = mode) implements the dump fallback chain:

| Mode | Site | Behavior |
|---|---|---|
| `1` | `0x10001B18` | loose file only (`TqFDump_LooseFile`, `0x10001BE0`) |
| `2` | `0x10001AFB` | package only (`TqFDump_Package`, `0x10001B60`) |
| `0` | `0x10001B2C`..`0x10001B46` | `TqFDump_LooseFile` first; return on `0` (success); return the error if it is **not** `3`; only on `3` (not found) fall through to `TqFDump_Package` |

`TqFDump` (`0x10004220`) always passes mode `0` (`0x10004273`), so whole-file loads are
**loose-file-first, WDF second** — this is what lets loose patch files override WDF contents.

`sub_10001640` (`0x10001640`) is the existence-check counterpart and takes the same mode:
mode `0` (`0x100016C8`) probes the loose file with `GetFileAttributesExA` and falls back to
`WdfHandler_Search` (handler `vtable+0x04`) when it is absent; mode `1` (`0x10001685`) is loose only;
mode `2` (`0x10001677`) is package only.

**Correction to prior notes:** `Common_OpenRes` does **not** use the fallback mode.
`TqFOpen` (`0x100042B0`) -> `sub_10001720` (`0x10001720`) hardcodes `push 0x2` at `0x10001747`
before calling `sub_10001640`, and stamps the handle's source type as `2` at `0x1000180B`
(`mov dword [ebp+0x20], 2`). **Streaming opens are package-only and never fall back to a loose file.**
`TqFOpen` returns `3` when the prefix has no registered package (`0x100042FA`) and `3` when the
entry is absent from that package (`0x10001752`).

Practical consequence for parity: a loose file on disk overrides the WDF for `DataFile_Load` /
`DataFileCheck`, but **not** for `Common_OpenRes`-style streaming reads, which see WDF content only.

### TQPRESULT values observed

| Value | Meaning | Evidence |
|---|---|---|
| `0` | success | `0x1000186B`, `0x10001C9F`, `0x10002E18` |
| `1` | invalid argument (null/empty path, bad mode) | `0x10004317`, `0x1000428B`, `0x10001ADE` |
| `3` | not found (no package for prefix, or entry absent) | `0x1000430B`, `0x10001752`, `0x10001C1E` |
| `4` | could not open the underlying file | `0x10001C46`, `0x10002D20` |
| `5` | short/failed read | `0x10001C87`, `0x10002D49`, `0x10002DC2` |
| `0x11` | out of memory (entry table alloc) | `0x10002D79` |

## Configuration

### `ini/package.ini`

Retail 5517 content:
```
data.wdf
c3.wdf
data3.wdf
```

Parsing is `fscanf(stream, "%s\n", buf)` in a loop (`GraphicData.dll 0x1001A3F7`), i.e.
**whitespace-delimited tokens**, not lines and not INI sections/keys. Two names on one line would
register as two packages. A missing file is non-fatal (logged, zero packages). `data3.wdf` is listed
but not shipped; it is still registered with an empty index (see Registration Flow above).

There is a second, unrelated `ini/package.ini` consumer inside `TqPackageWdf.dll` itself:
`PackUpdatedFiles` (`0x100059E0`, `fopen` at `0x10005A06`, same `fscanf("%s\n")` loop at
`0x10005D8D`). That is the **repacking/patcher** path driven by `./PackUpdate.ini`
(`[DontPackDir] DirCount/Dir%d`, `[DontPackFile] FileCount/File%d`), not the client's runtime
registration path. Do not conflate the two.

### `ini/c3.wdb`

Binary database (magic: `BDMG`) consumed by `GraphicData.dll` (`GameDbPack_LoadAndUpdateC3Wdb`) as an indexed pack of `.dbc` resources.  
It is separate from WDF and has its own header, hashed filename index, and encrypted `0x54`-byte entry descriptors.

See the dedicated RE doc for exact verified layout + decrypt/hash flow:  
`20_notes/Rendering/graphicdata_dll/11_c3_wdb_format_and_decode.md`

## Implementation Notes for Rewrite

For our cross-platform rewrite, we need:

1. **WDF Reader** — parse header + entry table, provide file-by-path lookup
2. **WDF Hash** — exact reimplementation of the hash function for UID computation
3. **Fallback logic** — loose files first, then WDF, for whole-file loads and existence checks
   (`TqFDump`/`TqFCheck` mode `0`). Note that native `TqFOpen` is package-only; a single unified
   loose-first content source is a deliberate simplification, not native streaming behavior.
4. **Path normalization** — lowercase ASCII `A-Z` + backslash-to-forward-slash, nothing else
5. **Prefix derivation** — strip from the **last** `.` of the normalized package name; whole name if
   there is no `.`
6. **Duplicate prefixes** — first registration wins, silently; not an error
7. **Missing package files** — tolerated; registered with an empty index; never fatal

The WDF format is simple enough that we don't need the full TqPackage abstraction layer. A single `WdfArchive` class can handle:
- Open archive file
- Parse 12-byte header
- Read entry table (count × 16 bytes at offset)
- Build Dictionary<uint, WdfEntry> for O(1) lookup
- Hash-based file lookup with `TryGetEntry(path, out entry)`
- Read file data with `ReadFile(entry)` returning `byte[]` or `ReadOnlyMemory<byte>`
