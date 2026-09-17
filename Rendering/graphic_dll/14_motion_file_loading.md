# `graphic.dll` — Motion file loading (`C3MotionTracker_InitFromMotionFile`)

How the client loads a motion container from a motion file or resource stream.

The motion container is created via `MotionCreate(...)` and initialized by a vtable method that parses the file and loads one or more `C3Motion` records.

## Entry points

- `MotionCreate` (`0x10004FB0`) → allocates a `C3MotionTracker` and calls `C3MotionTracker_InitFromMotionFile(...)` (vtable offset `+0x04`).
- `C3MotionTracker_InitFromMotionFile` (`0x10004AD0`) → opens and parses the motion file, then returns success/failure.
- `EhHandler_MotionCreate` (`0x10037900`) → SEH helper for `MotionCreate`.

## File open + size limit gate

`C3MotionTracker_InitFromMotionFile` opens the resource identified by `path` via `Common_OpenRes(path, &size, 1)`.

In the stock pipeline this `path` is typically the same `.c3` resource used for the mesh itself; the loader scans that resource for motion (`MOTI`) chunks and loads them.

If `Common_OpenRes` fails, initialization fails immediately.

Before parsing, it calls methods on `g_ResLimitInterfacePtr` to validate the motion file's byte size against the client's resource limits:

- vtable slot `+0x00` (method index `0`) -> file-size gate (`category 0` in `GraphicData.dll` policy)

- if the size check fails, it logs:
  - `C3 Motion [%s] with [%d] file size beyond ResLimit.`
- and returns failure.

## Chunk loop (`MOTI`)

After opening the stream, it loops over chunks until EOF or until 16 motions have been loaded:

1. Reads a chunk header via `Common_GetChunk(stream, &hdr)`.
2. If `hdr.magic != "MOTI"`:
   - seeks forward by the chunk payload size (`Common_SeekRes(stream, hdr.size, 1)`),
   - continues scanning.
3. If `hdr.magic == "MOTI"`:
   - calls `C3Motion_LoadFromStream(&this->motions[count], stream)` in `c3_core_dll.dll`.
   - if `C3Motion_LoadFromStream` fails, exits chunk scan immediately (`je 0x10004C6A`).
   - after scan exit, success is still decided by `motionCount > 0` plus per-motion ResLimit checks.
   - otherwise increments `count`.

The motion tracker stores:
- `this->motionCount` at `this[1]` (dword at offset `+0x04`)
- `this->motions[i]` pointers in a fixed array at `this + 0x08` (16 slots).

Initialization succeeds only if at least one motion was loaded (`motionCount > 0`).
This success gate is returned as a boolean-like integer (`1` when `motionCount > 0`, otherwise `0`).

Practical implication:
- failed decode of the first MOTI chunk => init fails (`motionCount == 0`)
- failed decode after at least one loaded chunk => later MOTI chunks are not scanned, but init can still succeed
  if loaded motions pass post-load limits.

## Optional per-motion name hash

When the `enableNameHash` flag (the second parameter to `MotionCreate`, forwarded into `C3MotionTracker_InitFromMotionFile`) is non-zero:

After each successful `Motion_Load`, the loader computes:

1. `buf = sprintf("%s%d", path, motionIndex)`
2. `hash = ComputeCaseInsensitiveHashMaskIndex(buf, 0)` (`0x10012F30`)
3. stores `hash` at offset `+0x1C` within the loaded `C3Motion` object.

`ComputeCaseInsensitiveHashMaskIndex` calls `ComputeCaseInsensitiveHashValue` (`0x10012ED0`), which uppercases characters (`toupper`) and mixes them with a fixed lookup table (`dword_100497A0`).

## Per-motion resource limit checks (bones + frames)

After closing the stream, `C3MotionTracker_InitFromMotionFile` iterates each loaded `C3Motion` and validates:

- bone count against the resource limit via vtable slot `+0x08` (method index `2`, `category 1` in `GraphicData.dll`; logs `... bones beyond ResLimit.` on failure)
- frame count against the resource limit via vtable slot `+0x04` (method index `1`, `category 2` in `GraphicData.dll`; logs `... frames beyond ResLimit.` on failure)

If any loaded motion violates the limits, initialization fails.

## Managed parser parity slice

`Conquer.Assets` now mirrors this verified chunk-loop behavior via:

- `C3MotionContainerReader`
- `C3MotionContainer`
- `MotionChunkDescriptor`

Current managed scope for this slice:

1. Skip 16-byte file header.
2. Scan 8-byte chunk headers (`magic[4] + size[4]`).
3. Collect only `MOTI` chunk payload descriptors (offset + length), skipping non-`MOTI` chunks by declared size.
4. Enforce bounds checks for malformed chunk sizes.
5. Preserve native max of 16 motion chunks per file.

Managed runtime parity for `C3DObjX` binding now additionally mirrors native tracker load semantics:

- decode MOTI payloads in stream order,
- stop on first payload decode failure (do not continue to later MOTI chunks),
- keep dense tracker slots `[0 .. motionCount-1]` (no null hole slots),
- apply C3DObjX capacity guard with this loaded-motion count before PHY binding.

For verified `MOTI` payload decode formats (`KKEY` / `ZKEY` / `XKEY` / fallback),
see:

- `../c3_core_dll/12_motion_load_formats.md`
