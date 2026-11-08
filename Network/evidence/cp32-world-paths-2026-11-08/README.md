# CP3.2d active world wire paths

Source audit from [OCC main](https://github.com/berniemackie97/OpenConquerClient/tree/3f38c69c5251011765a895bc15c59f0ae8d3e336) and [OCS main](https://github.com/berniemackie97/OpenConquerServer/tree/8b0f0745332a29530d046a44104ccf6d2914e62a). Scope begins after world activation. [Login and bootstrap audit](../cp32-bootstrap-paths-2026-11-08/README.md) covers earlier paths. Evidence references refer to [the original 5517 VM captures](../cp32-world-entry-2026-11-08/README.md). This audit made no new VM capture.

## Active routes and evidence

OCC WorldFrameIngress owns one prefetched receive from GameServerHandshakeSession.ReadWorldFrameAsync and drains up to 32 frames per tick through ClientWorld and GameWorldPacketDispatcher. WorldFrameEgress is the only production caller of post-activation send methods. It writes 1009/27 and conditionally 1037 through the secured session. SendWorldWalkAsync and WriteOrdinary exist and are tested. A production source search found no caller of SendWorldWalkAsync.

OCS GameConnectionWorkerPool.RunSessionAsync owns one read loop. WorldSessionGameplay, WorldVisibilityService and WorldConnectedPortalTransferCoordinator publish through the session's serialized write boundary, directly or via the visibility mailbox. The logical frames use the same GameSecuredFrameWriter as entry. No separate hand-built gameplay framing path was found in this scope.

| ID and direction | Production routes | Evidence and gaps |
|---|---|---|
| 10005 C→S and S→C | OCS verifies owner, paces and commits movement, then echoes the original fields to the mover and eligible observers. Rejected motion can produce 108. OCC applies ordinary local-hero echoes to its tile and direction, and reports foreign or selector-9 frames as unhandled. Its own ordinary writer has no production caller. | 23 exact native requests, 12 selector 1 and 11 selector 0. Each peer echo is byte-identical. Remote application and mounted selector 9 were not observed. [OCC #250](https://github.com/berniemackie97/OpenConquerClient/issues/250) |
| 1009/27 C→S and S→C; 1037 C→S | OCC pumps the heartbeat from ClientWorld, observes echo +16, and adds the address report at the 30-minute gate when an address exists. OCS echoes a valid 88-byte 1009/27. It skips 1037 through the unsupported frame path. | Exact native heartbeat and controlled echo. The address report was outside the capture window and contains a local address. Managed raw-timer fix is tracked separately. [OCC #299](https://github.com/berniemackie97/OpenConquerClient/issues/299) |
| 10010/108 S→C; /100 and /146 C→S | OCS creates 108 on a paced rejection or qualified position mismatch. Its GamePositionReport parser takes X/Y from +8 and reconciles against authoritative state. It never echoes either report. OCC applies local-hero 108 using +24/+26 and sends no 146. | Full native 146 response shape below. 108/146 were outside these VM runs. [OCC #263](https://github.com/berniemackie97/OpenConquerClient/issues/263) |
| 10010/137, /79, /81 C→S and S→C | OCS parses jump, facing and pose separately, validates ownership and pacing, then sends accepted movement/action to the mover and visibility recipients. Rejected jump can produce 108. OCC's world action handler only consumes 108. | Source-only for these variants in the VM trace. [Jump #251](https://github.com/berniemackie97/OpenConquerClient/issues/251) · [Facing and emote #252](https://github.com/berniemackie97/OpenConquerClient/issues/252) |
| 10010/85 C→S; /86 and 1110 S→C | OCS processes a connected portal transfer. WorldVisibilityService queues 86/1110 together before destination spawns and removes old-map visibility. OCC consumes 1110 during bootstrap. Post-activation 86/1110 fall through unhandled paths. | Source-only for portal traffic. [OCC #253](https://github.com/berniemackie97/OpenConquerClient/issues/253) |
| 10010/102 C→S; 10014 and 10010/135 S→C | OCS validates a 102 query against the authenticated requester and responds with an eligible visible subject's spawn. Visibility entry/movement can also emit 10014. Exit or relocation emits 135. OCC has no world handler for 10014 or 135 and no 102 producer. | Source-only. Native unknown-mover query has separate static proof at CMsgEntityAction__Process. [OCC #249](https://github.com/berniemackie97/OpenConquerClient/issues/249) |
| 10010/145 C→S; 10017/25 and /11 S→C | OCS accepts ghost transition, updates authoritative status, and sends status/appearance rather than a 145 echo. Corpse admission can also send local status 25. OCC applies local attribute 25 and reports attribute 11 as unsupported. | Native 145 follows the controlled ghost stimulus. 10017/11 and /25 are peer-originated inputs applied by the retail client. [OCC #254](https://github.com/berniemackie97/OpenConquerClient/issues/254) |
| 10010/408 C→S; 1056 C→S | OCS validates 408 as a zero-field notification and sends no reply. Its 1056 route accepts 12-byte mode 2 for the authenticated hero, with no trade state or reply. OCC can emit 408 on a map bit-38 change during bootstrap. No production post-activation 408 or 1056 sender found. | Native 1056 length and ID observed after the status stimulus, metadata only. No 408 captured on flags-0 map. |
| 1004 C→S and S→C | OCS WorldChatPacketFactory and visibility routes handle local 2007/2000, whisper 2002 and role words 2104/2102, with policy and rate checks. Login-channel 2101 is handled before world activation. OCC has no active world-chat producer or dispatcher case. | World chat source-only. Previous 1004 captures are login controls. [OCC #255](https://github.com/berniemackie97/OpenConquerClient/issues/255) |
| 1008/1 and /3; 1009/3, /5, /6, /17, /46 S→C | OCC WorldHeroEquipment consumes item record add/update and item remove/equip/unequip/durability/active snapshot. Audited OCS producers for item records and /46 occur during bootstrap. No active post-activation OCS item mutation writer found. | Source-only for these variants. Empty test hero supplied no item records. |
| 10017 and 1016 S→C | OCC consumes local attributes 0, 1, 2, 3, 5, 7, 8, 10, 12, 22, 25, 27 and 43. It consumes valid weather and silently skips unsupported tuples. Audited world OCS attribute output is ghost look/status and corpse status at activation. Audited OCS weather output is clear during bootstrap. | Attribute 25 and valid/invalid weather observed using peer inputs. The trace did not exercise nonzero status high64 or other attributes. |
| 1115 S→C | WorldSession can send the OtherLogin farewell before disconnect. OCC has no world-specific 1115 handler. | Source-only. The enum's PasswordChanged value has no active sender in the audited path. |

The server rejects malformed chat, walk and trade frames in those typed routes. Unknown and unmatched 10010 cases reach diagnostic skip, apart from the validated ownership/state paths above. Client GameMessageBuffer handles the native fixed buffer boundary before dispatch. These source findings do not prove retail behavior for untested malformed transport or ordering cases.

## Native 10005 checks

The stored capture contains 23 original-client 24-byte frames and 23 exact controlled echoes. All carry synthetic hero 1000000, map ID 1010 and a nonzero tick. The first selector-1 frame has packed byte 70, selector 1 and normalized direction 6. The first selector-0 frame has packed byte 22 and normalized direction 6. The comparison rehashed every native logical packet. [Record-level verification](movement-verification.json)

In Conquer.exe view 9, Role_ProcessCommandStateAndCombatPackets obtains the current map ID and calls the millisecond timer at 0x65C69E–0x65C6AE. The ordinary sender adds 8 times rand modulo 31 to the facing value at 0x65C6B8–0x65C6BE. The mounted path uses selector 9 and adds 24 times rand modulo 9 at 0x65C75D–0x65C773. The builder at 0x740457 zeroes the message and writes one byte each at +4 and +12. The receiver compares the full selector with 9 and normalizes only the packed low byte with modulus 24 or 8. CMsgEntityAction_Send supplies a fresh tick at 0x7404F4–0x740500 only if the caller passed zero. No mounted frame was captured. The randomized ordinary padding is ignored by the verified receiver's modulo rule.

## Static proof of the 108 reply

In CMsgAction__Process, 108 resolves to the hero at 0x6FFCBF–0x6FFCD0. It reads unsigned tile words from +24/+26 at 0x6FFCEC/0x6FFCF3 and updates role and gate state through 0x6FFD21/0x6FFD31. There is no same-tile comparison or repeat suppression before the 146 builder and send at 0x6FFD80–0x6FFD8F. This is a static branch result. The later CP3.2e probe independently observed same-tile, changed-tile and exact-repeat replies, plus silent foreign-target paths. [Correction runtime evidence](../cp32-correction-2026-11-08/README.md)

The push of -1 at 0x6FFD5B survives CGameMap_GetSingletonPtr and CGameMap_GetMapId. Both return with plain RET. It is the tenth argument to CMsgAction_CreateExtended, which ends with RET 0x28. The current map ID is the ninth argument. EBX was zeroed at 0x6FED38 and is used for zero fields. The extended builder clears the buffer, reads the hero ID and facing passed by the caller, and uses a fresh timeGetTime when the timestamp argument is zero.

| Offset and width | Native reply value | Store |
|---|---|---|
| +0/+2 u16 | 38 / 10010 | 0x6FEA15/0x6FEA20 |
| +4 u32 | Local hero ID | 0x6FEA45 |
| +8/+10 u16 | Corrected X and Y | 0x6FEA92/0x6FEAA0 |
| +12 u32 | Zero | Reset buffer |
| +16 u32 | Fresh raw millisecond tick | 0x6FEA2D/0x6FEA38 |
| +20/+22 u16 | 146 / current hero facing | 0x6FEA78/0x6FEA6A |
| +24/+26 u16 | Zero | 0x6FEA4E/0x6FEA5C |
| +28 u32 | Current map ID | 0x6FEA85 |
| +32 u32 | 0xFFFFFFFF | 0x6FEAB0 |
| +36/+37 u8 | Zero flag and string count | Reset buffer |

The OCS GamePositionReport reader accepts the reply's 38-byte layout and reads the tile from +8. It does not trust the report to move a character. Keep the tile-change outcome and reply obligation distinct when evaluating same-tile corrections. Binary Ninja comments now cover the sentinel, reply call, both movement packers and the zero-tick fallback.

## Verification

.NET SDK 10.0.403, macOS arm64. Client World tests passed 244/244 after exposing the existing local retail fixture to the isolated snapshot. Protocol passed 635/635. GameServer first passed 859/860, then passed 860/860 on three full reruns. The failed test also passed in isolation. Its ChannelClosedException came from the test listener during normal host stop. Production socket impact is unverified. [OCS #216](https://github.com/berniemackie97/OpenConquerServer/issues/216)

[CP3.2d #302](https://github.com/berniemackie97/OpenConquerClient/issues/302) covers these source routes and static/runtime distinctions. Remaining wire variants and shared fixture integration stay open on [CP3.2 #248](https://github.com/berniemackie97/OpenConquerClient/issues/248).
