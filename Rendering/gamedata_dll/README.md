# `GameData.dll` — index

Only one behaviour of this DLL is documented. `GameData.dll` supplies
`RoleDataQuery` and related lookups; the rest of its surface has not been worked.

- [01_action_control_motion_easing.md](01_action_control_motion_easing.md) —
  action-control motion easing.

## `ini/Common.ini` `[Playerface]` / `[Statuary]` (CP1.7, 2026-11-06)

`C3DRoleData__LoadCommonIniPlayerFaceAndStatuary` GameData.dll `0x10003CE3` (TU `3DRoleData.cpp`):

| Key | Field | Retail |
|---|---|---|
| `MaleFaceAmount` | `+0x04` | 107 |
| `FemaleFaceAmount` | `+0x08` | 95 |
| `WuSengFemaleFaceAmount` / `…SectionStart` | `+0x24` / `+0x28` | 5 / 299 |
| `WuSengMaleFaceAmount` / `…SectionStart` | `+0x2C` / `+0x30` | 5 / 108 |
| `FemaleFaceAmountOfVip` / `FemaleFirstFaceIDOfVip` | `+0x34` / `+0x38` | 20 / 325 |
| `MaleFaceAmountOfVip` / `MaleFirstFaceIDOfVip` | `+0x3C` / `+0x40` | — |
| `…OfVipWarriorMonk` (4 keys) | `+0x44..+0x50` | — |
| `[Statuary]` Leader/Assistant/SubLeader Scale, MaxLife | `+0x0C..+0x20` | — |

`ani/PlayerFace.Ani` defines `Face0..Face400` contiguously. Female base face ID is not stored in the ini; the
consumer that applies it is not traced (historical server: 201).

