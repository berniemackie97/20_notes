# `_DXGet*` / `_DXCloseSound` / `_DXSetVolume` Contracts (Verified)

## Export + core mapping

- `_DXGetSound@12` (`0x10008CC1`) -> `NdSoundEngine_Find2dSoundByPathAndEmitter`
- `_DXGet3DSound@12` (`0x10008DBA`) -> `NdSoundEngine_Find3dSoundByPathAndEmitter`
- `_DXCloseSound@12` (`0x100089FD`) -> `NdSoundEngine_Close2dSoundByPathAndEmitter`
- `_DXSetVolume@16` (`0x10009267`) -> `NdSoundEngine_SetSoundVolumeByPathAndEmitter`

## `_DXGetSound@12` (2D/positional lookup)

`_DXGetSound@12(soundPath, emitterX, emitterY)`

Verified matching behavior:

1. Engine must be initialized (`engine+0x1c != 0`).
2. Iterate active 2D sound vector.
3. Require `strcmp(instancePath, soundPath) == 0` (case-sensitive).
4. If `emitterX == 0 && emitterY == 0`: accept path-only match (first match wins).
5. Otherwise require:
  - positional flag bit (`instanceFlags & 0x8`) set,
  - `instanceEmitterX == emitterX`,
  - `instanceEmitterY == emitterY`.
6. Return matched sound handle pointer; return `0` on miss.

## `_DXGet3DSound@12` (3D lookup)

`_DXGet3DSound@12(soundPath, emitterX, emitterY)`

Verified matching behavior:

1. Engine must be initialized.
2. Iterate active 3D sound vector.
3. Require `strcmp(instancePath, soundPath) == 0` (case-sensitive).
4. Require `(emitterX != 0 || emitterY != 0)`; zero/zero queries do not match.
5. Require exact emitter coordinate match:
  - `NdSound3dInstance_GetEmitterX(instance) == emitterX`
  - `NdSound3dInstance_GetEmitterY(instance) == emitterY`
6. Return matched 3D handle pointer; return `0` on miss.

## `_DXCloseSound@12` (2D close by key)

`_DXCloseSound@12(soundPath, emitterX, emitterY)`

Behavior:

- Uses same keying/match rules as `_DXGetSound@12`.
- On match:
  - stops buffer,
  - releases/removes instance from the 2D sound vector,
  - returns `1`.
- Returns `0` when no matching instance is found.

Note:
- This export closes only 2D/positional entries.
- 3D close APIs are separate (`_DXClose3DSound@4` by handle; internal path+emitter helper is `NdSoundEngine_Close3dSoundByPathAndEmitter`).

## `_DXSetVolume@16` (per-sound self-volume update)

`_DXSetVolume@16(soundPath, selfVolumePercent, emitterX, emitterY)`

Behavior:

1. Engine must be initialized.
2. Find matching 2D/positional sound using same keying rules as `_DXGetSound@12`.
3. Update instance self volume (`NdSound2dInstance_SetSelfVolumePercent`).
4. Reapply composite volume using current engine global sound volume:
  - `NdSound2dInstance_ApplyCompositeVolume(instance, engineGlobalSoundPercent)`.

Matching specifics:

- If `emitterX == 0 && emitterY == 0`, lookup is path-only.
- Otherwise requires positional flag + exact emitter XY.

Return semantics:

- Returns the `NdSound2dInstance_ApplyCompositeVolume` result for the first match.
- If no match (or engine not initialized), returns without applying updates.
