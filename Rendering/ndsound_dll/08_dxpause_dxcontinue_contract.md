# `_DXPause@0` / `_DXContinue@0` Contracts (Verified)

## Export -> engine mappings

- `_DXPause@0` (`0x10008BDF`) -> `NdSoundEngine_PauseAllSound` (`0x1000529A`)
- `_DXContinue@0` (`0x10008C50`) -> `NdSoundEngine_ResumeAllSound` (`0x100053A8`)

---

## `_DXPause@0`

`_DXPause@0()`

Verified behavior in `NdSoundEngine_PauseAllSound`:

1. Requires initialized engine (`engine+0x1c != 0`) or returns immediately.
2. Iterates media instances (`engine+0x2c`) and calls `NdSoundMediaInstance_TogglePauseResume(instance)`.
3. Iterates 2D instances (`engine+0x5c`) and calls `NdSound2dInstance_StopBuffer(instance)`.
4. Iterates 3D instances (`engine+0x8c`) and calls `NdSound3dInstance_RequestControlFlag1000Refresh(instance)`.

Wrapper notes:

- Export wrapper directly calls engine helper via singleton.
- No explicit null guard in the wrapper.

---

## `_DXContinue@0`

`_DXContinue@0()`

Verified behavior in `NdSoundEngine_ResumeAllSound`:

1. Requires initialized engine (`engine+0x1c != 0`) or returns immediately.
2. Iterates media instances (`engine+0x2c`) and calls `NdSoundMediaInstance_TogglePauseResume(instance)`.
3. Iterates 2D instances (`engine+0x5c`) and calls `NdSound2dInstance_StartFromCurrentSettings(instance)`.
4. Iterates 3D instances (`engine+0x8c`) and calls `NdSound3dInstance_InvokeControlFlag1000Resume(instance)`.

Wrapper notes:

- Export wrapper directly calls engine helper via singleton.
- No explicit null guard in the wrapper.

---

## Media toggle state machine

`NdSoundMediaInstance_TogglePauseResume` is used by both exports:

- if media backend pointer is null (`instance+0x2c == 0`): no-op.
- if state field (`instance+0x14`) is `0` or `1`:
  - call backend vtable `+0x1c`,
  - set state field to `2`.
- otherwise:
  - call backend vtable `+0x20`,
  - set state field to `1`.

This is a true toggle helper, not separate dedicated pause/resume helpers.

---

## `NdSoundEngine_ProcessFrame` interplay (per-instance transitions)

Pause/continue effects flow into these verified `ProcessFrame` transitions:

1. 3D refresh/aging counter (`instance+0x1b4`):
   - when non-zero, frame loop increments it each tick,
   - disposal check uses pre-increment value: dispose when previous counter `> 100`.
2. 2D stale/aging counter (`instance+0x28`):
   - when non-zero, frame loop increments it each tick,
   - disposal check uses pre-increment value: dispose when previous counter `> 100`.
3. 2D restart gate (`instance+0x24` and replay counter `instance+0xb0`):
   - when restart flag is clear and replay counter is non-zero, frame loop calls `NdSound2dInstance_StartFromCurrentSettings(instance)`.

These thresholds and gates are the source of the pause/continue process-frame contract mirrored in managed code.
