# World entry: map identity and the 10014 gate

From the 2026-08-23 smoke test of the reconstructed client against OpenConquerPublic.
All 5517 behaviour below is from Binary Ninja on `Conquer.exe`; `eosource` is one
revision earlier and is used for names and intent only, never as proof.

**Current validation (2026-08-29):** the managed client completed the account `1055` handoff,
authenticated its game connection, consumed `1004/2078/2079/1006/1110/1016/10010`, sent the
enter-map ladder, enabled the world-frame gate, and loaded map data id 1010 against the current
OpenConquerPublic server. A reported failure to leave login could not be reproduced after restarting
the current build and server processes; no client code change was made for that report.

**Native correction (2026-09-15):** the `TitleLabel` name in the historical predicate below
was incorrect. Packet 2078 is account last-login timestamp/location/alert data; packet 2079
selects a status-UI state. Neither is checked before native `1006` builds/sends action 74.
The legacy rewrite now records these updates independently, removes their receipt from
bootstrap readiness, and preserves the native 2079 global on unsupported state values and
bootstrap reset. The server's working `(0,0,empty text)` / state `0` bytes and order are retained.
These choices do not establish retail-server policy. See the
[2078/2079 native audit](../Network/10_extended_packets.md#successful-existing-character-login-audit-2026-09-15).
The earlier smoke-test report remains historical evidence, not a new native-client run.

## Symptom

Client reaches the world-entry boundary, then fails with
`status='SERVER OFFLINE', detail='game-bootstrap-timeout'`. Server-side the last line is
`Sent world-entry rung GetItemSet ... rows=0`.

## Where the historical build stalled

Not in the ladder. The reconstructed client blocks in
`CLoginStartupSubmitLoginRequest.TryReceiveInitialGameHandoff`, looping on
`TryWaitForNextDecodedPacket` until `ClientWorldBootstrapState.IsInitialWorldBootstrapReady`:

```
AnswerOk && TitleLabel && ServerState && UserInfo && SentClientEnterMap
  && ServerEnterMap && MapInfo1110 && Weather1016 && HasReceivedPlayerSpawn10014
```

The trace carries 1004, 2078, 2079, 1006, 1110, 1016, 10010 — eight of nine.
`HasReceivedPlayerSpawn10014` never sets.

## The server must not send a self-spawn

`CMsgPlayer__Process` (0x755F64) compares the packet's entity id against the hero's
before anything else:

```
00755f8d  cmp  ecx, edx        ; packet entity id vs CHero+0xCC
00755f8f  jne  0x755fa3        ; different -> normal spawn processing
00755f91  push ecx
00755f92  push 0x949b58        ; "Got a player with hero id! %u"
00755f97  call Debug_LogMessageToDailyFileWithDedup
00755f9e  jmp  0x7572c5        ; -> epilogue, return
```

`3drole/Network/MsgPlayer.cpp` is the same code with the log commented out:

```cpp
if (m_pInfo->id == g_objHero.GetID())
{
    //::LogMsg("Got a player with hero id! %u", m_pInfo->id);
    return;
}
```

The legacy OpenConquer5517v3 server did send one (`GameLoginWorldBootstrapService`
line 54, `SendSpawnAsync(character, direction: 0)`), which is why it appeared to be
required. It is not: the native client discards it. We do not send it, and
`TheBurstSendsNoSpawnForTheLocalCharacter` pins that.

**Correction to an earlier reading of this seam.** `MsgPlayer.cpp` also contains
`if (g_objGameMap.m_idDoc == 1010) return;` — "disable other player in newbie map". That
is *not* a disabled map; the player plays there normally and only other players' spawns
are hidden, giving Birth Village an instanced feel. More importantly the rule is **gone
from 5517**: `CMsgPlayer__Process` contains no reference to 1010 (0x3F2). 5517 gates
instead on a per-packet byte at `body+0xB2` combined with `sub_62071e`, which is an OR of
six CGameMap flag predicates (`sub_620785`, `sub_6207A8`, `sub_6207CB`, `sub_620693`,
`sub_62080F`, `sub_6206AC`) — `sub_6207CB` being the same `JumpForbidden` bit
(`0x0200_0000`) the jump handler uses. Do not carry the 1010 rule into the rewrite.

## World entry completes on the enter-map action alone

`MsgAction.cpp`, `actionEnterMap`:

```cpp
case actionEnterMap:		// map info end
{
    extern unsigned int g_uStatus;
    g_uStatus = _STATUS_NORMAL;
    //m_pInfo->idUser is map id
    MYASSERT (g_objGameMap.Create(m_pInfo->dwData));
    g_objHero.SetPos(nPosX, nPosY);
    g_objHero.SetAlignPos(nPosX, nPosY);
    g_objHero.SetDir(m_pInfo->unDir);
    ...
    MYASSERT (msg.Create(g_objHero.GetID(), 0, 0, 0, actionGetItemSet));
    msg.Send();
}
```

`g_uStatus` goes `_STATUS_LOGIN` (MsgConnect) → `_STATUS_NORMAL` here. That is the
login→world transition, and it depends only on the 0x4A response. No 10014 participates.
`CMsgUserInfo__Process` (0x764276) confirms the other end of the ladder: it finishes by
building `actionEnterMap` and sending it, asserting on
`msg.Create(g_objHero.GetID(), 0, 0, 0, actionEnterMap)` from `MsgUserInfo.cpp`. It posts
0xD39, 0x501, 0x403, 0x451 and 0xC74, and never 0x483.

So the reconstruction's 9-flag conjunction over-constrains: a solo login can never satisfy
`HasReceivedPlayerSpawn10014`. The fix is client-side — drop that flag from the
conjunction. Keep it and `HasIgnoredLocalHeroSpawn10014` as observations.

## Two real server bugs found on the way

### MsgMapInfo (1110) `+8` is the map data id, not spare

`CMsgMapInfo1110__Process` (0x732B10):

```
00732b74  CGameMap_ApplyMapIdAndRefreshWorldState(CGameMap*, *(body + 4)) ; -> +0xE0
00732b89  CGameMap_SetMapDocumentId(CGameMap*, *(body + 8))               ; -> +0xE4
00732ba1  CGameMap_SetFlags64(CGameMap*, *(body + 0xC), *(body + 0x10))
```

`MsgMapInfo.cpp` names them:

```cpp
g_objGameMap.SetID(m_pInfo->idMap);
g_objGameMap.SetIDDoc(m_pInfo->idDoc);
g_objGameMap.SetType(m_pInfo->dwType);
```

`CGameMap_ApplyMapIdAndRefreshWorldState` writes `+0xE0` and drives the refresh chain (conditional
force flag `+0x2E4`, tile region, ambient media, component projection) even when the ID repeats.
`CGameMap_SetMapDocumentId` is a bare setter for `+0xE4`. We were
sending `0` for `idDoc`. No 5517 reader of `+0xE4` has been identified, so this was
probably inert in this build, but both writers of the field otherwise agree on one value
and sending zero left it self-contradictory until the enter-map action repaired it.

### MsgAction 0x4A wire `+8` is the map data id, and we sent the map id

Both `CGameMap_CreateFromDataId` call sites in `CMsgAction__Process` are identical:

```
006ff46d  mov  ecx, dword [esi+0x404]   ; body = wire packet incl. 4-byte header
006ff473  push dword [ecx+0x8]
006ff478  call CGameMap_CreateFromDataId
```

`CGameMap_CreateFromDataId` (0x61DA1F) resolves that value to a GameMapInfo record
(`"GameMapInfo (%u) not found at %s, %d"`), `strncpy`s the record's path, calls
`CGameMap_LoadMapFileFromRelativePath`, and stores `arg1[0x39]` = `CGameMap+0xE4`.

Note the revision drift: eosource uses `m_pInfo->dwData` (union at struct +18) while 5517
reads wire +8. Our own layout already places `ParameterPair` at wire +8 — matching the
reconstruction's `MsgAction10010PacketReader` and the observed 38-byte packet — so only
the value was wrong.

`cq_map` has **27 rows where `mapdoc <> id`** (1052→1082, 1217→1075, 1219→1212, 1300→1001,
1927→1762, 4021→2021, …). Birth Village is 1010→1010, which is why the smoke test did not
expose it. On any of those 27 maps the client would have failed to find its map file.

## Changes made

- `IMapDataCatalog.TryGetMapDataId` on `GameMapAssetCatalog`, backed by the `MapDefinition`
  rows it already loads (`_flagsByMapId` became `_definitionsByMapId`).
- `MsgMapInfo1110.Encode(mapId, mapDataId, flags)` — the second slot now carries `idDoc`.
- `MsgAction10010.EncodeEnterMap(entityId, mapDataId, …)`.
- `EnterMapActionHandler` resolves the data id and refuses world entry with an error log
  when the map is not in the catalog, rather than guessing.

Still open and unrelated to this seam: overlay collision, mount jump cap, and the
unverified `cq_map.type` bits beyond `JumpForbidden`. Entity spawn and interest
management landed 2026-08-28 — see [entity-visibility.md](entity-visibility.md).
