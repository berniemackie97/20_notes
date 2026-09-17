# `_DXSoundinit@4` / `_DXDestroy@0` / `_DXCloseAllSound@0` Contract

## Export -> engine mapping

- `_DXSoundinit@4` (`0x10008527`) -> `NdSoundEngine_Initialize` (`0x10004E40`)
- `_DXDestroy@0` (`0x100095AD`) -> singleton release and null-reset path
- `_DXCloseAllSound@0` (`0x10009675`) -> `NdSoundEngine_CloseAllSound` (`0x10006FCE`)

Wrapper SEH helpers:

- `EhHandler_DXSoundInit` (`0x1000D230`)
- `EhHandler_DXDestroy` (`0x1000D2F8`)
- `EhHandler_DXCloseAllSound` (`0x1000D302`)
- `EhHandler_NdSoundEngine_CloseAllSound` (`0x1000D207`)

## `_DXSoundinit@4`

`_DXSoundinit@4(windowHandle)`

Verified behavior:

1. If `g_NdSoundEngineSingleton` is null:
   - allocates `0xC0` bytes,
   - constructs with `NdSoundEngine_Create`.
2. Calls `NdSoundEngine_Initialize(g_NdSoundEngineSingleton, windowHandle)` on every invocation.
3. Returns `NdSoundEngine_Initialize` result unchanged.

No wrapper null guard exists before calling `NdSoundEngine_Initialize`; idempotence is enforced inside `NdSoundEngine_Initialize` by the initialized flag.

## `NdSoundEngine_Initialize`

Verified flow:

1. Early success gate:
   - when `engine+0x1C != 0`, returns `0` immediately.
2. Stores runtime settings:
   - `engine+0xBC = windowHandle`,
   - `engine+0x10 = 0x50` (music default volume),
   - `engine+0x14 = 0x50` (sound default volume).
3. Calls `CoInitialize(NULL)`.
4. Calls `NdDirectSound_CreateDeviceAndPrimaryBuffer(engine+4, windowHandle, 1, 2, 22050, 16)`.
5. Result handling:
   - `0`: sets `engine+0x1C = 1`, returns `0`.
   - `-1`, `-2`, `-3`: sets `engine+0x1C = 0`, returns same code.
   - any other value: returns `-1`.

This makes `_DXSoundinit@4` effectively idempotent once initialized.

## DirectSound bootstrap helpers

### `NdDirectSound_CreateDeviceAndPrimaryBuffer`

Verified semantics:

1. Releases existing DirectSound interface pointer when present.
2. Calls `DirectSoundCreate` (imported as `Ordinal_DSOUND_11`).
3. Calls DirectSound `SetCooperativeLevel(windowHandle, cooperativeLevel)`.
4. Configures primary buffer format via `NdDirectSound_ConfigurePrimaryBufferWaveFormat`.

Verified return codes:

- `0`: success
- `-1`: DirectSound create failed
- `-2`: cooperative-level setup failed

### `NdDirectSound_ConfigurePrimaryBufferWaveFormat`

Verified semantics:

1. Creates primary DirectSound buffer (`DSBUFFERDESC.dwFlags = 0x1`).
2. Builds PCM `WAVEFORMATEX` from:
   - channel count,
   - sample rate,
   - bits per sample.
3. Computes:
   - block align,
   - average bytes per second.
4. Applies format using primary-buffer vtable slot `0x38`.
5. Releases temporary primary-buffer interface in both success and failure branches.

Verified return codes:

- `0`: success
- `-3`: primary buffer creation or format application failed

## `_DXDestroy@0`

Verified behavior:

1. If `g_NdSoundEngineSingleton` is non-null, calls virtual slot `0` with argument `1` (owner-release path).
2. Clears `g_NdSoundEngineSingleton` to null.
3. Returns the release call result; returns `0` when singleton was already null.

## `_DXCloseAllSound@0`

Verified behavior:

1. Directly calls `NdSoundEngine_CloseAllSound(g_NdSoundEngineSingleton)`.
2. Wrapper has no singleton null guard.

`NdSoundEngine_CloseAllSound` iterates 3D instances then 2D instances, requests stop/refresh where applicable, releases each instance, zeroes vector slots, and clears both vectors.

## Contract helpers in managed code

Verified lifecycle constants and result normalization above are mirrored in:

- `LegacyDxSoundEngineLifecycleContract`
- `SoundEngineInitializeRequest`
- `SoundEngineLifecycleRequest`
