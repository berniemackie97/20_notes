# Local movement input and packet producer: partial static contract

Verified November 23, 2026. Contributes to [OCC #341](https://github.com/berniemackie97/OpenConquerClient/issues/341); does not close it or authorize a production movement controller.

The [hero command follow-up](hero-command-followup.md) corrects the generic-versus-hero sender scope and local command ownership. Its proven/candidate/unresolved ledger is the current resume boundary.

## Authority and validation

Source executable SHA-256: `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`. Binary Ninja target: `Conquer.exe.bndb`, view 9. REA independently inspected the unmodified PE image with objdump; [identity evidence](rea-image-identity.json). This is static instruction evidence, not a new interactive or wire capture.

[Retained instructions](instructions.json) contain the original 13 full-function or explicitly filtered instruction transcripts plus 17 raw objdump ranges. The button-down excerpt omits unrelated interaction branches. Existing analysis names identify locations; their names are not independent proof of semantics. Shared exception-prologue lifting makes some pseudocode misleading, so conclusions below use instructions.

Run:

```sh
python3 verify.py /absolute/path/to/Conquer.exe
```

The initial run checked **957 instruction records with zero mismatches**. The follow-up expands the retained instruction and data checks; current counts are in [verification.json](verification.json). It also verified SHA-256 and producer-range consistency for **23 existing original-client 10005 emissions** in the November 8 corpus. These frames already existed; their input sequences were not recaptured or expanded. Results are retained in [verification.json](verification.json). Instruction agreement proves byte identity, not branch reachability, runtime timing or complete semantic correctness.

## Generic-role ordinary movement producer

`Role_SendCommandStartPacketsAndSelectAction` at `0x74353F` selects the current action before its movement branches:

| Condition | Packet construction | Instruction anchors |
| --- | --- | --- |
| Physical action 110 or 111 | actor ID from role+0xCC; direction from role+0x17C; packed = direction + 8 * (rand() % 31); selector 0 | 0x7437E3–0x7437F4, 0x74385E–0x7438A3 |
| Physical action 120 or 121 | Same packed producer; selector 1 | 0x7437F6–0x74384D |
| Random helper | modulus 31, reseed flag 0; helper returns rand() % modulus | calls 0x74382C / 0x743882; helper 0x769250 |

For an eight-way direction 0..7, the producer yields 0..247. The random portion occupies **bits 3..7 of the low byte**, not a separate high byte. This is static-derived production shape, not a mandate to reproduce a random sequence or reseed algorithm.

`CMsgEntityAction_CreateWithMoveModeFlag` at `0x740407` resets the packet, writes length 24 and type 10005, stores actor ID as a dword at +8 and packed direction as a dword at +4, and writes a boolean selector byte at +12. Reset clears the packet storage; the remaining selector bytes are initially zero. `CMsgEntityAction_Send` at `0x7404E1` fills a zero +16 timestamp with `Conquer_GetTimeGetTime` before forwarding to the generic sender.

This generic path does **not** establish the hero packet fields. The [hero follow-up](hero-command-followup.md) identifies the separate hero builder, its +20 field source and dispatch gate. Neither trace establishes a complete held-input cadence; do not substitute a fixed packet timer.

## Pointer projection

The scaled projection entry is `0x61E978`:

1. For positive screen dimensions, calculate screen midpoint using the signed integer half operation.
2. For each axis, form midpoint + truncTowardZero((pointer - midpoint) * globalScale / divisor).
3. Divisor at `0x61EDC3` is truncTowardZero(map+0x154 * map+0x140 / 100). Its inputs and globalScale lifetime need separate writer proof.
4. Clamped projection at `0x61D8E3` adds map+0x48/+0x4C before calling the unchecked inverse at `0x61D707`.
5. Unchecked inverse subtracts map+0x40/+0x44, then uses x/64 and y/32: tileX = R(x/64 + y/32), tileY = R(y/32 - x/64).
6. Clamp output X to 0..mapWidth-1 and Y to 0..mapHeight-1.

`R` is the helper at `0x768AA1`: t=trunc(v), u=trunc(v+0.5), result=(u>t ? t+1 : t). Negative values have unusual results; substituting Math.Round or floor(v+0.5) is unjustified. Integer intermediate overflow and all scale/configuration writers still need explicit implementation bounds.

At `0x5B23EA–0x5B242E`, status 0x3C selects an additional screen-coordinate reflection through `0x5DA73F` before scaled projection. This is a conditional path, not proof that every ground click uses that reflection. Do not infer HUD exclusion, DPI translation or full viewport behavior from this leaf projection.

## Press, modifiers and release

The shell message-map entry at `0x8685A0` has message 0x201 and handler `0x5AFEDF`; entry `0x8686C0` has message 0x202 and handler `0x5DB61E`. Message 0x200 at `0x868600` points to `0x5B9BEE`.

The down handler takes capture and passes an input code 1 plus coordinates to the viewport handler `0x6F0E17` before the later movement branches. Its complete interception contract remains untraced.

In the ground-target tail, after prior gates:

| Branch | Request |
| --- | --- |
| `0x5D91A2` returns true | Mounted charge path |
| Otherwise event flags bit 0x08 set | Jump request at 0x5B2468 |
| Otherwise flags zero, or the check-control state at shell+0x1407D8 is zero | Type 0x11 target request at 0x5B24D8 |
| Otherwise | Additional state branches choose type 0x12, type 0x13 or type 0x11 |

The helper at `0x5D91A2` calls GetKeyboardState and tests array byte 0x12 bit 0x80 (Alt). This identifies the tested key; it does not establish mounted eligibility or authorize mounted input.

Release handler `0x5DB61E` calls ReleaseCapture, `0x76A7AB(x,y,0)`, then `0x6F0E17(0,x,y)`; it calls the window default if the latter returns false. **No conclusion that releasing the pointer immediately cancels movement is supported.** The first helper's side effects and the held-command scheduler remain open.

Type 0x11 and 0x12 target request functions pass a 0x11C-byte command block via role vtable+0x80 after their gates. They can redirect into each other or jumping under statuses; they do not directly construct a 10005 packet. The hero applies accepted blocks immediately through its own +0x80 callback; the remote-role queue is a different path. See the follow-up below.

## Cross-repository boundary

GitHub main heads observed during this audit:

| Repository | SHA |
| --- | --- |
| OCC | cd02479394581d3dad23c6094fd39a0fae6af2e3 |
| OCS | a462d8016886f1f1d37560ef8303caa1a7bb3ff4 |
| 20_notes | ce3f2f2a19c91a47ea587c287e3bb4cf2961f458 |

Local product code inspected at OCC 5481724a673b9c549ba126c5f64d940711da6d84 and OCS eb7e8b0f8dc88ea1668b9aa395bf0a5816b73ca6. These are working branch heads; no claim is made that they are identical to current main.

OCC GameWalk10005 and OCS GameWalkPacket both decode ordinary low-byte direction modulo eight. OCC's existing ordinary writer accepts one packed byte and selector 0/1. OCS validates session identity and pacing before committing a step and echoing it. The newly identified packed producer fits the existing codecs; no codec or server admission broadening is justified. Server pacing remains an application security policy until compared with a proven client emission schedule. No product files changed.

## Parity order and next required proof

Audit the player flow in order: startup services and presentation → admission/loading handoff → first complete map/hero/HUD frame and audio ownership → world input and command execution → transfer/teardown. Issue numbers do not replace this order.

World ambience is still absent from OCC. Existing Sound/02_map_sound_path.md identifies the target build's load-once looping Type0F scenery sound; eosource's interval-driven MapSound class has different behavior. Do not import its timer model. First-world ambience can be scoped separately from full map transfer, but any such slice must own failed activation, disconnect and shutdown cleanup.

For movement, the next static trace must cover 0x6F0E17 interception, 0x76A7AB release/held state, queue dispatch through vtable+0x80, completion/interrupt scheduling, final +20 production, and focus/transfer teardown. Then use a controlled original-client session on map 1010: single click, hold stationary, drag while held, release mid-step, Shift/control/Alt branches, blocked tile, HUD click, focus loss, correction and transfer. Record screen/tile coordinates, actor states, ordered decrypted C→S logical frame hex, timestamps and per-frame hashes. Exclude authentication material. Pair with two OCC clients against the same OCS head before accepting the interactive slice.

The controlled runtime experiment was **not executed in this slice**. Do not close #341 or its implementation dependents from this evidence.

## Supporting references

The locally available eosource MyShellDlg.cpp shows a timer-driven ProcessMouseHold and different left-button release bookkeeping. It is historical orientation only. Preservation-CO-Client/docs/movement.md documents action and sound choices in another implementation; it does not prove 5517 pointer semantics. Existing 20_notes instructions and the source executable remain authoritative for this trace.

Two function comments were added or extended in the active Binary Ninja analysis to record the packed producer and release-handler boundary. No database save was requested.
