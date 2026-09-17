# Game map — index

World rendering, the radar, and the on-disk terrain formats.

- [cgamemap_class.md](cgamemap_class.md) — `CGameMap` / `C3DGameMap`, world
  rendering. IDA folder `/Game_Map/`, 23 functions across 2 sub-folders.
- [post_login_world_loading_orchestration.md](post_login_world_loading_orchestration.md) —
  the order in which the world comes up after login, and which handler owns each
  piece of local-hero state.
- [cradar_cell_to_radar_projection.md](cradar_cell_to_radar_projection.md) —
  `CRadar` cell-to-radar projection. Translation unit proven by the assert string
  at `0x6275C1`.
- [pux_aoxpuzzle_terrain.md](pux_aoxpuzzle_terrain.md) — `CAoxPuzzle` and the
  `.pux` "TqTerrain" format.

Map transitions, map assets and the server's side of world entry are in
[../Server/](../Server/README.md).
