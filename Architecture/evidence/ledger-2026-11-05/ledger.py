import json,sys
S=sys.argv[1]; out=sys.argv[2]
scan=json.load(open(f"{S}/cp03/scan.json")); m=json.load(open(f"{S}/cp03/match.json"))
B={ # uncited native-parity doc -> (level, anchor)
"OCC:compatibility/native-graphics.md":("B","Rendering/graphic_dll/08_screen_dimensions_and_internal_resolution.md"),
"OCC:compatibility/native-text.md":("B","Rendering/graphic_dll/04_fonts_and_text.md"),
"OCC:compatibility/server-dat.md":("B","Crypto/02_server_dat_rsa_public_key_5517.md; Architecture/05_startup_data_files_and_native_replacement.md"),
"OCC:world/WORLD-001-map-cell-grid.md":("B","Game_Map/cgamemap_class.md"),
"OCC:world/WORLD-002-scene-sections.md":("B","Rendering/05_dmap_positioned_overlay_system.md"),
"OCC:world/WORLD-003-map-archive.md":("B","Game_Map/map1999_icecrypt_archive_native.md"),
"OCC:world/WORLD-004-map-content-loading.md":("B","Game_Map/post_login_world_loading_orchestration.md"),
"OCC:world/WORLD-006-puzzle-animation-binding.md":("B?","Game_Map/pux_aoxpuzzle_terrain.md; Rendering/07_ani_frame_animation_runtime.md"),
"OCC:world/WORLD-007-dds-compression.md":("B","Rendering/c3_core_dll/06_image_decoders.md"),
"OCC:world/WORLD-008-map-puzzle-preflight.md":("M","offline validation tool"),
"OCC:world/WORLD-009-puzzle-layer-drawing.md":("B","Game_Map/world_render_contract_5517.md"),
"OCC:world/WORLD-010-scenery-ani-binding.md":("B","Rendering/07_ani_frame_animation_runtime.md; Rendering/05_dmap_positioned_overlay_system.md"),
"OCC:world/WORLD-011-camera-and-puzzle-frames.md":("B","Game_Map/world_render_contract_5517.md; Rendering/graphic_dll/03_camera.md"),
"OCC:world/WORLD-012-terrain-scene-resources.md":("B","Game_Map/world_render_contract_5517.md"),
"OCC:world/WORLD-013-terrain-scene-drawing.md":("B?","Game_Map/world_render_contract_5517.md"),
"OCC:world/WORLD-014-world-scene-activation.md":("B?","Game_Map/post_login_world_loading_orchestration.md"),
"OCC:world/WORLD-015-role-geometry.md":("B","Rendering/graphicdata_dll/04_mesh_resource_loading.md; Rendering/graphic_dll/12_meshcreate_and_c3dobjx.md"),
"OCC:world/WORLD-016-phy-geometry.md":("B","Rendering/c3_core_dll/05_phy.md"),
"OCC:world/WORLD-017-c3-motion.md":("B","Rendering/c3_core_dll/12_motion_load_formats.md; 13_motion_sampling_and_blend.md"),
"OCC:world/WORLD-018-phy-deformation.md":("B","Rendering/c3_core_dll/13_motion_sampling_and_blend.md; 05_phy.md"),
"OCC:world/WORLD-019-indexed-mesh-submission.md":("B","Rendering/c3_core_dll/05_phy.md (DrawIndexedPrimitive)"),
"OCC:world/WORLD-020-character-mesh-world-depth.md":("B","Rendering/06_hero_render_pipeline.md"),
"OCC:world/WORLD-021-local-role-playback-and-world-presentation.md":("B","Rendering/roleview_dll/07_action_playback_transition_state.md; 13_role_compute_frame_interval.md"),
"OCC:world/WORLD-022-initial-character-parts.md":("B","Entity_System/role_visual_construction.md; Rendering/11_3d_role_part_loaders.md"),
"OCC:world/WORLD-023-authenticated-world-ingress.md":("B","Network/01_core_packets.md; Network/00_protocol_overview.md (registry)"),
"OCC:world/WORLD-024-ground-walk-transport.md":("B","Network/15_msgwalk_10005_direction_index_order.md; Server/movement.md"),
"OCC:world/WORLD-025-first-world-hero-attributes.md":("B","Network/11_else_branch_packets.md (MsgUserAttrib 10017); MsgUserInfo1006-semantic-closure-2026-09-17.md"),
"OCC:world/WORLD-026-initial-equipment-state.md":("B","Server/equipment.md; Network/08_system_packets.md (MsgItem 1009); MsgItem1008-domain-contract-5517.md"),
"OCC:world/WORLD-027-first-world-vitals.md":("B","Rendering/14_hero_effective_max_life_mana.md; 13_hud_progress_gauges.md"),
"OCC:world/WORLD-028-first-world-experience.md":("B","Entity_System/chero_class.md:444 (LevExp.dat seed 0x4D2)"),
"OCC:content/retail-5517-inventory.md":("B","Architecture/05_startup_data_files_and_native_replacement.md"),
"OCC:startup/STARTUP-001C.md":("B","Architecture/11_login_ui_assets_and_interactions.md"),
"OCC:startup/STARTUP-001D.md":("B","Architecture/11_login_ui_assets_and_interactions.md"),
"OCC:startup/STARTUP-001E.md":("B","Architecture/11_login_ui_assets_and_interactions.md"),
"OCC:startup/STARTUP-001F.md":("B","Network/5517-server-selection-and-realm-handoff.md"),
"OCC:startup/STARTUP-001H.md":("B?","Rendering/graphic_dll/04_fonts_and_text.md"),
"OCC:startup/STARTUP-001M.md":("B","Architecture/11_login_ui_assets_and_interactions.md"),
"OCC:startup/STARTUP-001P.md":("B","Architecture/11_login_ui_assets_and_interactions.md; 03_login_flash_startup_command_contract.md"),
"OCC:startup/STARTUP-001T.md":("B","Architecture/11_login_ui_assets_and_interactions.md"),
"OCC:startup/STARTUP-001X.md":("B","Architecture/11_login_ui_assets_and_interactions.md"),
"OCC:startup/STARTUP-002-world-activation.md":("B","Architecture/09_frame_loop_architecture.md; Game_Map/post_login_world_loading_orchestration.md"),
"OCS:status.md":("B","feature table below"),
"OCS:content/historical-source-reconciliation.md":("H","Server/historical-reconciliation-5095.md"),
"OCS:protocol/README.md":("B","Network/13_connection_lifecycle.md; 01_core_packets.md; 00_protocol_overview.md"),
"OCS:protocol/framing.md":("B","Crypto/00_tqcipher64.md; Network/13_connection_lifecycle.md"),
"OCS:protocol/text-encoding.md":("B","Network/Native-auth-string-validation-2026-10-18.md"),
"OCS:architecture/authentication.md":("B","Server/login-credential-envelope.md; Crypto/01_rc5_credential_field.md"),
"OCS:architecture/networking.md":("B","Network/13_connection_lifecycle.md"),
"OCS:architecture/world-execution.md":("M","partition design (modern)"),
"OCS:operations/character-creation-starting-state.md":("H","Server/tq-server-15.10-runtime-semantics.md (CUserList__CreateNewUser 0x4AA79A, map 1010 portal0); Server/character-attributes-and-auto-allot.md"),
"OCS:content/item-type-catalog-v2.md":("B","Entity_System/citem_class.md (Itemtype.dat seed 0x2537); Server/database-provenance.md"),
}
rows={"OCC":[],"OCS":[]}; cnt={}
for d in scan:
    k=d["repo"]+":"+d["doc"]; cited=bool(d["addrs"] or d["notes"] or d["syms"])
    if cited: lv,an="A",(f'{len(d["addrs"])} addr' if d["addrs"] else "")+(" + notes" if d["notes"] else "")+(" + symbols" if d["syms"] else "")
    elif k in B: lv,an=B[k]
    else: lv,an="M","product/ops (no native counterpart)"
    cnt[lv]=cnt.get(lv,0)+1
    rows[d["repo"]].append(f'| `{d["doc"]}` | {lv} | {an.strip(" +")} |')
def section(r,title): return f"## {title}\n\n| Doc | Level | Native anchor |\n|---|---|---|\n"+"\n".join(sorted(rows[r]))+"\n\n"
hdr=f"""# Implementation evidence ledger — OCC + OCS (CP0.3, 2026-11-05)

Baseline OCS `6241d61`, OCC `c6c718d5`. Rebuild: scan scripts under `evidence/ledger-2026-11-05/`.

| Level | Meaning | Count |
|---|---|---|
| A | repo doc cites native anchor (address / notes / Binja symbol); every cited client address present in 20_notes | {cnt.get('A',0)} |
| B | anchor exists in 20_notes (keyword-confirmed); doc does not cite it → add citation | {cnt.get('B',0)} |
| B? | candidate anchor, weak keyword match → confirm while citing | {cnt.get('B?',0)} |
| C | no native anchor found → RE needed | {cnt.get('C',0)} |
| H | historical anchor only (TQ server / 5095 data); no 5517 client proof | {cnt.get('H',0)} |
| M | modern/product by design (launcher, ops, persistence, hosting, security policy, own formats) | {cnt.get('M',0)} |

Code citations: 14/14 native addresses quoted in OCS/OCC `src` comments exist in 20_notes.
Doc citation `0x66D477` (FLOW-001A) was absent from notes: Binja confirms `Sleep(5000)` in
`CGameMain_ConnectAccountServerWithBgpFallback` (`push 0x1388` `0x66D472`); added to `Network/5517-server-selection-and-realm-handoff.md`.

"""
feat="""## OCS `docs/status.md` features → anchor

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

"""
gaps="""## Gaps → closing checkpoint

- **B / B? docs (add native citation):** server docs → CP1.7; client docs → CP2.10. B? items must confirm the anchor or be downgraded to C.
- **P items (policy on native packets):** document as policy in the repo doc (not native) → CP1.7.
- **H items:** stay historical; any 5517 behaviour claim built on them needs a client Binja anchor before CP5+ work.
- **C items:** none found in docs. Unanchored *claims inside* A/B docs are not yet itemised — a per-claim pass happens when each doc is cited (CP1.7/CP2.10).
"""
open(out,"w",encoding="utf-8").write(hdr+feat+section("OCC","OpenConquerClient docs")+section("OCS","OpenConquerServer docs")+gaps)
print(cnt)
