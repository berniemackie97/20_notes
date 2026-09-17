# Conquer Online 5517 — client reverse-engineering notes

Reference documentation for the native 5517 Windows client, written to support a
faithful cross-platform reconstruction. Every claim here is meant to be traceable
to a native binary at a named address.

Primary subject: `CQ2ClientRelease-42.0.1` (`Conquer.exe`), Win32 PE, MFC42,
code range `0x401000`–`0x83E428`, 18,983 functions. See
[01_architecture_overview.md](01_architecture_overview.md) for the binary-level
summary, folder census and singleton map.

## Evidence policy

The v5517 native binaries and clean v5517 assets are authoritative. Nothing else
overrides them.

- Managed tests are evidence only when their expected values were independently
  established from those sources.
- Two legacy source trees sit outside this repository and are **directional leads,
  not truth**: `/Volumes/EnderChest/Development/Repos/GameDev/Remakes/Conquer/Servers/Sources/ZfServer/`
  and `/Volumes/EnderChest/Development/Repos/GameDev/Remakes/Conquer/Servers/Sources/魔域/`.
  The `魔域/soul-code` subtree is older client C++ that can corroborate class and
  method names; its action IDs, layouts, constants and behaviour must be
  independently confirmed in a v5517 binary before use. `ZfServer` corroborates protocol and data lineage but never overrides
  contradictory client evidence.
- Client and server agreeing on a value proves nothing — both can share a wrong
  assumption. Only the 5517 binary settles a question.

[Tooling/reference_binary_provenance.md](Tooling/reference_binary_provenance.md)
records what each reference binary and source tree can and cannot prove.

## Document conventions

- **Heading 1 is the subject.** The line under it is metadata — the translation
  unit, the binary, or the verification date. Sections start at heading 2.
- **Addresses are absolute and backticked**: `0x764BC6` for `Conquer.exe`,
  module-relative for DLLs (`c3_core_dll.dll` `0x1000BAE0`). A bare address with
  no named module means `Conquer.exe`.
- **Struct fields are written as offsets**, `+0x18`, or `object+0x18` where the
  base matters. Sizes are given in hex to match the disassembly.
- **"Verified" means disassembled**, with the address that proves it. A claim
  without an address is a lead, and says so.
- Links between documents are relative. Links into the rest of the repository are
  relative to the document, not to the repository root.

## Map

### Protocol

[Network/](Network/README.md) — the wire protocol, packet by packet, plus
connection setup and transport crypto.
[Crypto/](Crypto/README.md) — the cipher primitives the transport and the login
envelope are built from.

### Game logic

[Entity_System/](Entity_System/README.md) — `CRole`/`CPlayer`/`CHero` and the
item and NPC classes hanging off them.
[Game_Map/](Game_Map/README.md) — the world map, radar, terrain formats and
post-login world load.
[Server/](Server/README.md) — the contract a server must satisfy, derived from
client behaviour. Written against `50_server/OpenConquerPublic`.

### Presentation

[Rendering/](Rendering/README.md) — the whole render stack, from the EXE's call
sites down through `graphic.dll`, `c3_core_dll.dll`, `GraphicData.dll`,
`Role3D.dll` and `RoleView.dll`.
[Sound/](Sound/README.md) — `NDsound.dll` export surface and map sound, including
where the managed port models the wrong class.

### Process and provenance

[Architecture/](Architecture/README.md) — startup chains, the frame loop, and the
managed solution's own structure.
[Tooling/](Tooling/README.md) — what each reference binary proves, and the
translation units recovered from `Conquer.exe`'s assert strings.

[_archive/](_archive/README.md) holds retired working files. Nothing there is
maintained or citable.

## Known rough edges

- `Network/` skips 16 and 17, and `Network/MsgUserInfo1006-semantic-closure-2026-09-17.md`
  keeps its date-stamped name deliberately: that exact filename is cited inside
  Binary Ninja comments in `Conquer.exe.bndb` and in
  `10_work/docs/NATIVE_MSGUSERINFO_1006_5517.md`. Renaming it would desync the
  database.
- `Architecture/07`, `08` and `10` are managed-side refactor records rather than
  native findings. They are kept here for continuity with the slices that produced
  them.
