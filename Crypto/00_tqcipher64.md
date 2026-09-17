# TQCipher64 — Historical Project Name for CAST5 / CAST-128

## Status: VERIFIED TABLES + VERIFIED CFB PRIMITIVE + VERIFIED SCHEDULE EXPORT MAPPING

## Overview

TQCipher64 is the project's historical name for the **CAST5 / CAST-128** primitive
used by this 5517 GameServer's fixed-key DH wrappers and DH-derived CFB64 packet
streams. It is not a proprietary replacement or the cipher for every service:
AccountServer and separate modes 1/3/4 use the distinct legacy TQ byte transform.

The 2026-09-03 native audit independently matched the block/key/CFB control flow
and all eight S-boxes to OpenSSL CAST. The session-derived mask modifies only
unused outbound legacy tables in GameServer mode 2; it does not modify CAST.
See the [complete native mask and transport audit](../Network/14_session_derived_legacy_cipher_mask.md).

Verified primitive properties:
- all 8 S-boxes are verbatim RFC 2144 S1–S8
- 16-round / 12-round behavior follows the standard key-length rule
- schedule export mapping is verified at `0x779CCB..0x779CE3`:
  `schedule[2i] = subkey_i`, `schedule[2i+1] = ((uint8)raw_byte - 16) & 0x1F`

The project still uses a legacy 33-word schedule layout (`subkey, rotation` pairs plus
a round flag), but this is a representation detail, not a cryptographic divergence.

### Key Properties

| Property          | Value |
|-------------------|-------|
| Block size        | 64 bits (2 × 32-bit words) |
| Key size          | 1–16 bytes (clamped to 16) |
| Rounds            | 12 (key ≤ 10 bytes) or 16 (key > 10 bytes) |
| Stream mode       | CFB-64 (Cipher Feedback, 8-byte register, byte-granular) |
| S-box origin      | RFC 2144 (CAST-128) — all 8 S-boxes are verbatim CAST S1–S8 |

## Function Address Reference

| Function | Analyst name (current BN for CAST rows) | Address | Description |
|----------|----------|---------|-------------|
| Block cipher encrypt | `OpenSSL_CAST_encrypt` | `0x77F310` | CAST 64-bit block; old alias TqCipher64_EncryptBlock |
| CFB-64 stream cipher | `OpenSSL_CAST_cfb64_encrypt` | `0x778590` | CAST CFB64; old alias TqCipher64_Cfb64_Crypt |
| Key schedule | `OpenSSL_CAST_set_key` | `0x778790` | CAST_KEY, 33 words; old alias TqCipher64_ExpandKeySchedule |
| Engine init | `TqCipher64_EnsureEngineInit` | `0x778040` | Lazy-init global cipher vtable |
| DH context create | `DH_new_wrapper` | `0x777DC0` | Wraps embedded OpenSSL DH_new |
| DH context free | `DH_free` | `0x777F30` | Embedded OpenSSL DH_free |

## S-Box Layout (8 Total)

### Naming Conventions

| Role | IDA Name | Address | CAST-128 Equivalent |
|------|----------|---------|---------------------|
| Runtime SBox 0 | `TqCipher64_SBox0` | `0x86DF90` | CAST-128 S1 |
| Runtime SBox 1 | `TqCipher64_SBox1` | `0x86E390` | CAST-128 S2 |
| Runtime SBox 2 | `TqCipher64_SBox2` | `0x86E790` | CAST-128 S3 |
| Runtime SBox 3 | `TqCipher64_SBox3` | `0x86EB90` | CAST-128 S4 |
| Key-schedule SBox 0 | `TqCipher64_KSBox0` | `0x86EF90` | CAST-128 S5 |
| Key-schedule SBox 1 | `TqCipher64_KSBox1` | `0x86F390` | CAST-128 S6 |
| Key-schedule SBox 2 | `TqCipher64_KSBox2` | `0x86F790` | CAST-128 S7 |
| Key-schedule SBox 3 | `TqCipher64_KSBox3` | `0x86FB90` | CAST-128 S8 |

All 8 S-boxes are **256 entries × 4 bytes = 1 024 bytes each** (8 KB total).

### Verification — Full Table Integrity (IDA, 2026-02-27)

All 2048 dword entries in `TqCipher64Tables.cs` were compared directly against
`Conquer.exe` memory in IDA (`0x86DF90..0x86FF8F`):
- `SBox0`: SHA-256 `427c844bad080c6008bda87bd6aca4f6f342f6fca9472a6d63c31b69f6f85054`
- `SBox1`: SHA-256 `1a0c6d8588ad2bcc8fe37d32aad70981dd42eca259d570799beb531448d25ece`
- `SBox2`: SHA-256 `463be4a1c16eb914c411f194e1f87bef5a9081c49888860a682e8543d4b35f58`
- `SBox3`: SHA-256 `3eaa30e2bb2d4ff7221734e2cfbd2a94f0a3d8eb435634724dbf207afe0de24b`
- `KSBox0`: SHA-256 `5686dfa3dbae1c40758cfea05b267dac2faf6ccdfadbc08a75d81088b777c751`
- `KSBox1`: SHA-256 `97c49aba628782d4fe08840f38539e305c52d0a9c0e0882e77c23decab6bdba6`
- `KSBox2`: SHA-256 `31a50a6b8c571138dd6ea37b040389216b779c1ed712cb7980dd199e3bebefec`
- `KSBox3`: SHA-256 `ec103a6146a987638687685583404f2c172de3138c47b820021673ad5da00660`

### Verification — First Entries
```
SBox0[0] = 0x30FB40D4  ← CAST-128 S1[0], RFC 2144 Appendix B ✓
SBox1[0] = 0x1F201094  ← CAST-128 S2[0], RFC 2144 Appendix B ✓
SBox2[0] = 0x8DEFC240  ← CAST-128 S3[0], RFC 2144 Appendix B ✓
SBox3[0] = 0x9DB30420  ← CAST-128 S4[0], RFC 2144 Appendix B ✓
KSBox0[0] = 0x7EC90C04  ← CAST-128 S5[0], RFC 2144 Appendix B ✓
KSBox1[0] = 0xF6FA8F9D  ← CAST-128 S6[0], RFC 2144 Appendix B ✓
KSBox2[0] = 0x85E04019  ← CAST-128 S7[0], RFC 2144 Appendix B ✓
KSBox3[0] = 0xE216300D  ← CAST-128 S8[0], RFC 2144 Appendix B ✓
```

## Block Cipher: `TqCipher64_EncryptBlock` (0x77F310)

### Signature
```c
void TqCipher64_EncryptBlock(uint32_t block[2], const uint32_t schedule[33]);
```
- `block[0]` = left 32-bit half (in/out)
- `block[1]` = right 32-bit half (in/out)
- `schedule[0..31]` = 16 subkey/rotation pairs (schedule[2i] = subkey, schedule[2i+1] = rotation)
- `schedule[32]` = round flag (1 = 12 rounds, 0 = 16 rounds)

### Feistel Structure
Standard balanced Feistel with alternating subkey mixing operations and F-functions.

```
Initial:  L = block[0],  R = block[1]

for i in 0 .. rounds-1:
    X = mix(R, subkey[i], rotation[i])   // pre-rotate mixing
    F = sbox_combine(X)                   // 4-S-box combination
    new_R = L ^ F
    new_L = R
    L, R = new_L, new_R

Output: block[0] = R,  block[1] = L     // final state (no extra swap)
```

### Pre-Rotation Mixing (cycles every 3 rounds)
```
Round mod 3 == 0 (+):  X = ROL32(R + subkey,  rotation)
Round mod 3 == 1 (^):  X = ROL32(R ^ subkey,  rotation)
Round mod 3 == 2 (-):  X = ROL32(subkey - R,  rotation)
```

### F-Function Variants (cycles every 3 rounds, aligned with mixing)
Byte notation: B3=bits[31:24], B2=bits[23:16], B1=bits[15:8], B0=bits[7:0]
```
F1 (rounds 0,3,6,9,12,15):
    SBox3[B2] + (SBox1[B0] ^ SBox0[B1]) - SBox2[B3]

F2 (rounds 1,4,7,10,13):
    SBox3[B2] ^ (SBox2[B3] + SBox0[B1] - SBox1[B0])

F3 (rounds 2,5,8,11,14):
    (SBox2[B3] ^ (SBox1[B0] + SBox0[B1])) - SBox3[B2]
```
All arithmetic is unsigned 32-bit wrapping (mod 2³²).

## Key Schedule: `TqCipher64_ExpandKeySchedule` (0x778790)

### Signature
```c
void TqCipher64_ExpandKeySchedule(
    uint32_t output[33],    // subkey/rotation pairs + flag
    int       keyLen,       // key byte count (clamped to 16)
    const uint8_t *keyBytes // key material
);
```

### Output Layout
```
output[0]  = subkey_0      (uint32)
output[1]  = rotation_0    (0–31)
output[2]  = subkey_1
output[3]  = rotation_1
...
output[30] = subkey_15
output[31] = rotation_15
output[32] = use_12_rounds  (1 if keyLen ≤ 10, else 0)
```

### Algorithm Summary
The decompiled key schedule is CAST-family and uses S5–S8 (`KSBox0..3`) with
multi-pass state mutation over 16 key bytes. Verified output behavior:
- Produces 16 subkeys and 16 rotation values exported into the 33-word legacy schedule.
- Rotation values are stored as `(raw_byte - 16) & 0x1F` (range 0–31).
- Round flag set when keyLen ≤ 10 (12 rounds), cleared for > 10 (16 rounds).

Verification note:
- IDA output copy step at `0x779CCB..0x779CE3` stores subkeys and maps rotations as
  `((raw_ks_byte - 16) & 0x1F)` into the exported schedule.
- The bootstrap key `BC234xs45nme7HU9` schedule and block vectors are captured in
  `10_work/tests/Conquer.Tests/Crypto/TqCipher64Tests.cs`.

## CFB-64 Stream Mode: `TqCipher64_Cfb64_Crypt` (0x778590)

### Signature
```c
void TqCipher64_Cfb64_Crypt(
    const uint8_t *input,     // a1 — source bytes
    uint8_t       *output,    // a2 — destination bytes
    int            length,    // a3 — byte count
    uint32_t      *schedule,  // a4 — key schedule (33 elements)
    uint8_t       *iv,        // a5 — 8-byte shift register (modified in place)
    int           *feedbackPos, // a6 — byte position within current block (0–7)
    int            mode       // a7 — 0 = DECRYPT, non-zero = ENCRYPT
);
```

### IV / Shift Register
- `iv` is 8 bytes treated as two big-endian uint32s: `left = iv[0..3]`, `right = iv[4..7]`
- When `feedbackPos == 0`: `EncryptBlock(left, right, schedule)` produces 8 keystream bytes,
  overwriting `iv[0..7]` in big-endian order
- Keystream bytes are consumed one at a time, cycling through positions 0–7

### Encrypt (`mode != 0`)
```
for each byte i:
    if feedbackPos == 0: iv = EncryptBlock(iv)   // refresh keystream
    ciphertext[i] = iv[feedbackPos] ^ plaintext[i]
    iv[feedbackPos] = ciphertext[i]              // feedback
    feedbackPos = (feedbackPos + 1) & 7
```

### Decrypt (`mode == 0`)
```
for each byte i:
    if feedbackPos == 0: iv = EncryptBlock(iv)   // refresh keystream
    saved_ct = ciphertext[i]
    plaintext[i] = iv[feedbackPos] ^ ciphertext[i]
    iv[feedbackPos] = saved_ct                   // feedback (ciphertext)
    feedbackPos = (feedbackPos + 1) & 7
```

### Important Notes
- Both encrypt and decrypt use the **same** block cipher direction (encrypt only).
- The `iv` parameter is modified in-place — callers must maintain state across calls.
- The `feedbackPos` counter must survive across calls for streaming operation.
- The IV bytes are interpreted as BIG-ENDIAN for the block cipher call,
  but stored/read as individual bytes indexed 0–7.

## Embedded OpenSSL (DH Operations)

The client binary embeds OpenSSL for Diffie-Hellman key exchange. Confirmed by
the embedded source path string in `DH_free` (0x777F30):

```
".\\crypto\\dh\\dh_lib.c"  (line 178)
```

| Function | Address | Description |
|----------|---------|-------------|
| `BN_hex2bn` | `0x779F90` | Hex string → BIGNUM |
| `BN_bn2hex` | `0x779CF0` | BIGNUM → hex string |
| `BN_new` | `0x77A7F0` | Allocate BIGNUM |
| `BN_free_local` | `0x77A790` | Free BIGNUM (renamed local symbol) |
| `DH_generate_key` | `0x77A290` | Generate DH keypair |
| `DH_compute_key` | `0x77A2A0` | Compute shared secret |
| `DH_free` | `0x777F30` | Free DH context (OpenSSL, confirmed) |
| `DH_new_wrapper` | `0x777DC0` | Thin wrapper around OpenSSL DH_new |

**Implementation note**: In the C# reimplementation, all BN/DH operations are
replaced by `System.Numerics.BigInteger` with `BigInteger.ModPow` for the
DH exchange.

## Usage in Network Protocol

TQCipher64 is used exclusively in **CFB-64 streaming mode**:

1. **DH Handshake** (both directions): pre-shared key `BC234xs45nme7HU9` (16 bytes)
   - `ExpandKeySchedule("BC234xs45nme7HU9", 16)` → 16-round schedule
   - IVs are exchanged within the DH challenge/response

2. **Post-handshake packet encryption**: DH-derived shared secret as key
   - Native call path (`CClientSecurity__ProcessHandshake`, `0x753801`) computes
     `dhSize = DH_size(dh)`, zeroes a `dhSize + 1` buffer, writes secret bytes via
     `DH_compute_key`, then calls:
     `ExpandKeySchedule(dhSharedSecretBuffer, dhSize)` (uses `dhSize`, not the
     direct `DH_compute_key` return value)
   - Two independent CFB-64 instances: one for encrypt (with encrypt IV),
     one for decrypt (with decrypt IV)

See `../Network/13_connection_lifecycle.md` for the full handshake protocol.

## Implementation Notes for C#

1. **S-boxes are hardcoded constants**: Extract verbatim from binary or from RFC 2144.
2. **No block decryption needed**: CFB mode only ever calls the encrypt direction.
3. **Wrap-around arithmetic**: All F-function arithmetic is `unchecked` mod 2³².
4. **ROL32**: `(x << n) | (x >>> (32 - n))` — use C# `>>>` (unsigned right shift).
5. **Key schedule source of truth**: `TqCipher64_ExpandKeySchedule` (`0x778790`) in IDA.
   Current managed implementation uses CAST-128 expansion and maps to the legacy format as:
   `schedule[2i] = Km[i+1]`, `schedule[2i+1] = (Kr[i+1] + 16) & 0x1F`.
   Keep this under parity checks against new IDA vectors when additional key material is extracted.
6. **Rotation formula**: `rot = (raw_ks_byte - 16) & 0x1F` maps key-schedule bytes
   to rotation amounts 0–31.
7. **Thread safety**: `TqCipher64_EnsureEngineInit` (0x778040) uses a global lazy-init
   pattern in the original; in C# this is not needed (static S-boxes, no global state).
8. **CFB primitive mapping**: C# implementation mirrors 0x778590 in
   `10_work/src/Conquer.Crypto/TqCipher64Cfb64.cs` and is parity-tested against
   CAST-128 CFB-64 behavior.
9. **Stateful transport context**: C# stream context for persistent packet state
   (IV register + feedback byte index) is implemented in
   `10_work/src/Conquer.Crypto/TqCipher64StreamCipher.cs`.
