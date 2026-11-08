# Implementation evidence ledger — OCC + OCS (CP0.3 2026-11-05; server rows refreshed CP1.7 2026-11-06)

Baseline OCS `6241d61`, OCC `c6c718d5`. Rebuild: scan scripts under `evidence/ledger-2026-11-05/`.

| Level | Meaning | Count |
|---|---|---|
| A | repo doc cites native anchor (address / notes / Binja symbol); every cited client address present in 20_notes | 61 |
| B | anchor exists in 20_notes (keyword-confirmed); doc does not cite it → add citation | 36 |
| B? | candidate anchor, weak keyword match → confirm while citing | 4 |
| C | no native anchor found → RE needed | 0 |
| H | historical anchor only (TQ server / 5095 data); no 5517 client proof | 1 |
| M | modern/product by design (launcher, ops, persistence, hosting, security policy, own formats) | 44 |

Code citations: 14/14 native addresses quoted in OCS/OCC `src` comments exist in 20_notes.
Doc citation `0x66D477` (FLOW-001A) was absent from notes: Binja confirms `Sleep(5000)` in
`CGameMain_ConnectAccountServerWithBgpFallback` (`push 0x1388` `0x66D472`); added to `Network/5517-server-selection-and-realm-handoff.md`.

## OCS `docs/status.md` features → anchor

| Feature | Kind | Anchor |
|---|---|---|
| Host, config validation, DB readiness, supervised shutdown (both servers) | M | — |
| Connection limits, worker pools, timeouts | M | — |
| Account login: seed → credential → auth → ticket → 1055 → 2 reports | native | `Server/login-credential-envelope.md`; `Crypto/01_rc5_credential_field.md`; `Network/13_connection_lifecycle.md`; client AUTH-001A–E |
| Rate limiting, lockout, hash migration, ticket revocation, cleanup, metrics | M | — |
| 1060 `+260` server name → realm, 1055 redirect | native | `Network/5517-server-selection-and-realm-handoff.md` |
| 1055 refusal codes 10/70/20/21/11 | native text + **P** | client reads code only (`Network/13_connection_lifecycle.md:596`); retail `ini/Cn_Res.ini`: 010 "The Server is down.", 011 "Please try again later.", 020 "Server is busy.", 021 "Server is busy. Please try again, later.", 070 "Server Locked". Meanings 11 = playing in another realm, 21 = full are **OCS policy** mapped onto those texts |
| Registration `0xF001`/`0xF002` | M | non-native extension (`Architecture/03_login_flash_startup_command_contract.md:160`) |
| DH, CAST5 CFB64, ticket redemption | native | `Crypto/00_tqcipher64.md`; `Network/13_connection_lifecycle.md`; client AUTH-001F–M |
| Existing-character login + bootstrap sequence; 1134 discarded | native | `Server/world-entry-bootstrap.md` |
| World runtime partitions, generations, sessions, realm records | M | — |
| Kick notice 1115 | native | `CMsgKickoutNotice__Process` `0x75D80E` (registry) |
| Walk 10005 8/24 dir, selector 9 refused, dead/ghost bits, action 145, 1056/2 | native (+H pacing) | `Network/15_msgwalk_10005_direction_index_order.md`; `Server/movement-eligibility-5517.md`; `Server/death-ghost-revive-5517.md`; pacing intervals historical (`Server/tq-server-15.10-runtime-semantics.md`) |
| Jump 10010/137, 1–16 tiles, no-jump flag, collision | native | `Server/movement.md` (`0x658BDE`/`0x658BF0`); `Server/map-identity-flags-native-5517.md` |
| Position reports 100/146 → 108 correction | native packets + **P** | `Server/position-sync.md` (`CHero_TickIdlePositionSyncSend` `0x661AAC`); 64-tile history, 3-report threshold, 1/s rate are **OCS policy** |
| Peer spawn 10014 / walk relay / removal | native | `Server/entity-visibility.md`; `CMsgPlayer__Process` `0x755F64` |
| Turn (action 79), pose (action 81) | native | OCS `architecture/native-avatar-actions.md` (cited); `msgaction-prologue-dispatch` |
| Chat 1004 local/whisper/role words | native | `Server/chat.md`; `CMsgTalk__Process` `0x731371` |
| Portals / map transitions | native + H | OCS `architecture/native-portal-preflight.md`, `connected-portal-transfers.md` (cited); `Server/portal-transition-5517.md` |
| Character creation 1001 | native + H | OCS `protocol/character-creation.md` (cited); `Server/character-creation-decision-15.10.md` |

## OpenConquerClient docs

| Doc | Level | Native anchor |
|---|---|---|
| `architecture/architecture.md` | M | product/ops (no native counterpart) |
| `architecture/content-distribution.md` | M | product/ops (no native counterpart) |
| `architecture/launcher-instances.md` | M | product/ops (no native counterpart) |
| `architecture/launcher-managed-installation.md` | M | product/ops (no native counterpart) |
| `architecture/launcher-play-screen.md` | A | notes + symbols |
| `architecture/launcher-settings.md` | M | product/ops (no native counterpart) |
| `architecture/shared-build-baseline.md` | M | product/ops (no native counterpart) |
| `compatibility/native-graphics.md` | B | Rendering/graphic_dll/08_screen_dimensions_and_internal_resolution.md |
| `compatibility/native-text.md` | B | Rendering/graphic_dll/04_fonts_and_text.md |
| `compatibility/server-dat.md` | B | Crypto/02_server_dat_rsa_public_key_5517.md; Architecture/05_startup_data_files_and_native_replacement.md |
| `content/c3-studio-assets.md` | A | notes |
| `content/local-content.md` | M | product/ops (no native counterpart) |
| `content/retail-5517-content-plan.md` | M | product/ops (no native counterpart) |
| `content/retail-5517-inventory.md` | B | Architecture/05_startup_data_files_and_native_replacement.md |
| `development.md` | M | product/ops (no native counterpart) |
| `networking/AUTH-001A-account-wire-codecs.md` | A | 3 addr + notes + symbols |
| `networking/AUTH-001B-bounded-account-session.md` | A | notes |
| `networking/AUTH-001C-native-credential-composition.md` | A | 5 addr + notes + symbols |
| `networking/AUTH-001D-bounded-account-exchange.md` | A | 4 addr + notes |
| `networking/AUTH-001E-account-post-authentication-reports.md` | A | 3 addr + notes + symbols |
| `networking/AUTH-001F-offline-game-login-proof.md` | A | 3 addr + notes + symbols |
| `networking/AUTH-001G-game-server-challenge-envelope.md` | A | 3 addr + notes + symbols |
| `networking/AUTH-001H-game-bootstrap-cast5-cfb64.md` | A | notes |
| `networking/AUTH-001I-offline-game-dh-response.md` | A | 3 addr + notes + symbols |
| `networking/AUTH-001J-game-session-cast5-cfb64.md` | A | notes |
| `networking/AUTH-001K-game-secured-framing.md` | A | notes |
| `networking/AUTH-001L-bounded-loopback-game-handshake.md` | A | notes |
| `networking/AUTH-001M-game-login-proof-and-secured-io.md` | A | notes |
| `networking/AUTH-001N-game-login-control.md` | A | 2 addr + notes |
| `networking/AUTH-001O-existing-character-prelude.md` | A | 1 addr + notes + symbols |
| `networking/AUTH-001P-character-info-1006.md` | A | notes |
| `networking/AUTH-001Q-character-info-receipt.md` | A | 3 addr + notes + symbols |
| `networking/AUTH-001R-character-creation-continuation.md` | A | 6 addr + notes + symbols |
| `networking/FLOW-001A-live-login-bootstrap.md` | A | 2 addr + notes |
| `networking/FLOW-001B-account-registration.md` | A | symbols |
| `networking/README.md` | M | product/ops (no native counterpart) |
| `startup/LOADING-001.md` | M | product/ops (no native counterpart) |
| `startup/README.md` | M | product/ops (no native counterpart) |
| `startup/ROLE-001A.md` | A | notes + symbols |
| `startup/ROLE-001B.md` | A | notes + symbols |
| `startup/STARTUP-001C.md` | B | Architecture/11_login_ui_assets_and_interactions.md |
| `startup/STARTUP-001D.md` | B | Architecture/11_login_ui_assets_and_interactions.md |
| `startup/STARTUP-001E.md` | B | Architecture/11_login_ui_assets_and_interactions.md |
| `startup/STARTUP-001F.md` | B | Network/5517-server-selection-and-realm-handoff.md |
| `startup/STARTUP-001G.md` | M | product/ops (no native counterpart) |
| `startup/STARTUP-001H.md` | B? | Rendering/graphic_dll/04_fonts_and_text.md |
| `startup/STARTUP-001I.md` | M | product/ops (no native counterpart) |
| `startup/STARTUP-001J.md` | M | product/ops (no native counterpart) |
| `startup/STARTUP-001K.md` | A | 2 addr + notes + symbols |
| `startup/STARTUP-001L.md` | A | notes + symbols |
| `startup/STARTUP-001M.md` | B | Architecture/11_login_ui_assets_and_interactions.md |
| `startup/STARTUP-001N.md` | M | product/ops (no native counterpart) |
| `startup/STARTUP-001P.md` | B | Architecture/11_login_ui_assets_and_interactions.md; 03_login_flash_startup_command_contract.md |
| `startup/STARTUP-001Q.md` | A | notes + symbols |
| `startup/STARTUP-001R.md` | A | notes |
| `startup/STARTUP-001S.md` | M | product/ops (no native counterpart) |
| `startup/STARTUP-001T.md` | B | Architecture/11_login_ui_assets_and_interactions.md |
| `startup/STARTUP-001U.md` | M | product/ops (no native counterpart) |
| `startup/STARTUP-001V.md` | A | notes |
| `startup/STARTUP-001W.md` | A | 1 addr + symbols |
| `startup/STARTUP-001X.md` | B | Architecture/11_login_ui_assets_and_interactions.md |
| `startup/STARTUP-001Y.md` | A | symbols |
| `startup/STARTUP-001Z.md` | A | 2 addr + notes + symbols |
| `startup/STARTUP-002-world-activation.md` | B | Architecture/09_frame_loop_architecture.md; Game_Map/post_login_world_loading_orchestration.md |
| `studio-integration.md` | M | product/ops (no native counterpart) |
| `world/WORLD-001-map-cell-grid.md` | B | Game_Map/cgamemap_class.md |
| `world/WORLD-002-scene-sections.md` | B | Rendering/05_dmap_positioned_overlay_system.md |
| `world/WORLD-003-map-archive.md` | B | Game_Map/map1999_icecrypt_archive_native.md |
| `world/WORLD-004-map-content-loading.md` | B | Game_Map/post_login_world_loading_orchestration.md |
| `world/WORLD-005-puzzle-resources.md` | A | notes |
| `world/WORLD-006-puzzle-animation-binding.md` | B? | Game_Map/pux_aoxpuzzle_terrain.md; Rendering/07_ani_frame_animation_runtime.md |
| `world/WORLD-007-dds-compression.md` | B | Rendering/c3_core_dll/06_image_decoders.md |
| `world/WORLD-008-map-puzzle-preflight.md` | M | offline validation tool |
| `world/WORLD-009-puzzle-layer-drawing.md` | B | Game_Map/world_render_contract_5517.md |
| `world/WORLD-010-scenery-ani-binding.md` | B | Rendering/07_ani_frame_animation_runtime.md; Rendering/05_dmap_positioned_overlay_system.md |
| `world/WORLD-011-camera-and-puzzle-frames.md` | B | Game_Map/world_render_contract_5517.md; Rendering/graphic_dll/03_camera.md |
| `world/WORLD-012-terrain-scene-resources.md` | B | Game_Map/world_render_contract_5517.md |
| `world/WORLD-013-terrain-scene-drawing.md` | B? | Game_Map/world_render_contract_5517.md |
| `world/WORLD-014-world-scene-activation.md` | B? | Game_Map/post_login_world_loading_orchestration.md |
| `world/WORLD-015-role-geometry.md` | B | Rendering/graphicdata_dll/04_mesh_resource_loading.md; Rendering/graphic_dll/12_meshcreate_and_c3dobjx.md |
| `world/WORLD-016-phy-geometry.md` | B | Rendering/c3_core_dll/05_phy.md |
| `world/WORLD-017-c3-motion.md` | B | Rendering/c3_core_dll/12_motion_load_formats.md; 13_motion_sampling_and_blend.md |
| `world/WORLD-018-phy-deformation.md` | B | Rendering/c3_core_dll/13_motion_sampling_and_blend.md; 05_phy.md |
| `world/WORLD-019-indexed-mesh-submission.md` | B | Rendering/c3_core_dll/05_phy.md (DrawIndexedPrimitive) |
| `world/WORLD-020-character-mesh-world-depth.md` | B | Rendering/06_hero_render_pipeline.md |
| `world/WORLD-021-local-role-playback-and-world-presentation.md` | B | Rendering/roleview_dll/07_action_playback_transition_state.md; 13_role_compute_frame_interval.md |
| `world/WORLD-022-initial-character-parts.md` | B | Entity_System/role_visual_construction.md; Rendering/11_3d_role_part_loaders.md |
| `world/WORLD-023-authenticated-world-ingress.md` | B | Network/01_core_packets.md; Network/00_protocol_overview.md (registry) |
| `world/WORLD-024-ground-walk-transport.md` | B | Network/15_msgwalk_10005_direction_index_order.md; Server/movement.md |
| `world/WORLD-025-first-world-hero-attributes.md` | B | Network/11_else_branch_packets.md (MsgUserAttrib 10017); MsgUserInfo1006-semantic-closure-2026-09-17.md |
| `world/WORLD-026-initial-equipment-state.md` | B | Server/equipment.md; Network/08_system_packets.md (MsgItem 1009); MsgItem1008-domain-contract-5517.md |
| `world/WORLD-027-first-world-vitals.md` | A | Rendering/14_hero_effective_max_life_mana.md; 13_hud_progress_gauges.md; hero-model-cp22.md. CP2.2 adds per-rule anchors, clamp correction and explicit residuals. |
| `world/WORLD-028-first-world-experience.md` | B | Entity_System/chero_class.md:444 (LevExp.dat seed 0x4D2) |

## OpenConquerServer docs

| Doc | Level | Native anchor |
|---|---|---|
| `README.md` | M | product/ops (no native counterpart) |
| `architecture/README.md` | M | product/ops (no native counterpart) |
| `architecture/account-registration.md` | M | product/ops (no native counterpart) |
| `architecture/authentication.md` | A | 3 addr + notes + symbols |
| `architecture/authoritative-movement-eligibility.md` | A | notes |
| `architecture/character-creation-session-primitives.md` | A | notes |
| `architecture/character-creation.md` | A | 2 addr + notes + symbols |
| `architecture/connected-portal-transfers.md` | A | 1 addr + notes + symbols |
| `architecture/durable-character-location.md` | M | product/ops (no native counterpart) |
| `architecture/exception-handling.md` | M | product/ops (no native counterpart) |
| `architecture/fenced-character-admission.md` | M | product/ops (no native counterpart) |
| `architecture/ground-walking.md` | A | 2 addr + notes |
| `architecture/multi-realm.md` | A | notes |
| `architecture/native-24-direction-movement.md` | A | 3 addr + notes + symbols |
| `architecture/native-avatar-actions.md` | A | 7 addr + notes + symbols |
| `architecture/native-chat.md` | A | notes + symbols |
| `architecture/native-jumping.md` | A | 4 addr + notes + symbols |
| `architecture/native-portal-preflight.md` | A | 3 addr + notes + symbols |
| `architecture/networking.md` | A | 2 addr + notes + symbols |
| `architecture/persistence.md` | A | 1 addr + symbols |
| `architecture/player-visibility.md` | A | 5 addr + notes |
| `architecture/position-synchronization.md` | A | notes |
| `architecture/revival-destination-authority.md` | A | notes |
| `architecture/server-responsibilities.md` | A | notes |
| `architecture/shared-build-baseline.md` | M | product/ops (no native counterpart) |
| `architecture/world-command-load.md` | A | 2 addr + notes |
| `architecture/world-execution.md` | M | partition design (modern) |
| `architecture/world-transfer-preflight.md` | M | product/ops (no native counterpart) |
| `architecture/world-transition-catalog-readiness.md` | M | product/ops (no native counterpart) |
| `content/README.md` | M | product/ops (no native counterpart) |
| `content/base-terrain-format.md` | M | product/ops (no native counterpart) |
| `content/collision-format.md` | M | product/ops (no native counterpart) |
| `content/historical-source-reconciliation.md` | H | Server/historical-reconciliation-5095.md |
| `content/item-type-catalog-v2.md` | A | 1 addr + notes |
| `content/item-type-native-source.md` | A | notes |
| `content/map-transitions.md` | A | 1 addr + notes + symbols |
| `operations/account-server.md` | M | product/ops (no native counterpart) |
| `operations/character-creation-persistence.md` | M | product/ops (no native counterpart) |
| `operations/character-creation-starting-state.md` | A | 1 addr + symbols |
| `operations/database-identities.md` | M | product/ops (no native counterpart) |
| `operations/database-migrations.md` | M | product/ops (no native counterpart) |
| `operations/game-realm-binding.md` | M | product/ops (no native counterpart) |
| `operations/game-server.md` | M | product/ops (no native counterpart) |
| `operations/local-realm-provisioning.md` | M | product/ops (no native counterpart) |
| `operations/realm-bound-tickets.md` | M | product/ops (no native counterpart) |
| `operations/realm-registry.md` | M | product/ops (no native counterpart) |
| `operations/realms.md` | M | product/ops (no native counterpart) |
| `protocol/README.md` | A | 1 addr + notes + symbols |
| `protocol/character-creation.md` | A | 6 addr + notes + symbols |
| `protocol/framing.md` | A | 2 addr + notes + symbols |
| `protocol/text-encoding.md` | A | notes |
| `reviews/PR-171-registration-audit.md` | M | product/ops (no native counterpart) |
| `status.md` | A | notes |

## Gaps → closing checkpoint

- **B / B? docs (add native citation):** server docs → CP1.7; client docs → CP2.10. B? items must confirm the anchor or be downgraded to C.
- **P items (policy on native packets):** document as policy in the repo doc (not native) → CP1.7.
- **H items:** stay historical; any 5517 behaviour claim built on them needs a client Binja anchor before CP5+ work.
- **C items:** none found in docs. Unanchored *claims inside* A/B docs are not yet itemised — a per-claim pass happens when each doc is cited (CP1.7/CP2.10).

## Post-baseline ownership work

| Date | Repo document | Level | Checkpoint / authority |
| --- | --- | --- | --- |
| 2026-11-06 | OCC `architecture/client-role-ownership.md` | M | CP2.1b role lifetime/host extraction; `Architecture/client-role-ownership.md`. Existing role-flow anchors and pinned transport fixtures reused; no new native behavior claim. |
| 2026-11-06 | OCC `architecture/client-session-ownership.md` | M | CP2.1c login owner, explicit phases and ordered shutdown; `Architecture/client-session-ownership.md`. Existing native loading/role anchors and pinned encrypted fixtures reused. |
| 2026-11-06 | OCC `world/WORLD-027-first-world-vitals.md` | A | CP2.2 model boundary; `Rendering/hero-model-cp22.md` and byte-verified evidence. Static golden cases; runtime and packet-batch timing parity not claimed. |
| 2026-11-06 | OCC `world/WORLD-023-authenticated-world-ingress.md`, `WORLD-026-initial-equipment-state.md` | A | CP2.4b handler no-op and item-instance rules; `Network/inbound-tolerance-cp24.md`, 455 byte-verified native instructions. Off-map/bootstrap and parked #262/#263/#264 remain explicit. |
| 2026-11-06 | OCC `world/WORLD-023-authenticated-world-ingress.md`, `WORLD-020-character-mesh-world-depth.md` | A | CP2.4c signed/off-map tiles, screen visibility, depth and NULL terrain contribution; `Network/off-map-tiles-cp24c.md`, 789 verified instructions and 27 static golden inputs. Bootstrap/runtime and independent motion/offset limits remain explicit. |
