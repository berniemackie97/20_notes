# `NDsound.dll` - Overview

`NDsound.dll` is the legacy audio engine wrapper used by the Windows 5517 client.  
Its exports provide a `DX*` API surface for sound playback, per-frame audio ticking, and global volume control.

## Verified core lifecycle

- Engine singleton global: `g_NdSoundEngineSingleton` (`0x10016604`).
- `_DXSoundinit@4` (`0x10008527`):
  - allocates `NdSoundEngine_Create` (`0x10004CB0`) when singleton is null,
  - initializes it via `NdSoundEngine_Initialize` (`0x10004E40`) with caller window handle.
- `_DXDestroy@0` (`0x100095AD`):
  - releases the singleton and clears `g_NdSoundEngineSingleton`.

## Verified export families

- Playback:
  - `_DXPlaySound@24` (`0x100085FC`) -> `NdSoundEngine_PlaySound2dOrPositional`
  - `_DXPlay3DSound@32` (`0x1000870D`) -> `NdSoundEngine_Play3dSound`
  - `_DXPlayMedia@12` (`0x10008834`) -> `NdSoundEngine_PlayMediaStream`
- Lookup / close:
  - `_DXGetSound@12` (`0x10008CC1`) -> `NdSoundEngine_Find2dSoundByPathAndEmitter`
  - `_DXGet3DSound@12` (`0x10008DBA`) -> `NdSoundEngine_Find3dSoundByPathAndEmitter`
  - `_DXCloseSound@12` (`0x100089FD`) -> `NdSoundEngine_Close2dSoundByPathAndEmitter`
  - `_DXCloseMedia@4` (`0x10008AF6`) -> `NdSoundEngine_CloseMediaByPath`
  - `_DXCloseAllMedia@0` (`0x100096E6`) -> `NdSoundEngine_CloseAllMediaStreams`
  - `_DXClose2DSound@4` (`0x10008EB3`) -> `NdSoundEngine_Close2dSoundByHandle`
  - `_DXClose3DSound@4` (`0x10008F9F`) -> `NdSoundEngine_Close3dSoundByHandle`
  - `_DXCloseAllSound@0` (`0x10009675`) -> `NdSoundEngine_CloseAllSound`
- Tick / pause:
  - `_DXProcessSound@8` (`0x10008940`) -> `NdSoundEngine_ProcessFrame`
  - `_DXPause@0` (`0x10008BDF`) -> `NdSoundEngine_PauseAllSound`
  - `_DXContinue@0` (`0x10008C50`) -> `NdSoundEngine_ResumeAllSound`
- Volume:
  - `_DXSetVolume@16` (`0x10009267`) -> `NdSoundEngine_SetSoundVolumeByPathAndEmitter`
  - `_DXSet2DSoundPos@12` (`0x10009180`) -> `NdSoundEngine_Set2dSoundPositionByHandle`
  - `_DXSet3DSoundPos@16` (`0x1000908E`) -> `NdSoundEngine_Set3dSoundPositionByHandle`
  - `_DXSaveMusicVolume@0` (`0x100097C8`) -> `NdSoundEngine_SaveCurrentVolumesAndMuteOutput`
  - `_DXFlushVolume@0` (`0x10009757`) -> `NdSoundEngine_StartSavedVolumeRestore`
  - `_DXSetMusicVolume@4` (`0x10009353`) -> `NdSoundEngine_SetMusicVolumePercent`
  - `_DXSetSoundVolume@4` (`0x10009406`) -> `NdSoundEngine_SetSoundVolumePercent`
  - `_DXGetMusicVolume@0` (`0x100094B9`) -> `NdSoundEngine_GetMusicVolumePercent`
  - `_DXGetSoundVolume@0` (`0x10009533`) -> `NdSoundEngine_GetSoundVolumePercent`
