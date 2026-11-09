# Connected OpenConquer peer admission and movement

November 9, 2026. One focused connected test passed against OpenConquerClient
main `e9b408f97cf7ca1a03b489328067960334200033` and OpenConquerServer main
`30d0d33468e8ac274474fec099e6fab9ce968026`. The server process used the
byte-identical Git tree from reviewed PR #231 head `61216179ec705ca666b9131972467842317e3bf7`.
The test ran on macOS arm64 with the verified 5517 retail content and an
isolated, loopback-only MySQL 8.4.11 realm using the checked-in character
creation profile.

Two separate managed sessions registered disposable accounts, authenticated,
created characters, and entered map 1010. The test decoded logical packets
on the observer after CAST5-CFB decryption and TQServer framing validation.
The file records four selected frames in observed order, omitting intervening
unrelated traffic.

| Sequence | OCS emission | Observer result |
| --- | --- | --- |
| 1 | 10014, 233 bytes | Remote character admitted at (60, 108). |
| 2 | 10005 selector 0, direction 6 | Tile (61, 108), action 110. Mover echo matched the observer frame. |
| 3 | 10005 selector 1, direction 2 | Tile (60, 108), action 120. Both echoes matched the submitted logical bytes. |
| 4 | 10010 action 135, 38 bytes | Mover disconnect removed the remote character and playback state. |

The observer stayed at (60, 108). The harness used the production public walk
writer for selector 0 and submitted a constructed selector-1 request through
the existing secured packet writer after 600 ms. Both sessions used production
login and world ingress. The retained bytes are original to this isolated
**managed OCS** session. They contain only a disposable character name,
synthetic entity values and gameplay fields. Authentication, device, ticket
and key material were excluded.

## GPU replay of captured frames

The same four retained OCS frames were replayed unmodified through the
production client world dispatcher into the retail map-1010 C3 scene,
using a controlled observer seed at the same tile. The Apple M4 OpenGL
4.1 run rendered the new peer. The fourth animation frame differed from
the first at the same tile for both action 110 and action 120. Graphics
release and re-preparation on the same context restored the last frame.
Applying the captured removal cleared the role and animation, released
its appearance, and reproduced the exact empty framebuffer SHA-256.
See `gpu-replay.txt` for all framebuffer hashes.

This connects the observed wire bytes to the retail GPU result in a replay.
The live sessions were headless. Interactive visual comparison with the
original 5517 client, map-transfer cleanup, and native busy-state/pose checks
remain open. The [earlier retail GPU probe](../../../Rendering/evidence/peer-world-verification-2026-11-09/README.md)
documents the separate noncanonical selector-width discrepancy and
shared-appearance checks. Track OCC #249, #250 and #285.
