# `_DXProcessSound@8` Contract

## Export -> engine mapping

- `_DXProcessSound@8` (`0x10008940`) -> `NdSoundEngine_ProcessFrame` (`0x10007366`)
- SEH helper in wrapper prologue: `EhHandler_DXProcessSound` (`0x1000D258`)

## `_DXProcessSound@8`

`_DXProcessSound@8(listenerX, listenerY)`

Verified wrapper behavior:

1. Forwards `listenerX` and `listenerY` unchanged to `NdSoundEngine_ProcessFrame(g_NdSoundEngineSingleton, listenerX, listenerY)`.
2. Returns the helper return value directly (legacy side-effect API; not a strict success/fail code).

## `NdSoundEngine_ProcessFrame` execution gate

Frame logic executes only when:

- engine init flag is set (`engine+0x1c != 0`), and
- mute/suspend gate is clear (`engine+0x18 == 0`).

Otherwise the function exits without running vector processing.

## Verified frame transitions

1. Listener coordinates:
   - stores `listenerX` -> `engine+0x24`,
   - stores `listenerY` -> `engine+0x28`.
2. Delayed volume-restore branch (see `_DXSaveMusicVolume@0` / `_DXFlushVolume@0`):
   - increments `engine+0x20` when non-zero,
   - finalizes when `(short)(engine+0x20) > 30`,
   - reapplies music/sound volumes and clears saved slots/counter.
3. Periodic global sound-volume reapply:
   - when delayed restore has not finalized, branch runs when `rand() % 5 == 0`,
   - calls `NdSoundEngine_SetSoundVolumePercent(engine, engine+0x14)`.
4. Media vector (`engine+0x2c`):
   - processes playback events per instance,
   - removes instance when event processing returns zero.
5. 3D vector (`engine+0x8c`):
   - updates relative position using `(listenerX, listenerY, 0)`,
   - refresh/aging counter at `instance+0x1b4` increments when non-zero,
   - disposal check uses pre-increment value: remove when previous counter `> 100`.
6. 2D vector (`engine+0x5c`):
   - positional attenuation/pan and effective volume are recomputed,
   - replay path decrements `instance+0xb0` when playback completes and replay budget remains,
   - restart gate: when `instance+0x24 == 0` and `instance+0xb0 != 0`, calls `NdSound2dInstance_StartFromCurrentSettings(instance)`,
   - aging counter at `instance+0x28` increments when non-zero,
   - disposal check uses pre-increment value: remove when previous counter `> 100`.

## Contract helpers in managed code

The verified thresholds and gates above are mirrored in:

- `LegacyDxVolumeLifecycleContract` (delayed restore finalize threshold `30`),
- `LegacyDxPauseContinueContract` (aging threshold `100`, restart gate),
- `LegacyDxProcessSoundContract` (frame execution gate + periodic sound-volume refresh modulo `5`).
