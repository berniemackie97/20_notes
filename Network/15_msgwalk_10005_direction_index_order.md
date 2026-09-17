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
