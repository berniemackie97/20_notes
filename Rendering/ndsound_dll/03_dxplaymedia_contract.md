# `_DXPlayMedia@12` Contract (Verified)

## Export + core implementation

- Export: `_DXPlayMedia@12` (`0x10008834`)
- Core function: `NdSoundEngine_PlayMediaStream` (`0x10006578`)

## Verified argument semantics

`_DXPlayMedia@12(mediaPath, startSecondRaw, replayCount)`

- `mediaPath`:
  - required by downstream DirectShow setup (`RenderFile`),
  - no `.WAV`-style extension gate in this wrapper path.
- `startSecondRaw`:
  - wrapper truncates to `uint16` (`mov ax, [arg2]`) before forwarding,
  - converted to media time by `startSecond * 10_000_000` (100 ns units),
  - seek position is reduced modulo `(durationTicks + 1)`.
- `replayCount`:
  - stored on media instance (`+0x18`),
  - interpreted by completion-event processing:
    - `0` -> stop/remove at end,
    - `-1` -> loop forever,
    - positive values -> decrement on each completion and continue until zero.

## Verified playback initialization flow

`NdSoundEngine_PlayMediaStream`:

1. Requires initialized engine (`this+0x1c != 0`).
2. Allocates `NdSoundMediaInstance` (`0x148` bytes).
3. Calls `NdSoundMediaInstance_InitializePlayback`.
4. On success, applies global music volume via `NdSoundMediaInstance_SetVolumePercent`.
5. Appends instance to engine media-instance vector (`this+0x2c`) and returns handle.
6. On failure, releases allocated instance and returns `null`.

`NdSoundMediaInstance_InitializePlayback`:

1. Stores host window handle, replay count, and media path.
2. Creates DirectShow graph:
  - `CoCreateInstance(CLSID_FilterGraph, ..., IID_IGraphBuilder, ...)`
  - `IGraphBuilder::RenderFile(wideMediaPath, 0)`
3. Queries interfaces from graph builder:
  - `IID_IMediaControl`
  - `IID_IMediaSeeking`
  - `IID_IBasicVideo`
  - `IID_IVideoWindow`
  - `IID_IMediaEventEx`
  - `IID_IBasicAudio`
4. Calls `NdSoundMediaInstance_DetectAudioOnlyPlayback`.
5. Starts playback through media-control interface.
6. Calls `NdSoundMediaInstance_ConfigureSeekingAndReadDuration`:
  - checks `IMediaSeeking::IsFormatSupported(TIME_FORMAT_MEDIA_TIME)`,
  - stores current format,
  - sets `TIME_FORMAT_MEDIA_TIME`,
  - reads stream duration ticks (`+0x20/+0x24`),
  - restores previous time format when it differs.
7. Calls `NdSoundMediaInstance_SeekToStartSecondModuloDuration` with truncated `startSecond`.

## Volume mapping (media path)

`NdSoundMediaInstance_SetVolumePercent` maps percent input to DirectShow volume:

- `0` -> `-10000` (minimum)
- `>100` -> `0` (maximum)
- `1..100` -> `((percent - 100) * 100) / 2`

The value is written through the media-audio interface `put_Volume` call path.

## Completion / replay behavior

Per-frame media update occurs in `NdSoundMediaInstance_ProcessPlaybackEvents` (called from `NdSoundEngine_ProcessFrame`):

- Pumps event queue via media-event interface.
- For completion event code `1`:
  - if `replayCount == 0`, returns `0` (caller removes media instance),
  - otherwise seeks to start and restarts playback,
  - decrements replay count when replay count is not `-1`.
- Returns `1` to keep instance active when no terminal condition is hit.

## Close semantics

- `_DXCloseMedia@4` (`0x10008AF6`) -> `NdSoundEngine_CloseMediaByPath`:
  - linear scans active media instances,
  - matches by `strcmp(instancePath, mediaPath)` (case-sensitive),
  - stops/releases first match, compacts vector, returns `1` on close, `0` on miss.
- `_DXCloseAllMedia@0` (`0x100096E6`) -> `NdSoundEngine_CloseAllMediaStreams`:
  - stops/releases all media instances and clears vector.
