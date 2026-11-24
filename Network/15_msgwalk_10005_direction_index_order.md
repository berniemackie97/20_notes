# `10005` Walk Direction Index Order (5517)

Source: `Conquer.exe` BNinja database.

## Verified native tables

The client-side ground-move path does **not** use an east-first direction table.

Verified from:

- `Role_CommandType03_UpdateMotionPathAndSelectAction` (`0x7350B3`)
- `Role_ApplyGroundMoveActionAndPoseFromPathCursor` (`0x736315`)

Both functions index these two native tables:

- `data_86C608` for X deltas
- `data_86C628` for Y deltas

Verified contents:

| Direction index | X delta | Y delta |
|---:|---:|---:|
| `0` | `0` | `+1` |
| `1` | `-1` | `+1` |
| `2` | `-1` | `0` |
| `3` | `-1` | `-1` |
| `4` | `0` | `-1` |
| `5` | `+1` | `-1` |
| `6` | `+1` | `0` |
| `7` | `+1` | `+1` |

## Why this matters

Our server walk handler had been decoding `10005` direction indices with an east-first table:

- `0=(+1,0)`
- `1=(+1,+1)`
- `2=(0,+1)`
- `3=(-1,+1)`
- `4=(-1,0)`
- `5=(-1,-1)`
- `6=(0,-1)`
- `7=(+1,-1)`

That does **not** match the native 5517 client.

When the client autopaths with `10005` walk packets, the server can drift to the wrong tile if it
uses the wrong table. Screen/NPC visibility then updates around the wrong authoritative server
position, which matches the observed symptom:

- NPCs disappear during autopath/walk
- NPCs reappear after jump

Jump recovery makes sense because jump handling uses explicit target coordinates instead of
reconstructing the next tile from a direction index.

## Server implication

For opcode `10005` one-tile ground movement, the server should reconstruct the next tile using the
native 5517 direction-index order above, not an east-first compass ordering.

## Remote movement dispatch

Verified November 8, 2026 against original 5517 `Conquer.exe`, SHA-256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`. The raw PE
bytes agree across the clean, loader and Binary Ninja input copies. Analysis view
`Conquer.exe.bndb` (9), `CMsgEntityAction__Process` at `0x7405E7`.

- `0x740602` reads the low packed-direction byte at +4. `0x740606` compares the low
  selector byte at +12 with 9 (`80 79 0C 09`). Selector low byte 9 uses modulo 24,
  command `0x18`, and tables `0x86C804` / `0x86C864`. Other selectors use modulo 8
  and tables `0x86C7C4` / `0x86C7E4`. The low selector byte 1 chooses command
  `0x17`, otherwise `0x16`. The native receive branch treats `0x00000109` like 9.
  This static operand-width canary is outside the normally captured selector 0/1 cases.
- At `0x740667`, the resolver takes the actor dword at +8. The local fallback
  applies the existing gate tile and acknowledgement timestamp path. An unresolved
  foreign actor goes through action 102 query construction at `0x740729`.
- For a resolved actor, `0x74078F` checks ID > 999999. For those IDs, states
  `0x20` and `0x21` exit at `0x7407A8` without issuing the movement command.
- `Role_IsHeroOwnedPetEntity` is called at `0x7407AD`. A true result advances the
  offset-qualified tile pair `CRole+0xA88/+0xA8C` with the decoded delta
  (`0x7407BF`–`0x7407D2`). A false result initializes a 0x11C-byte command block
  at `0x7407D9`. It stores type at +0 and normalized direction at +0x28, then
  passes the block by pointer to role vtable+0x80 at `0x740810`.
- This receive proof does not establish interpolation, playback cadence, or
  end-to-end behavior. Verify those separately on the player presentation path.
  The observed 0/1 frames pin ordinary direction examples. The low-byte canary
  is instruction-derived and does not authorize broadening server ingress.

### Remote step presentation

Verified November 20, 2026, `Conquer.exe.bndb` (9) and `RoleView.dll.bndb` (126).
Remote players use role class vtable `0x86AEEC`.

| Stage | Native behaviour | Anchor |
|---|---|---|
| Ingress | vtable+0x80 = `Role_HandleIncomingActionStateBatch`. For types 0x0F..0x18: erase queued types 4..0xB/0xD/0xE/0x19, then, if the effective command is idle-class, commit the motion in progress (frame:=count, cursor:=end, tile from cursor), then `push_back` the block. Not applied here. | `0x6720EE`, label `0x672276` |
| Commit | `Role_RecomputeCoordinateGateCacheFromProjectedPosition`: `+0x1A8=+0x1AC`, `+0x350/+0x354=+0x19C/+0x1A0`, tile `+0x318/+0x334` from cursor. | `0x64E9A5` |
| Snap on arrival | `Role_CommandType16/17` set progress `+0x1EC=6` when the step starts; effective command then reads 5 (`0x64DDF8`). The next arriving step therefore snaps an unfinished step to its end. | `0x7365D8`, `0x736ACB` |
| Tick | `Role_TickCommandStateAndDispatchPlayback`: when vtable+0x58 reports the current motion complete, pop one queued block, apply it, run +0x84, dispatch. While a motion runs, queued walks wait. | `0x672662..0x6726E0` |
| Step staging | `Role_ApplyGroundMoveActionAndPoseFromPathCursor`: start `+0x194/+0x198` = current cursor `+0x350/+0x354`; end `+0x19C/+0x1A0` = projection of (cursor tile + `g_RoleMoveDirection8TileDelta[dir]`). | `0x73631C` |
| Action | 0x16: last physical action `+0x398` ∈ {110,120} → 111, else 110. 0x17: `+0x398`==121 → 120; ==120 → 121; else 120. `+0x398` init −1 (`0x64D307`); updated only for physical-set actions (`0x64E870`). | `0x736329`, `0x736AEC` |
| Timing | `+0x1AC` = RoleView+0x0C return (clip frames); `+0x1B4` = now; `+0x1B8` = `Role_ComputeFrameIntervalFromAction` = 25 ms for 110/111/120/121 ([13](../Rendering/roleview_dll/13_role_compute_frame_interval.md)). `+0x24` overrides when >0; init 0 (`0x64D2D1`), not written by 0x16/0x17. | `0x64E665`, `0x64E6ED..0x64E6FD` |
| Frame | `+0x1A8 = (now − start + interval/2) / interval` (unsigned, rounded), capped at count. | `0x64EB0C`, `0x64EB70` |
| Position | Easing key = RoleView key 0x1E = body composite of current action; low four digits = action id (`PlayerRoleView_BuildCurrentBodyMotionLookupKey`, RoleView `0x10002D35`). ActionCtrl.ini records end in 0340/0342/0344/0346/0370/0915/0916/0917/0919; lookup transforms keep the low four digits or force 9999 ([easing](../Rendering/gamedata_dll/01_action_control_motion_easing.md)). Ground walk/run: no record → linear: `start + roundHalfStep(delta·min(now−start,total)/total)` (`0x768AA1`, see [easing](../Rendering/gamedata_dll/01_action_control_motion_easing.md)), `total = max(frames·interval,1)`. Snap to end when `+0x1A8 ≥ +0x1AC`. | `0x64EE59..0x64EED4` |
| Queue drain | Motion done, queue empty: `Role_CommandType05` sets action 100, copies cursor into both endpoints. | `0x7335BA..0x7335D6` |
| Depth tile | Mid-step (action ∈ {110,111,120,121}) registers at tile of start point if `+0x17C ≤ 3`, else end point. | `0x672784` |

| Rendered frame | `RoleView+0x04(0x0A, role+0x1C ≥ 0 ? role+0x1C : +0x1A8)`; `+0x1C` init −1 → rounded `+0x1A8`. Forwarded unchanged to `I3DRole+0x50` → mesh `+0x4C`; C3 sampler clamps. No action cross-fade (`ActionTransition.ini` empty). | `0x64FA33..0x64FA4B`, RoleView `0x10002756` |
| Standby loop | Drain dispatches 100 from frame 0; interval 66 ms (100..103 fallback); same rounded frame; completion → `+0x84` → `Role_CommandType05` re-dispatches 100 from frame 0. | `0x73351E`, `0x672662` |
| Idle variants | Each Type05 dispatch while command type `+0x1E8 == 5` (never commanded): `rand()%10 == 1` → `101 + rand()%3` (`Conquer_GetRandomModuloWithOptionalTimeReseed`, no reseed). Then `+0x30C ≠ 0` → 0x1F5 (0x1F6 in window) or window `now − +0x37C < 10000` → 0x12C (alert). `+0x37C` = last-attack tick, stamped for actions 0x191..0x194 (`0x7334EF`). Interval 66 ms. eosource `CRole::StandBy`/`GetJumpHeight` match these rules (orientation). | `0x73350D..0x7335A4`, `0x769250`, `0x6E4FA1`, `0x733499` |

Open: `+0x24` writers outside init and 0x16/0x17 not enumerated; native 10014 replacement of a role mid-step not traced.

### Remote jump presentation

Verified November 20, 2026, `Conquer.exe.bndb` (9), `RoleView.dll.bndb` (126); constants read from PE bytes.

| Stage | Native behaviour | Anchor |
|---|---|---|
| Ingress | MsgAction 137, remote role: command `0x14 + (pkt+0x24 != 0)`, block `+0x20/+0x24` = u16 target X/Y from `pkt+8/+0xA`; vtable+0x80 queues it like a walk (types 0x0F..0x18). | `0x700352..0x7003DE` |
| Staging | 0x14: action `0x82` (`0x1FE` with status 0x1B). 0x15: `0x2C9` with status 0x32, else `0x82`. Direction `Role_SelectDirectionIndexTowardTile`; start = cursor; end = projected target tile. Progress 6. | `0x73597B`, `0x7358DB` |
| Direction | `Role_SelectDirectionIndexTowardTile` = v of `Direction_Select8WayFromDelta(target − tile)`: dx=0 → dy>0?0:4; dy=0 → dx>0?6:2; else `sign(dx)·dy·100` in `[−241,−41,41,241]·\|dx\|` buckets → 5/6/7 (dx>0) or 1/2/3 (dx<0), none → dy>0?0:4. Standing facing after landing uses it. | `0x61E478`, `0x6E4ACC` |
| Interval | `_ftol(base·dist·(1/300) + 1.0)`, unsigned floor 33; `dist` = start/end screen distance; base 33 for 0x82 ([13](../Rendering/roleview_dll/13_role_compute_frame_interval.md)). | `0x64DEF4..0x64DF50` |
| Stretch | Clip frames < cap (20; mounted `0x86A9FC` table) and `+0xEC` untransformed: interval = `_ftol(ceil(I·(cap−0.5)/(frames−0.5)))`. | `0x64E727..0x64E7E2` |
| Position | Linear (ActionCtrl has no 0130 record); completes on the rounded frame like walks. | `0x64EE59` |
| Facing | `role+0x1C == −1`: `−270 − _ftol(atan2(endY−startY, endX−startX)·57.29578)` degrees. | `0x64F6FB..0x64F749` |
| Arc | `Map_ComputeMotionArcScreenHeightOffsetFromProjectedPoints`: peak = first max tail elevation on the rounded line (source excluded); `adj(t)` = tail − base; `apex = _ftol(dist/3 + adjPeak) + 20`; apex point = midpoint (peak projection is overwritten, dead); nearer half: `_ftol(sin(dCur·π/max'(dMid)·0.5)·(apex − adjEnd) + adjEnd)`. Null start/end/peak entry → 0. | `0x6505B3` |
| Line | Dominant axis k = 1..max(\|dx\|,\|dy\|), ties Y-dominant: minor = `minor0 + trunc((2·dMinor·k + sMinor·aDom)/(2·aDom))`; `s = d>0 ? 1 : −1`. | `0x620171` |
| Tail | Base = cell elevation (`int16`). Per terrain-object group in map order, per object (anchor = group anchor + object offset), per cell (x,y), index `w·y+x`: tile = anchor − (x,y); tail = `int16(tail + delta)`. Out-of-grid entries null; null tail = 0. | `0x635FC5`, `0x63F4D3`, `0x644856`, `0x61D9C8` |
| Transform | `terrainDelta = adj(cursorTile) − arc`; RoleView+0x10 `(projX, projY − terrainDelta − arc, terrainDelta, facing, scale)`; non-project camera stores `2·terrainDelta`: `Scale · Translate(0,0,elev) · RotZ`. Status 0x1B skips the arc. | `0x64F6BB`, `0x64F811`, RoleView `0x1000329A` |

Correction: the previous arc comment placed the apex at the peak tile when `adjPeak > adjStart`; the instructions always use the midpoint.

### Managed gait verification

On November 9, 2026, OCC main `08396ebef644ff61fb0e82b0b6c99cf50aba7c41`
passed 317 world tests with retail content. A separate CPU-side probe used the
same `PackagedClientContentSource` and `WorldRoleAssetReader` as the actual
client. Actions 110 and 111 each decoded 20 frames for unarmored body families
1, 2, and 4, and 21 for family 3. Armored body families 2 and 4 with item type
130003 also decoded 20 frames for both actions. The production playback clock
alternated the actions, advanced frames at 25 ms, and stopped at the decoded
clip end. An initial loose-only harness could not read packaged meshes. The
normal packaged source resolved all six tested appearances. This establishes
managed asset and clock behavior. GPU playback and live peer/native comparison
remain open under OCC #250.

The [November 9 GPU probe and archive reconciliation](../Rendering/evidence/peer-world-verification-2026-11-09/README.md) verifies walk/run drawing and records the constructed selector-width discrepancy on the merged client.

The [connected managed peer run and retail GPU replay](evidence/cp42-managed-peer-2026-11-09/README.md) verifies canonical 0/1 across current OCC and OCS mains. The retained OCS relay frames are classified separately from original 5517 packets.

## Local hero command and sender contract

**Proven (static instructions; November 23, 2026 follow-up).** The generic-role
sender at `0x74353F` is not the hero's virtual callback. The hero constructor
writes vtable `0x86AD08` at `0x655730`; its +0x80 slot points to `0x65C079`,
+0x84 to `0x65C0F5`, and +0x58 to `0x64EAB2`.

- Hero +0x80 applies the supplied command through `0x64DD38` after coordinate
  bookkeeping. The accepted 0x11C-byte block is copied to hero+0x1E8.
  **Do not generalize the remote-role queue to local input.**
- Hero +0x84 selects the action, then its ordinary movement branch constructs
  packet 10005 with packed direction `direction + 8*(rand()%31)`,
  actor ID, selector 0 for actions 110/111 or 1 for 120/121,
  a sampled client timestamp, and the map object's +0xE0 identity field.
- The hero calls the builder at `0x740457`, which writes packed direction and
  selector as bytes into reset storage, actor/timestamp/map identity as dwords.
  The earlier generic-role builder at `0x740407` omits the latter two inputs.
- The role tick calls +0x84 and restarts presentation after the +0x58 completion
  path, or after the separately gated due-action path. This establishes the
  scheduling boundary; it does not establish a complete held-input cadence.
- The release helper at `0x76A7AB` only stores three globals (input value and
  coordinates). It is not itself a movement-stop routine. Its viewport
  consumer and all repeated-input/focus/transfer paths remain unresolved.

[Instruction evidence, verification and exact resume boundary](evidence/cp42-input-producer-2026-11-23/hero-command-followup.md).
This supplements the partial input trace; it does not close OCC #341 or establish
a new interactive capture. Server pace limits remain application policy, not
an observed original-server contract.
