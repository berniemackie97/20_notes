# CP3.2 mission catalog admission and content evidence

2026-11-08. Scope is the existing-character 1134/3 evidence gate in [OCC #306](https://github.com/berniemackie97/OpenConquerClient/issues/306), under [CP3.2 #248](https://github.com/berniemackie97/OpenConquerClient/issues/248).

## Trigger and order

In retail 5517, 1004 channel 2101 queues the login text at `0x731945`. `CMyShellDlg_HandleLoginStatusSystemTalk` first drains available network messages at `0x5DCC6E`, then reads the queue and compares with `ANSWER_OK` at `0x5DCC93`. On success, shell initialization at `0x5DCC9D` reaches the single mission-catalog sender call at `0x5B9B80`. `CMsgUserInfo__Process` separately queues action 74 at `0x7648A3`, followed by 1151/2 at `0x7648E6` for body digit 2. If 1006 was dispatched during the login handler's receive pass, these sends precede the catalog. If 1006 is dispatched in a later pass, the catalog comes first. The ordering depends on dispatch, and a peer's completed write of 1006 alone does not establish when the client dispatched it.

For character creation, `CMyShellDlg_HandleCreateRoleStatusSystemTalk` reads the separate 2100 queue. Its `ANSWER_OK` branch calls the game bootstrap sender at `0x5DCE90`, which sends the standard 1052 proof again on the same connection at `0x6DF22C`. The subsequent 2101 `ANSWER_OK` is the catalog trigger. That sequence is static native proof. Both captured sessions used existing characters and had a single game-form 1052 each.

| Existing-character capture | Peer 2101 success and 1006 | Native output order |
|---|---|---|
| 1 | 13 and 16 | 74 at 17, 1151/2 at 21, catalog at 22–24, 75 at 26 |
| 2 | 9 and 12 | Catalog at 13–15, 74 at 16, 1151/2 at 20, 75 at 22 |

Capture 1 preserves only catalog lengths. Capture 2 preserves the three native logical packets after peer CAST5-CFB decryption and `TQClient` trailer validation. The peer frames are controlled inputs. These records prove both placements relative to outbound 74 and 1151/2. [World-entry capture and provenance](../cp32-world-entry-2026-11-08/README.md)

## Asset, dataflow and failure paths

- Executable SHA-256 `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`. Checked 83 Binary Ninja instruction anchors against the corresponding offsets in this PE and read the seven referenced literals directly. [Native anchors](native-anchors.json)
- At first singleton construction, `CQuestTaskTypeMgr__Ctor` initializes the empty mission map at +0x18 and loads the mission config at `0x6A2119`. The login branch acquires the singleton before sending. The store cache lowercases the file path and opens `ini/Questinfo.ini` through `fopen(path,"r")` at `0x76EF68`. This is a loose file. Subsequent login sends traverse the existing map. This path does not reload the file for each login.
- `0x6A29B9` reads `[TotalMission] TotalMission` as a signed 32-bit integer with default zero. The signed loop starts at 1 and formats each section with `%d`. `0x6A2FAA` reads that section's `MissionId` with default zero. The INI lookup is case-insensitive. Missing/empty values use the default. Nonempty values use the existing CRT decimal conversion, or the hex branch for a leading `0x` or `0X` and length greater than two. The reader can accept numeric prefixes. [Native INI grammar](../../../Entity_System/chero_class.md#idle-timeout-ini-integer-read)
- `0x6A49D1` finds or inserts the signed MissionId key and `0x6A49D8` assigns the row to the record. Later rows replace duplicate-ID metadata. The sender walks the ordered tree and emits each ID once. It reads no other row metadata.
- Missing or unreadable file on a cold load gives no INI store, then a zero count. Empty file, missing/empty count, and count less than one also leave the new map empty. The sender skips its loop and the final send. It emits no 1134/3 packet for an empty map.
- A declared row with an absent or empty MissionId defaults to zero. If malformed data resolves to a nonpositive ID, insertion still occurs. Signed ordering places that ID first. Append rejects it at `0x72D485`, and the same unconditional send branch used for a full frame at `0x6A588F` is reached with initial length zero. The live socket's invalid-length branch at `0x6E1A3C` reaches protocol close at `0x6E1C41`. This is a static fault path under an active send. A login with a mutated asset was outside the VM captures.

## Frames and byte verification

The native initial buffer is 0x400 bytes and zero-filled. The wire frame has an 8-byte header and 12-byte records. Each record contains signed MissionId at +0, with the other eight bytes zero. Length is 8 plus 12 times record count. The valid catalog limit is 80 records or 968 bytes per frame, inside the 1,024-byte logical buffer. The full-buffer send and reset at `0x6A588F` and `0x6A589A` retry the same ID and continue. No unrelated send occurs between catalog frames. The last frame sends only if count is positive.

Extracted `ini/Questinfo.ini` directly from `5517.7z` and compared it with the `5517-loader` copy. They are byte-identical, 180,916 bytes, SHA-256 `b96b7f3007b1a95839e336666765b4d7ced7920f34dba91013fa9e81ebf8c06e`. The edited `clean/5517` copy has a different digest, `98d92e41bb092f406e601a6e728f1a4758561b82523fd8d7001daaa112185bad`, and the same catalog ID set. The retail sample has 230 rows and 224 distinct IDs. That count is sample data.

Using the unmodified assemblies built from the two main revisions below, an isolated diagnostic read the archive asset through OCC `IniDocument`, extracted/deduplicated/sorted the IDs, and invoked the merged `GameMissionCatalog1134.Write`. It reproduced the three independently recorded packets byte for byte. OCS `GameMissionCatalogReport.TryParse` accepted the original bytes and returned the same counts and ID ranges. The diagnostic invoked the component boundaries directly. Full socket integration remains with #306. [Rechecked packet digests](managed-comparison.json)

## Managed boundaries

- OCC main `91bb354025f7384931bc29f9e52d1a27de7a2d8a`. The existing serializer takes sorted positive IDs and writes one frame. The shared content abstraction and `IniDocument.LoadRequired` already support bounded loose-file reads. Add the asset requirement to `ClientContentClosure` with `LooseOnly` when the sender becomes active. This closure drives import and verification. Parse the selected install through the content layer and pass a validated immutable catalog to admission. Keep file IO and content validation outside the secured writer and reuse the same snapshot for role creation.
- Initial login in `LoginAttemptCoordinator` and post-creation continuation in `RoleCreationExchange` both reach successful `ReadLoginControlAsync` before reading the prelude and typed character. The observed early placement permits one deterministic contiguous burst after confirmed 2101 success and before outbound 74 on either route. The initial NEW_ROLE, creation-channel success, refusal, and cancel paths do not qualify. Keep one session owner, one reader and continuous secured write ordering across the burst. A partial write or cancellation must leave the session on its existing close path.
- OCS main `08d1dc0403faa01365e23c59b8c72951928c6ce6`. `LoginActionRequest` accepts the catalog while awaiting 74 or 75 and discards it after validation. A catalog must be contiguous and globally ascending. The server imposes its own bound of three frames or 240 IDs. Its current tests cover both observed placements and reject split bursts. The native sender's map walk has no three-frame guard.
- Treat invalid installed content as a bounded local validation error before any catalog write. That is managed policy. The native empty-map behavior and zero-length fault remain separate evidence. Cover missing/empty/malformed source, numbered sections outside the count, duplicate IDs, exact-full frames, the 240-ID bound, a write failure or cancellation mid-burst, and both admitted routes. Use the exact three captured native vectors for comparison. Keep created-character runtime verification and the complete corpus gate open.

Focused tests on isolated archives of the pinned mains passed with .NET SDK 10.0.403 on macOS arm64. OCC client 85, OCC content 108, OCS protocol 33, OCS login 442. Total 668 passed, zero failed or skipped.
