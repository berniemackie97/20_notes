# Rendering — index

The 5517 render stack. The EXE does almost no drawing itself: it calls a
proprietary `graphic.dll` (a `CMyBitmap::*` static-method façade) which wraps the
C3 engine in `c3_core_dll.dll`, with assets resolved through `GraphicData.dll` and
entity visuals built by `RoleView.dll` over `Role3D.dll`.

Reading order for the whole path: [00_rendering_gap_analysis.md](00_rendering_gap_analysis.md)
for the boundaries, [06_hero_render_pipeline.md](06_hero_render_pipeline.md) for
one complete call chain end to end, then the DLL deep-dive for whichever layer you
need.

## Boundaries and observed interfaces

Reconstructed from EXE call sites — this is what the client actually uses, not the
DLLs' full capability.

- [00_rendering_gap_analysis.md](00_rendering_gap_analysis.md) — every
  Windows-specific and DLL-specific touchpoint: windowing, GDI, DirectInput, WinMM
  timing, device-loss semantics.
- [01_graphic_dll_api_surface.md](01_graphic_dll_api_surface.md) — every imported
  `graphic.dll` symbol, grouped by function.
- [02_roleview_object_interface.md](02_roleview_object_interface.md) — the minimum
  vtable surface of objects returned by `RoleViewCreate`.
- [03_targetbmp_and_mybitmap_object_interfaces.md](03_targetbmp_and_mybitmap_object_interfaces.md) —
  offscreen render targets and drawables.

## Pipelines

- [06_hero_render_pipeline.md](06_hero_render_pipeline.md) — the hero/role render
  path from the per-frame tick down to the draw call. The best single entry point.
- [04_static_mesh_baseline_runtime.md](04_static_mesh_baseline_runtime.md) —
  deterministic static-mesh selection for the OpenGL baseline runtime, with
  real-client topology evidence.
- [05_dmap_positioned_overlay_system.md](05_dmap_positioned_overlay_system.md) —
  the DMap post-type-3 section of positioned overlay records.

## Individual subsystems

- [07_ani_frame_animation_runtime.md](07_ani_frame_animation_runtime.md) — `CAni`
  / `CAniFile`, the 2D frame-animation runtime.
- [08_alpha_mask_pixel_hit_test.md](08_alpha_mask_pixel_hit_test.md) —
  `CAlphaMask`, the 1-bit-per-pixel sprite hit mask.
- [09_player_roleview_weapon_slot_setter.md](09_player_roleview_weapon_slot_setter.md) —
  the `PlayerRoleView_Set{Right,Left}WeaponSource` pair and its packed argument.
- [10_3d_mount_part_loader.md](10_3d_mount_part_loader.md) — `C3DMount`, the mount
  mesh and texture part loader.
- [11_3d_role_part_loaders.md](11_3d_role_part_loaders.md) — the bulk-copy loader
  family: `C3DArmor`, `C3DArmet`, `C3DMisc`, `C3DMount`, `C3DWeapon`.

## HUD

- [14_static_main_hud_chrome.md](14_static_main_hud_chrome.md) — GFX-UI-001,
  English Progress45/Dialog4 calls, clean assets, placement and failure contract.

- [12_hud_status_hint_panel.md](12_hud_status_hint_panel.md) —
  `CMyShellDlg__RenderStatusHintPanel` (`0x5B9C3F`), the hover-hint panel.
- [13_hud_progress_gauges.md](13_hud_progress_gauges.md) — `CMyProgress`, the HUD
  gauge widget. Anchor `CMyProgress::Show` (`0x5A9033`).
- [14_hero_effective_max_life_mana.md](14_hero_effective_max_life_mana.md) —
  `CHero_GetEffectiveMaxLife` (`0x65D06D`) and `CHero_GetEffectiveMaxMana`
  (`0x65D25A`), which the gauges read.

- [15_main_hud_gauge_render_contract.md](15_main_hud_gauge_render_contract.md) — GFX-UI-002: HP/MP/stamina frame closure, overflow UV wrapping, failure behavior and font-calibrated origins.
- [16_main_hud_skill_progress_render_contract.md](16_main_hud_skill_progress_render_contract.md) — GFX-UI-003: Progress42 status/message state machine, exact timer ordering and wrap behavior, 92×92 fill versus 128×128 highlight, assets and replay vectors; Progress44's procedural draw corrects the earlier no-draw premise.
- [17_main_hud_action_strip_native_contract.md](17_main_hud_action_strip_native_contract.md) — evidence-only audit of ten CMyButton handlers and state writers, Skill/Mission frame-2 limits, exact PK skin/blink behavior, and corrected native command routing.
- [18_main_hud_check_controls_native_contract.md](18_main_hud_check_controls_native_contract.md) — GFX-UI-005 evidence: CMyCheck mouse-down state changes, bounded setter, MFC/Windows delegation, Check43/Check46/Button411 effects and exact native rectangles; target-OS release notifications remain explicitly unobserved.

## DLL deep-dives

- [c3_core_dll/](c3_core_dll/README.md) — the C3 engine core. Device lifecycle,
  sprites, textures, fonts, the `Phy_*` mesh pipeline including CPU skinning,
  motion and particle formats, WDF archives.
- [graphic_dll/](graphic_dll/README.md) — the `CMyBitmap` façade over C3. Device
  reset, camera, text, render targets, `MeshCreate`/`MotionCreate`.
- [graphicdata_dll/](graphicdata_dll/README.md) — `GameDataSetQuery` and
  data-driven asset resolution: the `id -> path -> bytes` pipeline, the `c3.wdb`
  and `RSDB` formats, the INI tuning files, `DataThread.dll`.
- [role3d_dll/](role3d_dll/README.md) — `I3DRole` and `Simple3DObj`, part records,
  effect instances and the effect tick state machine.
- [roleview_dll/](roleview_dll/README.md) — `RoleViewCreate` type dispatch, motion
  lookup keys, action playback and transition state, the transform chain and the
  role scale formula.
- [ndsound_dll/](ndsound_dll/README.md) — per-export `DX*` behavioural contracts.
  Sits here because it is a DLL deep-dive; the sound *findings* are in
  [../Sound/](../Sound/README.md).
- `gamedata_dll/` — [01_action_control_motion_easing.md](gamedata_dll/01_action_control_motion_easing.md)
  only. `GameData.dll` is otherwise undocumented.
