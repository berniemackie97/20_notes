# Sound — index

Two documents about where the sound model went wrong, and why.

- [01_ndsound_export_surface.md](01_ndsound_export_surface.md) — the `NDsound.dll`
  export surface. Two independent sources pin this API and disagree in ways that
  matter; this reconciles them.
- [02_map_sound_path.md](02_map_sound_path.md) — map sound in 5517, and why the
  managed `CMapSound` models the wrong class. `Check2DSound` is real and is used
  by the ancestor source, which is what made the wrong model plausible.

Per-export behavioural contracts for `NDsound.dll` live with the rest of the DLL
deep-dives, in [../Rendering/ndsound_dll/](../Rendering/ndsound_dll/README.md).
