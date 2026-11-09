# CP3.2e native position-correction replies

[OCC spike #304](https://github.com/berniemackie97/OpenConquerClient/issues/304) under [CP3.2 #248](https://github.com/berniemackie97/OpenConquerClient/issues/248). Client reply implementation is tracked in [#263](https://github.com/berniemackie97/OpenConquerClient/issues/263).

## Provenance

- Original 5517 `Conquer.exe`, SHA-256 `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`. Windows 11 ARM64 guest under x86 emulation. Launched directly with `blacknull` from an isolated copy of the known working retail asset tree, excluding its loader files. Stock `Server.dat` SHA-256 `0b4d366786aa4498c7e470f10fd8bca716bc1d6cbda1eb3894666183f8327a90`.
- Disposable local account, controlled peer and synthetic roles. The peer used the OCS protocol assembly from commit `8b0f0745332a29530d046a44104ccf6d2914e62a`, DLL SHA-256 `b98260ffb5c1fca87f962dbe8c9bea8eca5fb94f8f7a44fae23bd8a79c61e654`, and BouncyCastle 2.7.0. No stock MsgServer participated.
- Client emissions were captured at the peer after CAST5-CFB decryption and `TQClient` trailer validation. Controlled peer inputs were recorded before encryption and `TQServer` insertion. Exact bytes and SHA-256 cover the logical header and payload, excluding the transport signature. [Capture](capture.json)
- The successful run contains 75 ordered records. 29 exact native-client frames, 19 exact controlled peer inputs, 15 byte-exact controlled echoes and 12 metadata-only records. The capture contains no raw bytes or hashes for account, proof, DH, device/address messages or this run's mission catalog. The earlier mission catalog capture is separate. [World-entry capture](../cp32-world-entry-2026-11-08/README.md)

The first attempt used the same executable from the other clean asset tree. It reached peer acknowledgment 75 and then the process faulted in `Flash.ocx` (Windows Application events `0xc0000005` and `0xc000041d`, module offset `0x0006061d`). No correction was delivered in that attempt. The isolated retry reached rendered world entry. The crash's cause and dependence on a particular asset remain unverified.

## Observed order

Bootstrap action 74 places the local hero (1000000) at (61,109) on map 1010. The client emits action 132 at record 35 and heartbeat at 36. The peer spawns foreign actor 1000001 at (63,109) with 10014 at 38. Both synthetic names are visible in the running client. Each correction follows a heartbeat echo. No walk or jump emission occurs during the recorded probe.

| Case | Controlled 10010/108 record | Native 10010/146 record | Observation before next heartbeat |
|---|---:|---:|---|
| Hero, same tile (61,109) | 42 | 43 | One reply after 28 ms, then heartbeat 44 |
| Hero, changed tile (62,109), unrelated fields populated | 46 | 47 | One reply after 24 ms, then heartbeat 48. HUD shows (62,109). |
| Hero, byte-identical repeat of 46 | 50 | 51 | One new reply after 29 ms with a fresh tick, then heartbeat 52 |
| Known foreign actor 1000001, proposed tile (62,110) | 54 | — | No client packet before heartbeat 55, 10,029 ms later |
| Unspawned foreign actor 1000002, proposed tile (62,110) | 57 | — | No client packet before heartbeat 58, 10,007 ms later |

Heartbeats continue through client record 74. The unrelated input fields at +8, +12, +16, +22, +28, +32 and +36 in records 46/50 differ from the corresponding reply fields. Records 46 and 50 have identical SHA-256 `b161241af5cba25f5318d917e91b07d36ef0a23bb559d8450b2aff46fb683fd4`.

## Reply contract and verification

Each 38-byte native reply contains actor at +4, corrected u16 X/Y at +8/+10, fresh raw u32 tick at +16, action 146 at +20, facing at +22, map ID at +28 and `0xFFFFFFFF` at +32. +12, +24/+26, +36 and +37 are zero. Facing is 0 in this run despite input facing 4 in records 46/50. The loaded map and its data ID are both 1010 in this test. The builder's map-ID source, facing source and early exits for foreign actors are established by the native call path. [Static ABI and field proof](../cp32-world-paths-2026-11-08/README.md#static-proof-of-the-108-reply)

| Native record | Raw tick | Logical packet SHA-256 |
|---:|---:|---|
| 43 | 82952310 | `415e1ee47b20bf7bb89252426b1ff7f4b74a9e860ca858705dfff4053757e593` |
| 47 | 82962325 | `bdb4bab11a349150e3f59457c4635faad834098760fdf72006aa979dd3df7294` |
| 51 | 82972342 | `3737030ee17d8ecb40d552ce3ba4a7b4996abd56056a19414901e5c82a65af09` |

The peer ran `GamePositionReport.TryParse` on all three native replies. It accepted each and decoded the actor and corrected tile. The parser file matches the blob `317c3c29ec69bccc618c95aec1ff103e78c045ce` on OCS main `08d1dc0403faa01365e23c59b8c72951928c6ce6`. This verifies parser compatibility. Full OCS session handling and original-server 108 emission remain untested in this probe.

All 63 retained frame byte lengths, headers and hashes were checked. The five correction windows were checked in sequence. The probe exercised well-framed 108s after activation, including nonzero ignored fields. Malformed frames, pre-activation delivery, off-grid tiles and nonzero hero facing were outside this run.

For #263, cover exactly one reply for each applied hero correction, including same-tile and identical repeats, and zero replies for either foreign target. Preserve serialized authenticated writes and existing close/cancellation ownership. Compare the entire reply layout and test the running client against OCS before closing the implementation issue.

## Managed secured replay — 2026-11-08

Client [PR #310](https://github.com/berniemackie97/OpenConquerClient/pull/310), head `08cdfa120f363f50fc26edb1debbae5a2c82a3a8`. Server main `08d1dc0403faa01365e23c59b8c72951928c6ce6`. This is a replay of the existing native evidence through the managed components.

An isolated loopback diagnostic completed the managed login and normal game admission ladder against a controlled peer. It used the existing test account/DH fixture and replayed the peer's bootstrap responses from capture records 9–12, 14–16, 23, 25, 28, 30, 32 and 34. The admitted snapshot had hero 1000000, map 1010, tile (61,109), and facing 0. The peer sent the exact five controlled 108 stimuli from records 42, 46, 50, 54 and 57. The client applied each through the normal dispatcher, inbound state, correction FIFO and secured session writer. For the byte comparison, the frame clock supplied the original reply ticks. The diagnostic suppressed heartbeat scheduling. Existing heartbeat tests ran separately.

After decryption and trailer validation, the peer received three logical frames. Each matched all 38 bytes and the SHA-256 of original native records 43, 47 and 51. The session emitted no additional reply for the foreign cases. The managed server's current `GamePositionReport.TryParse` separately accepted all three exact original packets and decoded (61,109), (62,109), (62,109) for hero 1000000. This covers the client ingress-to-secured-write route and the server parser boundary. A full connected OCC-to-OCS smoke and real session gameplay remain open.

Focused client tests used the local retail fixture. On both `84e651ed735eee50e6ba9632982a4021bac2e080` and the head above, 147 passed and one failed, with zero skips. The secured replay passed. `CorrectionBacklogIsBoundedWithoutDroppingAcceptedReplies` still expected `InvalidDataException` after the queue began throwing `WorldCorrectionQueueFullException`. Changing only the expected exception in the isolated test copy yielded 148 passed and zero skips. The existing FIFO assertions remained enabled. The current OCS focused protocol (19) and gameplay/worker (23) tests passed, 42 total. [Review evidence](https://github.com/berniemackie97/OpenConquerClient/pull/310#issuecomment-6727796986)

Follow-up head `518dc21e892802785e019de703d63b54463548fc` applies the identical one-line expectation change. Its only delta from `08cdfa1` is that test assertion. Both changed tracked test files were byte-compared against the passing isolated snapshot. The 148-test result therefore applies to that head plus the isolated replay diagnostic.

## Managed connected verification

The pinned OCC and OCS builds were exercised together in the [managed connected verification](../cp32-managed-connected-2026-11-08/README.md). That run preserves managed-server output separately from the original-client evidence in this directory.
