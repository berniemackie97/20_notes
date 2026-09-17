# Item Packets — Items, Equipment, Gems, Packages
## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Network\

---

## MsgItem (Type 1008)
**Direction**: S→C (action dispatch based on server-sent mode)
**Handler**: CMsgItem__Process (0x762AC3)
**Parse**: `CMsgItem__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1008`.

**Verified local-hero item ownership model**:
- `CHeroItem__TryAddInventoryItem` and `CHeroItem__FindItemByUid` operate on the inventory deque at `heroItem+0xE34`.
- `CHeroItem__TrackItemAtPosition` and `CHeroItem__GetTrackedItemRefByPosition` operate on the tracked-position map at `heroItem+0xF20` with tracked-position keys (`1..0x1D`).
- `CHeroItem__FindTrackedItemByUid` scans that same tracked-position map by item UID, and `CHeroItem__FindTrackedPositionByItemUid` returns the tracked-position key for a given item UID.
- `CHeroItem__GetEquipSlotItemRef` and `CHeroItem__SetEquipSlot` operate on the equip-slot ref table at `heroItem+0xE84` / stride `8`.
- `MsgItem` action handling mutates those hero item tables first; visible equipment appearance is derived afterward.

**Verified field layout (offsets from packet start)**:
- `+0` (u16) size
- `+2` (u16) type == `1008`
- `+4` (u32) item UID (passed to `CItem__InitFromUIDAndItemId` and `CHero__GetItemByUID`)
- `+8` (u32) item_id (passed to `CItem__InitFromUIDAndItemId`)
- `+12` (u16) → `CItem__SetWord_0x194`
- `+14` (u16) → `item+84` (word at `((WORD*)item)+42`)
- `+16` (u8) `action_type` (switch values `1..10`, `6` falls through default)
- `+17` (u8) → `item+86` (byte)
- `+18` (u8) container selector (used by actions `1/3/4` to route add paths)
- `+20` (u32) → `CItem__SetDword_0x14C`
- `+24` (u8) → `item+87` (gem_slot_1)
- `+25` (u8) → `item+88` (gem_slot_2)
- `+28` (u32) → `item+92` (dword at `((DWORD*)item)+23`)
- `+32` (u8) → `item+96` (byte)
- `+33` (u8) → `item+97` (`CItem+0x61`, ItemAdd secondary/addition level); immediately refreshes the `ItemAdd.ini` cache at `item+0x180`
- `+34` (u8) → `item+360` (stored as dword index 90)
- `+35` (u8) → `CItem__CanUpgrade`
- `+36` (u8) → `item+364` (`CItem+0x16C`, zero-extended enchantment life bonus)
- `+40` (u32) → `item+368` (dword index 92)
- `+44` (u16) → `CItem__SetByte_0x1AD(entry+44 != 0)`
- `+46` (u16) → `CItem__OrDword_0x1A0`
- `+48` (u16) → `CItem__SetRoleViewTextureVariantSelector`
- `+52` (u32) → `CItem__SetDword_0x160`
- `+56` (u32) → `CItem__SetDword_0x17C`
- `+60` (u32) → `CItem__SetTimerDuration` (seconds)
- `+64` (u16) → `CItem__SetDwordMin1_0x190`
- `+19`, `+26..+27`, `+37..+39`, `+50..+51`, `+66..` are not referenced in this handler.

`CItem__SetRoleViewTextureVariantSelector` writes the item-side selector at `item+0x19C`.
For the native special-case branch where `sub_67AD9A(item) == 0x0E`, it rewrites the stored
selector as `sub_67D75D(item) * 100 + sub_67CC54(item)` before returning.

The `+33` ItemAdd key and `+36` enchantment are not display-only metadata. The native
max-life path consumes ItemAdd payload word 0 for every non-broken equipped item and consumes
the `+36` enchantment for every such slot except steed slot 12.

Broken-state mutation is also exact: new MsgItem equipment objects set `CItem+0x1AC` only when
current durability `+12` is zero; action 3 update-existing writes 0 for positive durability and
1 for zero. CMsgTick subtype 17 always writes the incoming low word to current durability and
sets `+0x1AC` for a non-positive equipment update, but does not clear that byte on its positive
path.

**Action switch (`packet+0x10` as u8)**:
- `1`: Creates a new item, initializes from `+4/+8`, copies the fields above, sets `CItem__SetByte_0x165(1)`, then routes by `+18`. If `+18 != 0`, it tracks the item through `CHeroItem__TrackItemAtPosition` and refreshes UI (`0x445/0x446`). If `+18 == 0`, it tries `CHeroItem__TryAddInventoryItem` and posts `0x3EB`. If status flag `0x3F` is clear and the item passes the native socket-add predicate, it posts `0x4B9`. If the item passes the native socket/status notification predicate, it posts `0x4B3` with the item UID.
- `2`: Creates a new item, initializes from `+4/+8`, copies the fields above, sets `CItem__SetByte_0x165(0)`, then routes it into the verified hero singleton side container path.
- `3`: Finds an existing item by UID through `CHeroItem__FindItemByUid` (which falls back to `CHeroItem__FindTrackedItemByUid`), updates all fields above, then re-checks inventory-only membership via `CHeroItem__FindItemByUid(..., inventory_only=1)`. If the item is still in inventory, it posts `0x3EB`. Otherwise it reroutes through `CHeroItem__TrackItemAtPosition` using `+18` and posts `0x3FB/0x445/0x446/0x4F1`. This is an update-existing-item path, not a delete path. Native item removal uses `MsgTick (1009)` subtype `3`.
- `4`: Requires `+18 != 0`. Creates new item, initializes from `+4/+8`, copies the fields above, then routes through `ItemPosition_NormalizeEquipmentPosition` / `CRole__SetEquipSlotItem` and posts `0x432` if successful.
- `5`: Creates a new item, initializes from `+4/+8`, copies the fields above, sets `CItem__SetByte_0x165(1)`, then routes it through the verified special-add path. If the item passes the same socket/status notification predicate, it posts `0x4B3` with the item UID.
- `6`: default path (no handler observed).
- `7`: If the verified hero-side gate succeeds, dispatches the UID-driven follow-up operation for `+4` and returns.
- `8`: Creates a new item, initializes from `+4/+8`, copies the fields above, then routes it into the verified subsystem behind singleton `0x4B178A` and posts `0xC2C`.
- `9`: Creates a new item, initializes from `+4/+8`, copies the fields above, then routes it into the verified subsystem behind singleton `0x410729` and posts `0xDC2`.
- `10`: Creates a new item, initializes from `+4/+8`, copies the fields above, then routes it into the verified subsystem behind singleton `0x51D37B`.

---


## MsgFloorItem (Type 1037)
**Direction**: S→C (log only in this build)
**Purpose**: Logging‑only; no packet fields are processed beyond header logging.
**Dispatch**: Create `CMsgFloorItem__Create` (0x743F64), parse `CMsgFloorItem__Parse` (0x743FCA), process `CNetMsg__LogProcessMsg` (0x6DF2F6; shared logging handler)

**Verified parse behavior**:
- `CMsgFloorItem__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1037`.

**Verified processing behavior**:
- `CNetMsg__LogProcessMsg` only logs `"Process Msg:%d, Size:%d"` using the message header fields; no packet-specific fields are parsed.


## MsgMapItem (Type 1038)
**Direction**: C→S (NoopProcess on receive; outgoing solidify builder)
**Purpose**: Outgoing solidify/nonsuch‑solidify material list (target item UID + material item UIDs); incoming handler is a no‑op in this build.
**Dispatch**: Create `CMsgMapItem__Create` (0x717AFA), parse `CMsgMapItem__Parse` (0x717B60), process `CNetMsg__NoopProcess` (0x5AD9B1)

**Verified parse behavior**:
- `CMsgMapItem__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1038`.

**Verified processing behavior**:
- `CNetMsg__NoopProcess` decompiles to an empty function (no reads, no writes, no calls).
- In `CNetMsg__ProcessMsg` (0x6DEBA5), after `CNetMsg__ProcessMsg_Dispatch` returns a parsed message object, the engine calls `msg->vftable[4](msg, 0)` as the packet “Process” handler.
- In the `CMsgMapItem` vtable `CMsgMapItem__vtable (0x86C184)`, entry index `4` is `CNetMsg__NoopProcess` (0x5AD9B1), so incoming type `1038` packets are ignored in this build.
- `CMsgMapItem__Create` (0x717AFA) is referenced only from `CNetMsg__ProcessMsg_Dispatch` and the two outgoing send paths (solidify dialogs), consistent with a client→server packet whose server→client handler is empty here.

**Verified outgoing build path**:
- `CMsgMapItem__Build` (0x717B83) is called from:
  - `CDlgNonsuchSolidify__SendMapItem` (0x4D996C), which validates the target item via `CHero__GetItemByUID` and requires `CItem__GetTimeLimitFlag` before sending.
  - `CDlgSolidify__SendMapItem` (0x52833F), which sends the selected target item + material list for solidify.
- The material list passed to `CMsgMapItem__Build` is the dialog’s item‑UID vector; `CDlgNonsuchSolidify__ClearMaterials` (0x4DA0FB) and `CDlgSolidify__ClearMaterials` (0x5283A6) iterate the same vector and release each UID via `PostMainWndMsg_0x464(0x4C7, uid)`.
- `CMsgMapItem__Build` sets:
  - `+4` (u16) = `a4` (mode selector),
  - `+6` (u16) = `0` (reserved; payload buffer is zeroed in `CMsgMapItem__Create` via `CNetMsg__InitPayloadBuffer`),
  - `+8` (u32) = `a2` (target item UID),
  - `+12` (u32) = count = `(a3[1]-a3[0]) >> 2`,
  - `+16...` = array of u32 item UIDs copied from `a3[0..count-1]`,
  - `+2` (u16) = type `1038`,
  - `+0` (u16) = size = `20 + 4*count`.

**Field semantics** (offsets from packet start):
- `+4` (u16) mode:
  - `0` = solidify request from `CDlgSolidify__SendMapItem`.
  - `1` = nonsuch solidify request from `CDlgNonsuchSolidify__SendMapItem`.
- `+6` (u16) reserved (always `0` in this build).
- `+8` (u32) target item UID.
- `+12` (u32) material count.
- `+16..` array of material item UIDs.


## MsgGemEmbed (Type 1027)
**Direction**: C→S (NoopProcess on receive; outgoing gem embed/takeout builder)
**Purpose**: Client request to embed/take out a gem from an equipment slot.
**Dispatch**: Create `CMsgGemEmbed__Create` (0x7533AE), parse `CMsgGemEmbed__Parse` (0x75347E), process `CNetMsg__NoopProcess` (0x5AD9B1)

**Verified parse behavior**:
- `CMsgGemEmbed__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1027`.

**Verified processing behavior**:
- Process handler is `CNetMsg__NoopProcess` (no-op).

**Verified outgoing build path**:
- `CMsgGemEmbed__Build` (0x753414) is called from:
  - `CHeroItem__SendGemEmbed` (0x6DC5A2): validates both item/gem UIDs via `CHero__GetItemByUID`, requires slot `1` or `2`, then builds the request with `action = 0` (embed).
  - `CHeroItem__SendGemTakeout` (0x6DC68A): validates item UID, requires slot `1` or `2`, then builds the request with `gem_uid = 0` and `action = 1` (takeout).
- `CMsgGemEmbed__Build` writes:
  - `+4` (u32) = hero ID (`this->GetID()` from the `CHeroItem` owner),
  - `+8` (u32) = target item UID,
  - `+12` (u32) = gem UID (0 when taking out),
  - `+16` (u16) = slot index (1 or 2),
  - `+18` (u16) = action (0 = embed, 1 = takeout).


## MsgPackage (Type 1039)
**Direction**: S→C
**Purpose**: Warehouse/package operations (verified by warehouse/inventory handlers in `CMsgPackage__Process`).
**Dispatch**: Create `CMsgPackage__Create` (0x72B91E), parse `CMsgPackage__Parse` (0x72B9DA), process `CMsgPackage__Process` (0x72BA6C)

**Verified parse behavior**:
- `CMsgPackage__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1039`.

**Verified field usage in `CMsgPackage__Process`** (offsets relative to packet start):
- `+4` (u32) is a mode selector:
  - `0`: reads two strings from the list object at `this+0x408` (indices `0` and `1`, length `0x20`), calls `CHero__SetNpcProtectId(+8)`, shows `CMessageBoxMgr__ShowCommandMessageWithParam(3442, +16, "CONFIRM_NPC_PROTECT", ArgList)`, then `PostMainWndMsg_0x464(0xD96, +32)`.
  - `4–6`: calls `CMessageBoxMgr__ShowMessage("CONFIRM_NPC_PROTECT")` then `PostMainWndMsg_0x464(0xD8B, 0)`.
  - `9`: reads a string (index `0`) from the list object, builds a small struct with `+60` and `+16`, then calls `PostMainWndMsg_0x464(0xD8A, struct_ptr)`.
  - `10`: calls `PostMainWndMsg_0x464(0xD8B, 0)`.
- `+8` (u32) is passed to `CHero__SetNpcProtectId` in mode `0`.
- `+16` (u32) is passed to `CMessageBoxMgr__ShowCommandMessageWithParam` in mode `0` and stored into the struct in mode `9`.
- `+32` (u32) is passed to `PostMainWndMsg_0x464(0xD96, ...)` in mode `0`.
- `+60` (u32) is stored into the struct in mode `9`.


## Account Authentication Response (Type 1055; former MsgSuitStatus alias)
**Direction**: AccountServer → Client
**Purpose**: Login success grant and GameServer redirect, or login failure. The old item/suit classification was incorrect; this section remains here for existing references.
**Dispatch**: `CMsgAccountAuthResponse__Ctor` (0x7548A3), `CMsgAccountAuthResponse__Parse` (0x754909), `CMsgAccountAuthResponse__Process` (0x75492C)

**Verified parse behavior**:
- `CMsgAccountAuthResponse__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1055`.

**Verified field usage in `CMsgAccountAuthResponse__Process`** (offsets relative to packet start):
- `+4` (u32) is the primary gate. If `== 0`, an error path builds UI text and returns via `MFC__SetDword_0x4(+8)`. If nonzero, it is written to singleton `+2716` and used in follow‑on calls.
- `+8` (u32) is an error code when UID is zero; otherwise it is authenticationKey, stored by `CHero__SetLoginAuthKey` at CHero+0x2F5C. The wrapping sum with UID XOR 0x4321 is a stack-local cookie, not a checksum.
- `+16` (u32) is an additional session field stored at CHero+0xAA0 and forwarded by alternate 1203.
- The derived `key ^ cookie` rekeys outbound legacy tables after mode 2 is selected. Those tables are unused by standard GameServer send/receive. [Verified native consumer audit](/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/20_notes/Network/14_session_derived_legacy_cipher_mask.md).


## MsgDetainedItem (Type 1102)
**Direction**: S→C
**Purpose**: Detained‑item package sync (add/remove/update items; timeout notifications).
**Dispatch**: Create `CMsgDetainedItem__Create` (0x74E08A), parse `CMsgDetainedItem__Parse` (0x74978C), process `CMsgDetainedItem__Process` (0x74E158)

**Verified parse behavior**:
- `CMsgDetainedItem__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1102`.

**Verified handler prelude**:
- The handler gets `CPackageMgr` via `CPackageMgr__GetSingletonPtr`.
- It looks up a package via `CPackageMgr__FindPackageByIdAndType(+4, +9)`. If null, it calls `CPackageMgr__EnsurePackageByIdAndType(+4, +9)` and then retries the lookup.
- If the package is still null, it logs an error (`"CPackage"` assert) and returns.

**Packet fields used by `CMsgDetainedItem__Process`** (offsets relative to packet start):
- `+4` (u32): package key A (passed into `CPackageMgr__FindPackageByIdAndType` and `CPackageMgr__EnsurePackageByIdAndType`).
- `+8` (u8): mode selector.
- `+9` (u8): package key B (passed into `CPackageMgr__FindPackageByIdAndType` and `CPackageMgr__EnsurePackageByIdAndType`).
- `+12` (u16): used only by mode `3` (written into package field `+0x34`).
- `+16` (u32): used only by mode `2` (item UID to remove).
- `+20` (u16): item count for modes `0`, `1`, and `5`.
- `+24` (varies): entry list base for modes `0`, `1`, `5`; item UID for mode `4`.
- `+28` (u32): used only by mode `4` as fallback `item_id` for the timeout message.

**Mode behavior** (`mode = *(u8*)(+8)`):
- `0`: Bulk add. Loops `count = *(u16*)(+20)` and parses a 52‑byte entry at `+24 + i*52` for each item, builds a `CItem`, and inserts it into the package via `CPackage__AddOrReplaceItem`. Posts `PostMainWndMsg_0x464(0x3F7, 0)` after the loop.
- `1`: Single add. Requires `count != 0`, uses the first entry at `+24`, builds a `CItem`, inserts it into the package, then posts `PostMainWndMsg_0x464(0x3F7, 0)`.
- `2`: Remove by UID. Calls `CPackage__RemoveItemByUID(*(u32*)(+16))`, then posts `PostMainWndMsg_0x464(0x3F7, 0)` and `PostMainWndMsg_0x464(0x4B5, uid)`.
- `3`: Writes `*(u32*)(package + 0x34) = *(u16*)(+12)` via `CPackage__SetDword_0x34`, then posts `PostMainWndMsg_0x464(0x3F7, 0)`.
- `4`: Timeout notification. Looks up item UID at `+24`. If found, formats `"StrItemTimeOut"` using `CItem__GetEffectiveId`. If not found, queries item data using `item_id = *(u32*)(+28)` and formats the message from that record. In both cases it shows the `"ItemTimeout"` UI, removes the item via `CPackage__RemoveItemByUID(uid)`, and posts `PostMainWndMsg_0x464(0x3F7, 0)` and `PostMainWndMsg_0x464(0x4B5, uid)`.
- `5`: Durability update. Loops `count` entries; for each `uid = *(u32*)(entry+0)`, if the item exists in the package it updates:
  - `CItem__SetDwordMin1_0x190(*(u16*)(entry+44))`
  - `CItem__SetWord_0x194(*(u16*)(entry+46))`
  - `*(u16*)(item + 84) = *(u16*)(entry+48)`
  - Posts `PostMainWndMsg_0x464(1015, 0)` for each updated item.

**Entry layout for modes 0/1/5** (52 bytes at `+24 + i*52`):
- `+0` (u32) → `CItem__InitFromUIDAndItemId` arg `uid`.
- `+4` (u32) → `CItem__InitFromUIDAndItemId` arg `item_id` (loads CItemData record).
- `+8` (u8) → copied to `item+86` (byte).
- `+9` (u8) → copied to `item+87` (gem_slot_1).
- `+10` (u8) → copied to `item+88` (gem_slot_2).
- `+12` (u32) → copied to `item+92` (dword).
- `+16` (u8) → copied to `item+96` (byte).
- `+17` (u8) → copied to `item+97` (level byte, used by `GetLevel_Byte`).
- `+18` (u8) → copied to `item+360` (stored as dword at index 90).
- `+19` (u8) → passed to `CItem__CanUpgrade`.
- `+20` (u16) → copied to `item+364` (dword at index 91).
- `+22` (u16) → copied to `item+368` (dword at index 92).
- `+24` (u16) → `CItem__SetByte_0x1AD(entry+24 != 0)`.
- `+26` (u8) → `CItem__OrDword_0x1A0`.
- `+27` (u8) → `CItem__SetRoleViewTextureVariantSelector`.
- `+28` (u32) → `CItem__SetDword_0x14C`.
- `+32` (u32) → `CItem__SetDword_0x160`.
- `+36` (u32) → `CItem__SetDword_0x17C`.
- `+40` (u32) → `CItem__SetTimerDuration` (seconds).
- `+44` (u16) → `CItem__SetDwordMin1_0x190`.
- `+46` (u16) → `CItem__SetWord_0x194`.
- `+48` (u16) → copied to `item+84` (max durability).

**Other per‑item operations for modes 0/1**:
- After copying `+16/+17`, the handler calls `CItem__UpdateAddStatsFromItemIdAndLevel` to recompute the 4‑dword add‑stat array at `item+384`.
- It clears `item+0x1A0` via `CItem__AndNotDword_0x1A0(-1)` before OR‑ing `entry+26`.
- It sets `item+0x165` to `1` via `CItem__SetByte_0x165`.


## CMsgItemStatus (Type 2048)
**Direction**: S→C
**Wire type**: 2048 (0x0800)
**Create**: `CMsgItemStatus__Create` @ `0x6E702E`
**Process**: `CMsgItemStatus__Process` @ `0x6E70E7`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Synchronises item amount and status flags for inventory, warehouse, and equipment items.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2048 |
| +4 | 4 | itemUID | Item unique ID (used to look up item across hero inventory, package manager, and equipment) |
| +8 | 1 | mode | Action mode (0–4) |
| +9 | 1 | statusFlags | Item status bitmask — written to item field 0x1A0 via `CItem__OrDword_0x1A0` (modes 0/1/3 only) |
| +12 | 4 | amount | New amount value — passed to `SetAndFormatAmount` (modes 0/1/2/3) |

### Mode Behaviour

| Mode | Description | UI Messages |
|------|-------------|-------------|
| 0 | Update hero inventory item: look up by UID, set amount, apply status flags, refresh UI. If the item passes the native socket/status notification predicate, post `0x4B3`; otherwise post `0x4B5` | 0x4BA (pre-update), 0x4AB (refresh), 0x4B3 or 0x4B5 |
| 1 | Same as mode 0 (identical code path) | Same as mode 0 |
| 2 | Update warehouse item: look up by UID, set amount. Also checks secondary warehouse slot (`CWarehouse__GetCurrentItem`) — if UID matches, updates that too. | 0xD08 (warehouse refresh), 0xDCA (secondary update) |
| 3 | Remove/zero item: look up by UID, set amount to 0, apply status flags. Formats game data string 11191 with effective item ID and posts as notification. | 0x4AA (notification text), 0x4B5 (item update) |
| 4 | Simple UI signal: posts 0x4B7 with no item lookup. | 0x4B7 |

### Item Lookup Order
For modes 0/1/3, the handler searches three sources in order:
1. `CHero__GetItemByUID` — hero inventory
2. `CPackageMgr__FindItemByUID` (0x6AA0DD) — package/storage
3. `CHero__FindEquippedItemByUID` (0x667B5B) — equipment slots

Mode 2 uses the same three-source lookup plus an additional warehouse check via `CWarehouse__GetCurrentItem` (0x685DCE).

---
**Verified world-entry bootstrap implication**:
- native `CMsgAction__Process` subtype `0x4A` immediately sends client `MsgAction 0x4B (GetItemSet)` after the enter-map side effects complete.
- the verified local-hero equipment hydrate path on the receive side is `MsgItem (1008)` action `4`, which routes through `ItemPosition_NormalizeEquipmentPosition` and `CRole__SetEquipSlotItem`.
- `MsgItem` action `1` is still the generic add/create path, but it mutates the same hero item tables through `CHeroItem__TryAddInventoryItem` / `CHeroItem__TrackItemAtPosition`; it is not the dedicated equip-slot hydrate branch used by the touched world-entry slice.
- managed server timing correction for this seam:
  - do not push login-time `MsgItem (1008)` rows directly from the post-`1006` connect bootstrap.
  - wait for the verified client `MsgAction 0x4B (GetItemSet)` request first.
  - evidence for the managed fix:
    - BNinja verifies the client request ladder `0x4A -> 0x4B -> 0x4C -> 0x4D -> 0x4E -> 0x61`.
    - managed packet trace captured `ServerToClient 1008` create rows before the client's `0x4B`, proving the old server ordering was wrong.
  - managed correction applied in the server branch:
    - preload the session item table during login if needed for state,
    - but emit those same `1008` rows only on the `0x4B` handler leg.

**Verified visual-source split for action `4`**:
- `CMsgItem__Process` action `4` (`Conquer.exe:0x762D15..0x762D68`) stops after:
  - `ItemPosition_NormalizeEquipmentPosition(packet+0x12)`
  - `CRole__SetEquipSlotItem(j_CHero_GetSingletonPtr()+0x1EA0, normalizedSlot, item, itemRefHandle)`
  - `PostMainWndMsg_464(0x432, 0)`
- that branch does **not** call `CHeroItem__SetEquipSlot` and does **not** call
  `CHero__RefreshEquipmentDerivedStats`.
- the verified local-hero writers that actually push slot-derived visual inputs into the
  role / RoleView state remain `CHeroItem__SetEquipSlot` (`0x6DA906`), especially:
  - slot `1` -> `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView`
  - slot `3` -> `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView`
  - slot `4` -> `CRole__SetRightWeaponVisualInputsAndRefreshRoleView`
  - slot `5` -> `CRole__SetLeftWeaponVisualInputsAndRefreshRoleView`
  - slot `9` -> `CRole__SetSharedBodyHelmetVariantLookupSourceAndRefreshRoleView`
  - slots `12/17` -> `Role_UpdateMountActionScaleCacheFromSources`
- managed parity consequence: local-hero item-table hydrate and local-hero appearance /
  RoleView projection are two separate native seams. Do not treat action `4` as proof that
  the visible role-state projection must already have refreshed in the same handler.
