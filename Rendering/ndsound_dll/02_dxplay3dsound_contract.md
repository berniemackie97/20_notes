# `_DXPlay3DSound@32` Contract (Verified)

## Export + core implementation

- Export: `_DXPlay3DSound@32` (`0x1000870D`)
- Core function: `NdSoundEngine_Play3dSound` (`0x1000669E`)

## Verified argument semantics

`_DXPlay3DSound@32(soundPath, emitterX, emitterY, emitterZ, distanceRange, playbackModeSelector, streamBlockIndex, lifetimeSeconds)`

- `soundPath`:
  - required, non-empty, not `" "`
- `emitterX`, `emitterY`, `emitterZ`:
  - stored on the 3D instance as emitter coordinates (`+0xA0/+0xA4/+0xA8`)
- `distanceRange`:
  - passed into `NdSound3dInstance_ApplyDistanceRange`
  - used as the float value applied to the 3D distance-range parameter block
- `playbackModeSelector`:
  - passed through to `NdSound3dInstance_SetPlaybackModeSelector`
  - exact downstream COM semantic is not yet fully named
- `streamBlockIndex`:
  - converted to stream byte offset by `streamBlockIndex * 0x898`
  - bounds-checked against stream length
- `lifetimeSeconds`:
  - wrapper truncates to `uint16` (`mov ax, [arg8]`)
  - used as expiry timestamp: `timeGetTime() + (uint16)lifetimeSeconds * 1000`

## Verified behavior

1. Validate engine init + `soundPath`.
2. Search existing 3D instances by `soundPath`; on hit, update emitter XYZ and selector value.
3. On miss, allocate a 3D instance and initialize:
  - create internal 3D playback pipeline,
  - open stream by path,
  - apply selector,
  - seek by computed block offset,
  - prime playback buffer,
  - store expiry tick from truncated `lifetimeSeconds`.

## `_DXSet3DSoundPos@16` linkage

- Export: `_DXSet3DSoundPos@16` (`0x1000908E`)
- Behavior:
  - takes `(soundHandle, emitterX, emitterY, emitterZ)`,
  - finds matching active 3D instance by handle,
  - updates emitter coordinates via `NdSound3dInstance_SetEmitterPosition`.

## Per-frame 3D update linkage

`_DXProcessSound@8` -> `NdSoundEngine_ProcessFrame` updates 3D instances by:

- listener-relative position refresh (`NdSound3dInstance_UpdateRelativePositionFromListener`),
- periodic cleanup / stale counter advance,
- expiry-based close using stored lifetime tick.
