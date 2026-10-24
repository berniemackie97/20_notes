# Architecture — index

Process-level behaviour: how the client starts, what it reads on the way up, and
how its frame loop is driven. Also holds the managed solution's own structure
records.

## Native startup

- [01_play_launcher_startup_and_handoff.md](01_play_launcher_startup_and_handoff.md) —
  `play.exe` startup and the handoff to the client.
- [02_conquer_client_startup_chain.md](02_conquer_client_startup_chain.md) —
  `Conquer.exe` from CRT entry through the first stable frame-driving loop.
- [03_login_flash_startup_command_contract.md](03_login_flash_startup_command_contract.md) —
  the full command surface between `CLoginFlashDlg` and `start.dat` (Flash SWF).
- [05_startup_data_files_and_native_replacement.md](05_startup_data_files_and_native_replacement.md) —
  data files consumed during startup and login, and the replacement strategy for
  each.

## Runtime

- [09_frame_loop_architecture.md](09_frame_loop_architecture.md) —
  `CMyShellDlg_RunFrameTick`, from `MyShellDlg.cpp` (assert string at `0x93F3CE`).
- [04_dummy_movie_system.md](04_dummy_movie_system.md) — `CDummyMovieMgr`. Despite
  the name, a timed sprite animation system.

## Server-facing

- [06_server_schema_compatibility.md](06_server_schema_compatibility.md) — schema
  facts verified from the workspace `conquer.sql` backup.

## Managed solution structure

These record refactors of `10_work/src`, not native findings. They are kept for
continuity with the slices that produced them.

- [00_solution_architecture.md](00_solution_architecture.md) — project-layer
  boundary contract for `10_work`.
- [07_client_application_world_structure_refactor.md](07_client_application_world_structure_refactor.md)
- [08_client_contract_model_folder_normalization.md](08_client_contract_model_folder_normalization.md)
- [10_conquer_project_source_structure.md](10_conquer_project_source_structure.md)

- [Retail 5517 login UI assets and interactions](11_login_ui_assets_and_interactions.md) — source-hashed Flash artwork, timelines, account controls, credential editing, original-asset package and explicit runtime gaps (2026-10-14; research only).
