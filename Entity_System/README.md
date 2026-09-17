# Entity system — index

The entity class hierarchy as it exists in `Conquer.exe`:

```
CRole (base entity, ~1088 bytes)
  └── CPlayer (rendered entity with nameplate, ~2636 bytes)
        └── CHero (local player singleton, ~12300 bytes)
```

`CItem`/`CItemData` and `CNpc` are separate hierarchies.

- [crole_class.md](crole_class.md) — `CRole`, the base entity.
  `3DRole\Role.cpp`, assert string at `0x93E950`.
- [cplayer_class.md](cplayer_class.md) — `CPlayer`, rendered entity with
  nameplate. `3DRole\Player.cpp`, assert string at `0x93FED8`.
- [chero_class.md](chero_class.md) — `CHero`, the local player singleton.
  `3DRole\Hero.cpp`, assert string at `0x93F114`. The largest document here.
- [croleaction_class.md](croleaction_class.md) — `CRoleAction`, the entity
  action/command processor. Also `3DRole\Role.cpp`.
- [citem_class.md](citem_class.md) — `CItem` and `CItemData`.
  `3DRole\Item.cpp` / `ItemData.cpp`.
- [cnpc_class.md](cnpc_class.md) — `CNpc`. Reconstructed from
  `3DRole\Network\MsgNpcInfo.cpp`.
- [role_visual_construction.md](role_visual_construction.md) — what the client
  builds after `MsgUserInfo` (1006) arrives for the local hero. The bridge from
  entity state to [../Rendering/](../Rendering/README.md).

Entity IDs partition the space: players are `1`–`999,999`, NPCs
`0x61A81`–`0x7A120`, monsters `0x7A121`–`0x927BF`.
