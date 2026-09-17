# Login credential envelope (5517)

How the account server recovers a password from a login request. **Settled and proven against the
real native 5517 client on 2026-08-23.** Written after a long session in which several confident
conclusions turned out to be wrong; the "how we got it wrong" section is part of the note on
purpose.

## Wire shape

Scope distinction: this note concerns the AccountServer credential envelope.
The later 1055-derived legacy table mask is **not** another credential transform
or GameServer requirement. See the [2026-09-03 native consumer audit](../Network/14_session_derived_legacy_cipher_mask.md):
standard GameServer traffic uses DH + CAST5-CFB64 and bypasses the rekeyed tables.
This does not change the live credential-envelope evidence recorded below.

Decrypted 1060 / register payload:

```
0x00..0x7F   username, 128 bytes, ANSI, NUL-padded   (plaintext, not RC5'd)
0x80..       credential field, RC5-encrypted
```

Frame length 276 for `ClientAuthRequest` (1060) = 4 header + 128 account + 128 password + 16 server.

`Standard5517` transforms `0x20` bytes of the credential field, `OemAccountSetup` the full `0x80`.
The branch is `ini/oem.ini` → `AccountSetup/Type == 1`, read at
`CGameMain_AccountSetupAndSendLoginAuthPacket` (0x66D4CB). No `oem.ini` ships, so `Standard5517`.

## Proven

**RC5 is standard RC5-32/12/16.** Native's key schedule (`Rc5CredentialKeySchedule_ExpandKey`,
0x749A97) is `P32 = 0xB7E15163`, step `-0x61C88647` (≡ `+0x9E3779B9`), 26 subkeys, 78 mixing
iterations, `%26` / `%4` indices. The rounds in `Rc5CredentialTransform_EncryptInPlace` (0x749B67)
are `A = ROL(A^B,B) + S[2i]`, 12 rounds, with `A += S[0]` / `B += S[1]` folded into little-endian
byte packing. Our `Rc5Cipher` reproduces the published RC5 vector
(`key=00*16, pt=00*8 -> 21A5DBEE154B8F6D`).

**The in-memory XOR obfuscation is not on the wire.** `CEncryptedCredentialBuffer_SetPlaintext`
(0x7148B0) stores

```
enc[i] = plain[i] ^ (byte)((i - 0x29) * i * 0x67)
                  ^ streamKeyMaterial[i % 0x100]
                  ^ (byte)((i >> 4) * 0x66)
```

and the RC5 input-word assembly re-applies the identical expression on the same index, so the two
cancel. The struct puts `streamKeyMaterial` at offset 0, `plaintextLength` at `+0x104`,
`encodedPlaintext` at `+0x108`. This layer exists to keep the cleartext out of process memory; the
server must not try to reverse it.

**The keypad permutation is applied.** `CGameInputString_ProcessFrameInputAndSelection` (0x59E59F)
branches at 0x59EC41 on an encode flag: set → per-account keypad permutation
(`CGameInput_ResetPasswordKeypadSeedFromAccount` 0x59F02D +
`CGameInput_MapVirtualKeyToLoginCipherByte` 0x59EF7B); clear → `sub_59F0AA`, which maps the scan
code straight to ASCII. The login dialog computes that flag at 0x4ADDFF from the selected server's
charge type, which made a raw form look plausible for a plain server — **it is not**. Measurement
against the live client shows the keypad stage is applied; see the SETTLED section. Do not infer
the transform from that flag without re-measuring.

The permutation itself: weight `seed[i & 0xF] ^ i` over values `1..255`, sorted descending; the
cipher byte is the sorted index of the scan code, `+0x80` when shifted. Seed is the signed byte
sum of the account name → `srand` → 16 × `rand() % 256`.

**The 48-row table at 0x936768** (stride 8: scan code dword, shifted char, unshifted char) is
scanned shifted-column-first, first hit wins. Because most digit rows repeat the same character in
both columns, digits `1,3,4,5,6,7,8,9,0` resolve as **shifted** and only `2` does not — its shifted
column is `'@'`. Deriving the flag from character case instead mis-encodes nine of ten digits.
Only `0-9 a-z A-Z . - @ > _` are representable; anything else terminates the buffer.

## SETTLED: RC5 key is derived from the login seed

**Proven end to end on 2026-08-23 against the real native 5517 client.** Registered an account on
the reconstructed client, authenticated from native, identical decode on both:

```
native (192.168.1.123, packet 1060): seed+keypad = len=4, aaaa
[2007] Auth success username=newtest5 account=11 sessionUid=1109323329
```

Native then completed character creation (characterId=18) and advanced the world-entry ladder.

The verified pipeline is:

```
RC5 key   = MSVCRT LCG seeded with the login seed the server sent
            state = state*0x343FD + 0x269EC3 ; byte = (state >> 16) & 0x7FFF ; 16 times
credential = RC5-decrypt(field)  ->  per-account keypad permutation  ->  password
```

Both stages are required. Measured by decoding one live native login under all four candidate
combinations; exactly one was ever clean, across five separate attempts and three accounts:

| candidate | result |
| --- | --- |
| seed + keypad | `len=4, aaaa` — correct, every time |
| seed + raw | `len=4, ?as?` / `?ss?` — garbage |
| fixed + raw | `len=32`, no terminator — garbage |
| fixed + keypad | `len=1` or `len=2` — garbage |

### Why a static read says "fixed key" — resolved

The disassembly and the measurement agree once the writer is found.

All six `Rc5CredentialKeySchedule_ExpandKey` call sites in
`CGameMain_AccountSetupAndSendLoginAuthPacket` do pass the literal `0x93FD84`. But
`CMsgLoginSeed__Process_DeriveCredentialRc5KeyFromSeed` (**0x764BC6**) overwrites the sixteen bytes
living there the moment the login seed frame arrives:

```asm
mov  eax, dword [ecx+0x404]      ; message body
push dword [eax+0x4]             ; body+4 = the login seed
call [srand]
loop:
  call [rand]
  idiv 0x100                     ; edx = rand() % 256
  inc  esi                       ; esi = 1 .. 0x10
  mov  byte [esi+0x93fd83], dl   ; 0x93FD84 .. 0x93FD93
  jb   loop
```

So `0x93FD84` holds a **pre-login default**, replaced per connection by
`srand(seed)` + 16 × `rand() % 256` — byte-for-byte what `LoginCredentialKey.Resolve` computes.
Nothing about the client is obfuscated here and there is no anti-disassembly involved.

**How it hid for so long:** the writer addresses the key as `0x93FD83 + esi`, so the instruction
encodes the immediate `83 FD 93 00`. A byte search for the literal `0x93FD84` returns only the six
`push` sites — which is exactly the search that produced the false "never written at runtime"
conclusion. Two compounding errors: searching for an address instead of a range, and treating
"appears only as a push operand" as proof of read-only when `memcpy(dest, …)` also pushes.

Binja is updated: 0x764BC6 renamed and commented. **The .bndb must be saved in the GUI** or the
rename is lost.

## Remaining gaps

Known-unknown, recorded so they are not mistaken for settled. The RC5 key question is **no longer
among them** — see above.

- **Why the charge-type flag at 0x4ADDFF did not predict the transform.** The branch at 0x59EC41
  genuinely selects keypad vs raw, and a plain server looked like it should take the raw path, yet
  the live client sent keypad. Either the flag is set for reasons not traced, or the raw branch is
  unreachable from the login dialog. Not chased once measurement settled the behaviour. Given the
  0x764BC6 lesson, assume a writer elsewhere sets that flag rather than that the branch is dead.
- **Non-ASCII account names are untested.** The keypad seed is a signed byte sum; ASCII names make
  signed and unsigned identical, so the sign only matters above 0x7F. We match native's `sx.d`,
  but no live test has exercised it, and usernames allow 32 unrestricted characters.
- **`OemAccountSetup` (0x80-byte field) is untested against a live client.** No shipped `oem.ini`
  triggers it, so the branch is implemented from the disassembly only.
- **Passwords containing characters outside the 48-row table are untested.** Both sides truncate at
  the first unrepresentable character, which matches the client's own behaviour, but no live test
  has confirmed the truncation point agrees.
- **`Decrypt` stopping at an unmappable value** is our inverse, not a native behaviour — native
  never decrypts. It makes a decode error surface as a short password rather than an exception,
  which is what made the four-way diagnostic readable, but it is a server-side choice.

## How we got it wrong (repeatedly)

- **The reconstructed client agreeing with the server proves nothing.** Both were written from the
  same understanding, so a wrong assumption gets implemented twice and round-trips cleanly. Native
  is the only referee. This hid the credential bug for the entire life of the code.
- **Reading one call site is not enumerating callers.** The fixed-key conclusion came from reading
  a single `ExpandKey` call rather than all seven.
- **A literal in the disassembly is not proof of the runtime value** when the target is writable.
- **eosource is several revisions before 5517** and its login flow differs; names only, never
  behaviour. It uses `m_pInfo->dwData` where 5517 reads wire `+8`.
- **Symbol names in the .bndb can be wrong.** `CGameInput_TryMapAsciiToVirtualKeyAndShiftFlag`
  returns scan codes, not virtual keys.
- Length is a stronger signal than content. A terminator's position is invariant under the keypad
  transform and the seed, so `length` alone distinguishes "wrong key" from "wrong transform".
