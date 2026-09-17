# `NDsound.dll` Documentation Index

- `00_overview.md` - module role, lifecycle, and exported API families.
- `01_dxplaysound_contract.md` - verified `_DXPlaySound@24` semantics and high-level `_DXProcessSound@8` linkage notes.
- `02_dxplay3dsound_contract.md` - verified `_DXPlay3DSound@32` and `_DXSet3DSoundPos@16` semantics.
- `03_dxplaymedia_contract.md` - verified `_DXPlayMedia@12`, `_DXCloseMedia@4`, `_DXCloseAllMedia@0`, and media replay semantics.
- `04_dxsound_lookup_close_volume_contract.md` - verified `_DXGetSound@12`, `_DXGet3DSound@12`, `_DXCloseSound@12`, and `_DXSetVolume@16` match/update semantics.
- `05_dxsound_handle_control_contract.md` - verified `_DXClose2DSound@4`, `_DXClose3DSound@4`, `_DXSet2DSoundPos@12`, and `_DXSet3DSoundPos@16` handle-control semantics.
- `06_dxglobal_volume_contract.md` - verified `_DXSetMusicVolume@4`, `_DXSetSoundVolume@4`, `_DXGetMusicVolume@0`, and `_DXGetSoundVolume@0` global-volume semantics.
- `07_dxvolume_save_flush_contract.md` - verified `_DXSaveMusicVolume@0` / `_DXFlushVolume@0` delayed restore lifecycle semantics.
- `08_dxpause_dxcontinue_contract.md` - verified `_DXPause@0` / `_DXContinue@0` pause-continue contract and `NdSoundEngine_ProcessFrame` instance-transition interplay.
- `09_dxprocesssound_contract.md` - verified `_DXProcessSound@8` frame-tick contract (listener forwarding, delayed-restore gate, periodic volume refresh, and per-instance aging/restart transitions).
- `10_dxsound_lifecycle_contract.md` - verified `_DXSoundinit@4`, `_DXDestroy@0`, and `_DXCloseAllSound@0` lifecycle contract (singleton creation/teardown, DirectSound bootstrap settings, and close-all behavior).
