# `_DXClose*Sound` / `_DXSet*SoundPos` Contracts

## Export -> engine mappings

- `_DXClose2DSound@4` (`0x10008EB3`) -> `NdSoundEngine_Close2dSoundByHandle`
- `_DXClose3DSound@4` (`0x10008F9F`) -> `NdSoundEngine_Close3dSoundByHandle`
- `_DXSet2DSoundPos@12` (`0x10009180`) -> `NdSoundEngine_Set2dSoundPositionByHandle`
- `_DXSet3DSoundPos@16` (`0x1000908E`) -> `NdSoundEngine_Set3dSoundPositionByHandle`

## `_DXClose2DSound@4`

`_DXClose2DSound@4(soundHandle)`

Verified behavior:

1. Uses engine singleton and calls `NdSoundEngine_Close2dSoundByHandle`.
2. Core function requires engine init flag (`this+0x1c != 0`), otherwise returns `0`.
3. Iterates active 2D instance vector by `NdSound2dInstanceVector_GetCount`.
4. Match condition is exact handle pointer equality (`slot == soundHandle`).
5. On first match:
   - decrements/releases instance refcount,
   - clears slot and erases vector entry,
   - returns `1`.
6. Returns `0` when no match is found.

## `_DXClose3DSound@4`

`_DXClose3DSound@4(soundHandle)`

Verified behavior mirrors 2D close for the 3D active-instance vector:

1. Calls `NdSoundEngine_Close3dSoundByHandle`.
2. Requires engine init flag (`this+0x1c != 0`), else `0`.
3. Iterates 3D vector by `NdSound3dInstanceVector_GetCount`.
4. Uses exact handle pointer match.
5. On first match, releases/erases instance and returns `1`.
6. Returns `0` on miss.

## `_DXSet2DSoundPos@12`

`_DXSet2DSoundPos@12(soundHandle, emitterX, emitterY)`

Verified behavior:

1. Calls `NdSoundEngine_Set2dSoundPositionByHandle`.
2. Requires engine init flag to enter scan loop.
3. Iterates active 2D instances and matches by exact handle pointer.
4. On match, calls:
   - `NdSound2dInstance_SetEmitterAndRange(instance, emitterX, emitterY, instanceCurrentRange)`
   - range is preserved from existing instance state (`instance+0x1c`).

Return semantics (legacy quirk):

- Match path: returns setter result (`emitterY`).
- No-match path: returns current 2D vector count.
- Engine-not-initialized path: returns engine pointer (`this`).

Treat as side-effect API; callers should not rely on return value for success/failure.

## `_DXSet3DSoundPos@16`

`_DXSet3DSoundPos@16(soundHandle, emitterX, emitterY, emitterZ)`

Verified behavior:

1. Calls `NdSoundEngine_Set3dSoundPositionByHandle`.
2. Requires engine init flag to enter scan loop.
3. Iterates active 3D instances and matches by exact handle pointer.
4. On match, calls `NdSound3dInstance_SetEmitterPosition(instance, emitterX, emitterY, emitterZ)`.

Return semantics (legacy quirk):

- Match path: returns setter result (`emitterY`).
- No-match path: returns current 3D vector count.
- Engine-not-initialized path: returns engine pointer (`this`).

Treat as side-effect API; callers should not rely on return value for success/failure.
