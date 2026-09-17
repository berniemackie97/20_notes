# RC5 Credential Field Cipher (MsgAccount Pre-Encryption)

## Status: VERIFIED via IDA decompilation

This document covers the legacy credential-field transform used before Msg1060/Msg1121
packet submission.

## Function Reference

| Function | Address | Role |
|----------|---------|------|
| `Rc5CredentialKeySchedule__Ctor` | `0x749A76` | Zero-init schedule object |
| `Rc5CredentialKeySchedule__Init` | `0x749A97` | Expand 16-byte seed into 26 RC5 subkeys |
| `Rc5CredentialTransform__EncryptInPlace` | `0x749B55` | Encrypt `floor(len/8)*8` bytes in 8-byte blocks |
| `RotateLeft32` | `0x749B38` | 32-bit rotate helper |
| `CredentialBlob__EncryptField` | `0x71459F` | Clamp-to-256 wrapper over `Rc5CredentialTransform__EncryptInPlace` |

## Verified Algorithm Notes

- RC5 profile: `RC5-32/12/16` style schedule (`26` subkeys, `12` rounds).
- Seed source for default schedule:
  `3C DC FE E8 C4 54 D6 7E 16 A6 F8 1A E8 D0 38 BE` (`0x93FD84`).
- Schedule expansion constants (as seen in native arithmetic):
  - `P32 = 0xB7E15163`
  - `Q32 = 0x9E3779B9` (native code subtracts `0x61C88647`, equivalent mod `2^32`).
- Mix loop count: `78`.

Credential wrapper behavior (`CredentialBlob__EncryptField`, `0x71459F`):
- returns immediately unless both source/key pointer and destination pointer are non-null.
- clamps requested output length to `256`.
- copies `256` bytes from `this + 0x108` into a local buffer.
- encrypts in place with stream key material at `this + 0x000`, key length `256`.
- copies clamped output bytes to destination.

## Ground-Truth Vectors (from IDA-decompiled logic)

Seed:
`3cdcfee8c454d67e16a6f81ae8d038be`

Expanded 26 subkeys:
`0xA9915556,0x48E44110,0x9F32308F,0x27F41D3E,0xCF4F3523,0xEAC3C6B4,0xE9EA5E03,0xE5974BBA,0x334D7692,0x2C6BCF2E,0x0DC53B74,0x995C92A6,0x7E4F6D77,0x1EB2B79F,0x1D348D89,0xED641354,0x15E04A9D,0x488DA159,0x647817D3,0x8CA0BC20,0x9264F7FE,0x91E78C6C,0x5C9A07FB,0xABD4DCCE,0x6416F98D,0x6642AB5B`

For test fixtures:
- source blob: `source[i] = (i * 3 + 7) & 0xFF` for `i in [0,255]`
- stream key: `key[i] = 255 - i` for `i in [0,255]`

Expected ciphertext:
- first `32` bytes:
  `ae83f0ac39925a39caf707dd0786c212cc0b0f451c07bd93d565333b78f85624`
- first `128` bytes:
  `ae83f0ac39925a39caf707dd0786c212cc0b0f451c07bd93d565333b78f85624326cb485d19fd78bb2cc39fd7633ea41a63d2321d2376964efac24cf0000bf4c77f53f6bbedad72d9578e1526056f9067934fc2c7d436f6cc29bc634e1c06191dc14bf14351590ac09d27d58bcc1bea4f71e5fad403afcd504064f8690b7b5a9`
- for requested length `31`, transformed bytes = `24`, encrypted prefix:
  `ae83f0ac39925a39caf707dd0786c212cc0b0f451c07bd93`
