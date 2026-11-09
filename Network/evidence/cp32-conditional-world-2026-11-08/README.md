# Native 5517 map-state, jump, and trade-quit capture

Captured November 8, 2026, New York time, in Windows 11 ARM64 under Parallels x86 emulation. The original client and stock Server.dat hashes are pinned in `capture.json`. The client launched directly with `blacknull` from an isolated copy of the installed retail tree, excluding loader files and restoring the clean `ini/GameSetUp.ini`. The installed copy exited before login. The isolated copy reached the login screen. This identifies a working launch setup; it does not isolate the failing setting.

GardenOfEden was routed inside the guest to a disposable controlled peer. The hero ID, coordinates, map flags, and actor status were synthetic. The captured client emissions are exact unmodified logical frames after CAST5-CFB decryption and validation of the TQClient trailer. Controlled peer inputs are recorded separately before encryption and insertion of the TQServer trailer. No account, proof, key-exchange, device, or ticket material appears in the retained artifact.

| Case | Sequence | Observation |
| --- | --- | --- |
| 10010/408 | Peer 1110 at 16, client 408 at 23 | Map 1010, flag bit 38 set. Client emitted one 38-byte 408 before action 75. Every body field except action is zero. Earlier flags-zero controls did not emit 408. |
| 10010/137 | 46–48 and 51–59 | Twelve 38-byte ordinary ground-jump requests. Target X/Y at +8/+10, origin X/Y at +24/+26, map at +28, 0xFFFFFFFF at +32, ground flag zero at +36. No jump acknowledgement was sent by this controlled peer. |
| 1056/2 | Peer appearance at 64, peer status at 67, native 1056 at 68 | Status low64 0x420, high64 zero, elicited one 12-byte trade quit 36 ms later. Synthetic hero at +4, u16 mode 2 at +8, zero at +10/+11 in this sample. Native 10010/145 followed 3.079 s later. |

Static anchors include 0x732CFD and 0x732D4C (map-state transition), 0x658965 (jump request), and 0x72A36C (trade quit on death). A captured packet does not establish original-server emission, mounted charge, or native jump acknowledgement behavior.

## Managed comparison

OCC main `89ca6e8a2fc2e878889169cbd201065deb95835f` produced an exact byte match using its existing action-408 writer. OCS main `e69aaf8d0db18e50952ce4ae587cdf20a4a031d7` parsed all twelve jumps and serialized exact byte-identical acknowledgements. Its production 1056 decoder accepted the captured mode-2 frame and the action parser accepted the zero-field 408. The comparison used the production parsers/serializers in a temporary harness. Connected OCS admission and jump behavior were outside this test. The next delivery gate is mirroring these cases in both checked-in fixture suites.
