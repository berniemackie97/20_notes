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
