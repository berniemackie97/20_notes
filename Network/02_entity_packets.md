# Entity Packets — NPC, Entity, Monster, Names

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## MsgBattleEffectiveness (Type 1032) — class proven by `MsgBattleEffectiveness.cpp` assert (CP0.1 2026-11-05); former label `MsgNpcInfo` withdrawn
**Direction**: S→C
**Purpose**: NPC entity information
**Dispatch**: Create `CMsgNpcInfo__Create` (0x75E304), parse `CMsgNpcInfo__Parse` (0x75E36A), process `CMsgNpcInfo__Process` (0x75E38D)

**Parse**: `CMsgNpcInfo__Parse` — standard header validation, then `type == 1032`.

**Verified field usage in `CMsgNpcInfo__Process`** (offsets relative to packet start):
- `+4` is compared to the local player ID from singleton `+204`. If it matches, the handler compares `+8` against a vtable call at offset `+184` on the singleton object and asserts on mismatch.
- If `+4` does not match the local player ID, `+4` is used to look up an entity via `EntityManager__FindEntityById`, and a vtable call at offset `+188` is invoked with `+8`.

## Type 1033 — class unproven; label `MsgNpcInfoEX` withdrawn (`MsgNpcInfoEX.cpp` asserts are in the type 1109 handler; CP0.1 2026-11-05)
**Direction**: S→C
**Purpose**: Extended NPC information (server time sync, mode-based data)
**Dispatch**: Create `CMsgNpcInfoEX__Create` (0x74A4E6), parse `CMsgNpcInfoEX__Parse` (0x74A54C), process `CMsg1033__Process` (0x74A5E6)

**Parse**: `CMsgNpcInfoEX__Parse` — standard header validation, then `type == 1033`.

**Verified field usage in `CMsg1033__Process`** (offsets relative to packet start):
- `+4` is treated as a `u8` mode selector.
- If `+4 == 0`: the handler reads seven 32-bit fields and fills a `tm` struct:
  - `+8` -> `tm_year`, `+12` -> `tm_mon`, `+16` -> `tm_yday`, `+20` -> `tm_mday`,
    `+24` -> `tm_hour`, `+28` -> `tm_min`, `+32` -> `tm_sec`.
  - The handler computes time deltas using `timeGetTime()` and `mktime()` and calls `CHero__SetTimeOfDaySync`, `CHero__SetServerEpochSec`, `CHero__SetTimeSyncClientTick`.
- If `+4 == 2`: passes `+8` (u32) to `CHero_SetMountVigor` (hero `+0x2DA8`, current steed vigor; the only writer) — see [movement eligibility](../Server/movement-eligibility-5517.md#mount-and-vigor-client-proven).
- If `+4 == 3`: passes `+8` (u32) to `CMsgNpcInfoEX__SendType3` after `s__GetSingletonPtr_5DF90A`.
- If `+4 == 4`: passes `+8` and `+12` (u32/u32) to `CMsgNpcInfoEX__HandleType4` after `s__GetSingletonPtr_5DF90A`.

## Type 1034 — class unproven; label `MsgTaskDialog` withdrawn (`MsgTaskDialog.cpp` asserts are in the type 2032 handler; CP0.1 2026-11-05)
**Direction**: S→C
**Purpose**: Quest/task dialog system
**Dispatch**: Create `CMsgTaskDialog__Create` (0x75DF38), parse `CMsgTaskDialog__Parse` (0x75DF9E), process `CMsgTaskDialog__Process` (0x75DFC1)

**Parse**: `CMsgTaskDialog__Parse` — standard header validation, then `type == 1034`.

**Verified field usage in `CMsgTaskDialog__Process`** (offsets relative to packet start):
- `+4` (u32) copied into a local `v19[0]` passed to `CItemInfoEntry__Dtor`.
- `+8` (u32) and `+12` (u32) passed to `CItem__InitFromUIDAndItemId`; `+12` (item_id) is also used as a nonzero gate for the main branch.
- `+16` (u16) passed to `CItem__SetWord_0x194`.
- `+18` (u16) copied into the dialog object (`v20`) at `+84` (word).
- `+20` (u8) used as a mode selector; if `== 2` or if `+12 == 0`, the handler exits early via `RefPtr__Reset`.
- `+21` (u8), `+28` (u8), `+29` (u8), `+36` (u8), `+37` (u8), `+38` (u8), `+39` (u8), `+40` (u8) copied into various fields of the dialog object (`v20`).
- `+24` (u32) passed to `CItem__SetDword_0x14C`.
- `+32` (u32) copied into the dialog object (`v20`) at offset `+92` (dword).
- `+44` (u32) copied into the dialog object (`v20`) at offset `+368` (dword).
- `+48` (u16) passed as a boolean into `CItem__SetByte_0x1AD`.
- `+50` (u16) passed to `CItem__OrDword_0x1A0`.
- `+52` (u16) passed to `CItem__SetRoleViewTextureVariantSelector`.
- `+56` (u32) copied into a local `v19[7]`.
- `+60` and `+80` are treated as null-terminated strings (both passed to `strlen` and `ByteBuffer__AppendRange`).
- `+76` (u32) copied into a local `v19[6]`.
- `+100` (u32), `+104` (u32), `+108` (u32) copied into locals `v19[1]`, `v19[2]`, `v19[5]`.

## MsgName (Type 1015)
**Direction**: Bidirectional
**Purpose**: Name/string operations (fireworks, guild names, etc.)
**Dispatch**: Create `CMsgName__Create` (0x73ECC9), parse `CMsgName__Parse` (0x73EE2B), process `CMsgName__Process` (0x73EFDF)

**Parse**: `CMsgName__Parse` — standard header validation, then `type == 1015`.

**Verified field usage in `CMsgName__Process`**:
- `packet+4` is used as an entity ID (passed to `EntityManager__FindEntityById` for lookup).
- `packet+8` is a sub-type selector (switch on `*(uint8_t *)(packet+8)`).
- String list is read via `MsgStringList__GetEntry` from the list object at `this+0x408` (same list format as MsgTalk/MsgUserInfo).

## Type 1112 (class unproven; label `MsgMonsterTransform` withdrawn — `MsgMonsterTransform.cpp` asserts are in the 1042 handler `0x761D5C`)
**Direction**: S→C
**Purpose**: Writes two hero-side display strings from packet values (decimal id string + SynMgr lookup string).
**Dispatch**: Create `CMsg1112__Ctor` (0x75EBFC), parse `CMsg1112__Parse` (0x75EC62), process `CMsg1112__Process` (0x75EC85)

**Parse**: `CMsgMonsterTransform__Parse` — standard header validation, then `type == 1112`.

**Verified field usage in `CMsgMonsterTransform__Process`** (offsets relative to packet start):
- `+4` (u32) not read in this handler.
- `+8` (u32) `value_num` (formatted with `"%d"` into a decimal string).
- `+12` (u32) `syn_lookup_id` (passed to `SynMgr__LookupString_6C5DE4` with local hero word `0x874`).

**Verified processing flow**:
- Resolves local hero singleton (`s__GetSingletonPtr_404460`) and uses block base `hero + 0x12DC`.
- Formats `value_num` using format string `"%d"` and copies it to hero string field at `hero + 0x12DC + 28` (`0x12F8`) via `ByteBuffer__AppendRange`.
- Reads local hero value `CHero__GetWord_0x874()`, resolves name string via `SynMgr__LookupString_6C5DE4(hero_word_0x874, syn_lookup_id)`, and copies it to hero string field at `hero + 0x12DC + 52` (`0x1310`) via `ByteBuffer__AppendRange`.
- No window message post or additional side effects in this handler.

## MsgHero (Type 1114)
**Direction**: S→C
**Purpose**: Applies movement/action updates for one or more entity IDs (direction-only, directional step action, or absolute-position action).
**Dispatch**: Create `CMsgHero__Create` (0x7624E8), parse `CMsgHero__Parse` (0x76254E), process `CMsgHero__Process` (0x762571)

**Parse**: `CMsgHero__Parse` — standard header validation, then `type == 1114`.

**Verified packet layout used by `CMsgHero__Process`** (offsets relative to packet start):
- `+4` (u8) `subtype` (switch key: `0`, `1`, `2` handled in this build).
- `+6`:
  - subtype `0/1`: packed direction byte.
  - subtype `2`: tile `x` (`u16`).
- `+7`:
  - subtype `1`: action variant byte (`0 -> action_type 22`, non-zero -> `23`).
- `+8`:
  - subtype `2`: tile `y` (`u16`).
- `+12` (u32) `entity_count` (loop bound).
- `+16` (u32 array) entity ID list (`entity_count` entries).

**Verified subtype behavior in `CMsgHero__Process`**:
- `0` (`CMsgHero__ProcessSubtype0_SetDirectionList`):
  - Iterates entity ID list; for each existing entity from `EntityManager__FindEntityById`, calls `CRole_SetDirectionFromPacked8(entity, packet[+6])`.
- `1` (`CMsgHero__ProcessSubtype1_DirectionActionList`):
  - Computes `gate_enabled = CHero__IsDword_0x2EEC_Equal3(local_hero) && CHero__CheckState2EECAndEntityFlag_6647BD(local_hero)`.
  - For each entity ID:
    - If entity is missing: sends `CMsgAction` with type `102` targeting that entity ID.
    - If entity exists:
      - Normalizes direction: `packet[+6] %= 8`.
      - Initializes action struct via `CRoleAction__ZeroInit_64D033`.
      - Sets action type `22` or `23` from `packet[+7]`.
      - Sets action direction from `packet[+6]`.
      - If gate is enabled and entity ID equals either local hero ID or `CHero__GetDword_0x2EE0(local_hero)`, suppresses action application for that entity.
      - Local-hero entity path:
        - Reads current local tile, applies direction deltas, and calls `CHero__UpdateMapInfoFromTiles(new_x, new_y)`.
        - If not suppressed: sets action field `[15] = 2` and applies via `CRole__ApplyActionWithQueue_6720EE(local_hero, action)`.
      - Non-local entity path (not suppressed): applies action via target entity vfunc `+128`.
- `2` (`CMsgHero__ProcessSubtype2_PositionActionList`):
  - Uses the same gate/suppression logic as subtype `1`.
  - For each entity ID:
    - If entity is missing: sends `CMsgAction` type `102`.
    - If entity exists:
      - Initializes action struct via `CRoleAction__ZeroInit_64D033`.
      - Sets action type `20`.
      - Sets action tile coordinates from `*(u16*)(packet+6)` / `*(u16*)(packet+8)`.
      - Local-hero entity path updates local map via `CHero__UpdateMapInfoFromTiles(x, y)`.
      - Applies action (same local-vs-remote split as subtype `1`) unless suppressed by gate.
- Other subtype values in this build return without action processing.

**Verified direction delta tables (used by subtype `1` local-map update)**:
- `dx[8]` at `0x86D5FC`: `{0, -1, -1, -1, 0, 1, 1, 1}`.
- `dy[8]` at `0x86D61C`: `{1, 1, 0, -1, -1, -1, 0, 1}`.
