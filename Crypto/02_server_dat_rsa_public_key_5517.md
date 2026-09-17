# Server.dat RSA public-key material — independent native 5517 audit

Date: 2026-09-03. Candidate comparison: **MATCH — all 256 bytes**.

## Provenance and scope

Primary binary: `/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517/Conquer.exe`.
SHA-256: `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Binary Ninja view: `/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb`.

The seed was recovered from the original instruction immediates and stores in
`CConfigDataTableQueryProvider_ctor` at `0x765232`, not from reconstruction
constants. Every seed-store instruction in the Binary Ninja disassembly was
compared against the raw executable. Original x86 instructions were then executed
for seed initialization, the schedule transform, all 64 big-number accumulation
iterations, and exponent assignment. The candidate was used only for comparison
after that recovery.

Function names are analyst labels; addresses and instructions are authoritative.
For the cited code addresses, the parsed PE section map gives
`file offset = VA - 0x400000`. For example, constructor VA `0x765232` is file
offset `0x365232`.

This pass changes only documentation/evidence. No OpenConquerClient/application
code, repository tests, retail executable bytes, server code, Binary Ninja
annotations, branches or PRs were changed.

## Exact seed — 256 bytes in native memory order

Concatenate the following lines; these are bytes, not printed DWORD values.

```text
5c3dafa0bc08e8e4d1ae989a58921c4dfd7478d60590f03826ccd543bf54fcd6
815092ff1a3b095e7d84d6660b23567c7bffa8ef5f8416df575630c884db3ac9
883dba5e52e3fd733716ddd4da68b8c3c696305dd3cf07c663c5265f3207c2ca
c8a05c7779ac1983dbd449d9c92575d0ad11ea3961c3beb8f3407d2c09b059fb
792e3b0797b920ca86959884ca002846aa85b9a9d7a92646309a2de0164cd887
7646e54a262045c898060c2da168ba5cb906819f3a054628dea7c123d7f341fb
e44eb445e8e2dfde6644a04bb1e3b08bb2c83a48fdc0e8e1dbbbf8ef68fd1aab
afc7aa51ef699f33fb7eec933137d1ebbbf04b42022872c8b140838ca7f22022
```

## Exact seed — 64 little-endian DWORD values

Order is `seed[0]` through `seed[63]`; eight DWORDs per row.

```c
0xA0AF3D5C, 0xE4E808BC, 0x9A98AED1, 0x4D1C9258, 0xD67874FD, 0x38F09005, 0x43D5CC26, 0xD6FC54BF,
0xFF925081, 0x5E093B1A, 0x66D6847D, 0x7C56230B, 0xEFA8FF7B, 0xDF16845F, 0xC8305657, 0xC93ADB84,
0x5EBA3D88, 0x73FDE352, 0xD4DD1637, 0xC3B868DA, 0x5D3096C6, 0xC607CFD3, 0x5F26C563, 0xCAC20732,
0x775CA0C8, 0x8319AC79, 0xD949D4DB, 0xD07525C9, 0x39EA11AD, 0xB8BEC361, 0x2C7D40F3, 0xFB59B009,
0x073B2E79, 0xCA20B997, 0x84989586, 0x462800CA, 0xA9B985AA, 0x4626A9D7, 0xE02D9A30, 0x87D84C16,
0x4AE54676, 0xC8452026, 0x2D0C0698, 0x5CBA68A1, 0x9F8106B9, 0x2846053A, 0x23C1A7DE, 0xFB41F3D7,
0x45B44EE4, 0xDEDFE2E8, 0x4BA04466, 0x8BB0E3B1, 0x483AC8B2, 0xE1E8C0FD, 0xEFF8BBDB, 0xAB1AFD68,
0x51AAC7AF, 0x339F69EF, 0x93EC7EFB, 0xEBD13731, 0x424BF0BB, 0xC8722802, 0x8C8340B1, 0x2220F2A7
```

## Native stores and transform

The seed occupies `[ebp-0x114 .. ebp-0x15]`, 256 contiguous bytes.
There are 63 immediate-to-memory stores beginning at `0x76526D`, followed by
the last DWORD loaded into EDX at `0x765495` and stored at **0x76549C**.
Thus a range ending at `0x765495` identifies the final immediate but misses its
actual seed-table store. The decompiler's local-variable names/offset conventions
must not replace these raw EBP-relative displacements.

```asm
0076526D  mov dword [ebp-0x114], 0xA0AF3D5C  ; seed[0], bytes 5C 3D AF A0
00765277  mov dword [ebp-0x110], 0xE4E808BC  ; seed[1]
...
0076548E  mov dword [ebp-0x1C], 0x8C8340B1   ; seed[62]
00765495  mov edx, 0x2220F2A7
0076549A  push 0x11
0076549C  mov dword [ebp-0x18], edx          ; seed[63], bytes A7 F2 20 22
0076549F  pop eax                           ; rotation starts at 0x11
007654A0  lea ecx, [ebp-0x114]
007654A6  mov dword [ebp-0x10], 0x3F        ; exactly 63 XOR iterations

007654AD  lea edi, [ecx+4]
007654B0  mov ecx, dword [ecx]
007654B2  mov ebx, eax
007654B4  xor ecx, dword [edi]              ; seed[i] XOR seed[i+1]
007654B6  and ebx, 0x3F
007654B9  inc eax
007654BA  dec dword [ebp-0x10]
007654BD  mov dword [ebp+ebx*4-0x214], ecx
007654C4  mov ecx, edi
007654C6  jne 0x7654AD
007654C8  and eax, 0x3F
007654CB  mov dword [ebp+eax*4-0x214], edx
```

Exact transform:

```c
for (uint32_t i = 0; i < 63; ++i)
    schedule[(0x11u + i) & 0x3Fu] = seed[i] ^ seed[i + 1];
schedule[(0x11u + 63u) & 0x3Fu] = 0x2220F2A7u;
```

The final store is **schedule[0x10]**, not schedule[63].
EDX retains the last seed DWORD throughout the XOR loop.
All 64 schedule positions are written once. XOR operates on 32-bit words.

## Modulus construction and exponent

Provider `this+4` holds the RSA key pointer (store `0x7654D7`).
The constructor allocates BIGNUM objects at key+0x10 (n, `0x7654E2`) and
key+0x14 (e, `0x7654ED`), plus a temporary BIGNUM.

`BigNum_New` at `0x77A7F0` initializes top/negative/capacity/data to zero
at `0x77A82C..0x77A835`. `BigNum_SetWord` at `0x77AB30` clears the sign
at `0x77AB76`, stores the full unsigned 32-bit word at `0x77AB82`, and sets
the used-word count at `0x77AB84`. Words with bit 31 set are not sign-extended.

```asm
007654F7  lea edi, [ebp-0x214]       ; schedule[0]
007654FD  mov dword [ebp-0x10], 0x40

00765507  push 0x20                 ; shift count = 32 bits
00765509  mov eax, dword [eax+0x10] ; RSA n
0076550C  push eax
0076550D  push eax
0076550E  call BigNum_LeftShiftBits ; 0x77C610, n = n << 32
00765513  push dword [edi]          ; current schedule DWORD
00765515  push ebx                  ; temporary BIGNUM
00765516  call BigNum_SetWord       ; 0x77AB30
0076551E  push ebx
0076551F  mov eax, dword [eax+0x10]
00765522  push eax
00765523  push eax
00765524  call BigNum_Add           ; 0x77C100, n += temporary
00765529  add esp, 0x20
0076552C  add edi, 4
0076552F  dec dword [ebp-0x10]
00765532  jne 0x765504

0076553A  mov eax, dword [esi+4]    ; provider's RSA key
0076553D  mov dword [esp], 0x10001
00765544  push dword [eax+0x14]     ; RSA e
00765547  call BigNum_SetWord       ; e = 65537
```

Therefore `n = (((schedule[0] << 32) + schedule[1]) << 32 ...)`:
`schedule[0]` is the **most significant** 32-bit limb. The exported unsigned
256-byte modulus is the concatenation of 64 big-endian DWORD encodings.
The BIGNUM's own little-endian internal word array is not this exported byte
representation. The accumulation is arbitrary precision, not wrapping uint32
arithmetic.

Public exponent: **65537 = 0x10001**, unsigned big-endian bytes `01 00 01`.

## Derived modulus — 256 bytes, unsigned big-endian

```text
bef5bd339b6bac0c957fa68ec010a7d7c38a2b03a9d2084f0e107b2644e246b3
fab03ac76235ae40a0731714783d49caa99ac78a8a39d8b944f168b3aea3b216
2220f2a7444735e07e70a66dd7843c899b64e6a5ee88e4f87b255c2395299899
296e043ea19b6b9b38dfbf671a80a77693fedc7030be7b241726d208010a8dd3
9780e60c2d47dedaa720f56517657eed9e88fe1c9b37591599210ab095e4c251
bd9ea7faf4450cb15a5078a2093cf112e99f34648154d2cc94c38392d724f0fa
fc629e70cd1b97ee4eb82c11c2b0954cef918560ef9f2c7da60b33e767f5d626
cd3d0a6082a06650e54926be71b66e39c33b6e18b7c703830b87a2e4d8805409
```

Bit length: **2048**.

SHA-256 of these **256 raw modulus bytes** (not ASCII hex, DER/SPKI or PEM):

```text
76acb04b08190b129985f8dee2b466efcd686eb1662cb598bd1a8154cb9196f1
```

## CConfigDataTableQueryProvider consumption

`CConfigDataTableQueryProvider_LoadEncryptedDatToMemoryBuffer` (`0x764E8B`)
passes this same `this+4` key to `Rsa_GetModulusByteLength` at `0x764F8D`.
That helper (`0x77BE20`) reads key+0x10 and derives the byte length from its
bit length. The loader reads blocks at `0x764FBA`.

The real decode continuation `0x765111` pushes provider+4 at `0x765111`
and calls `Rsa_PublicDecryptDispatch` (`0x77BE70`) at `0x76511D`.
Its predecessor `0x765109` supplies padding value 1. The dispatch wrapper
reads the key's method pointer at +8 and invokes method slot +8 at `0x77BE8C`.
This binds the constructor key to the provider's actual public-block decode
path; it is not an unused seed copied from an unrelated subsystem.

As an independent data check, the recovered n/e successfully decoded all
**11** 256-byte blocks of clean `Server.dat` with valid PKCS#1 type-1 padding.
Their concatenated 2495-byte payload inflated
to 38819 bytes of XML containing `outenserver`.

- Server.dat SHA-256: `0b4d366786aa4498c7e470f10fd8bca716bc1d6cbda1eb3894666183f8327a90`.
- Inflated XML SHA-256: `5d6b00ff722a8b37aa2981affecd478aee73bdc22cdc498a25b700242b55c35a`.

That data check uses modular exponentiation on the recovered key. It is separate
from original-x86 constructor/BN arithmetic execution and is not represented as
a live Windows loader run.

## Verification and reproducibility

[Evidence directory and reproduction instructions](/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/10_work/docs/evidence/server-dat-rsa-5517/README.md) contains:

- full Binary Ninja constructor disassembly and decompilation;
- supporting big-number and RSA consumer extracts;
- a SHA-gated original-x86 harness;
- machine-readable seed, per-store VA/file offset/instruction bytes, schedule,
  modulus, hash, exponent and candidate comparison.

Observed original instruction/function counts:

| Native location | Count | Meaning |
|---|---:|---|
| 0x7654BD | 63 | Adjacent-XOR schedule stores |
| 0x7654CB | 1 | Final constant store to schedule[16] |
| 0x77C610 | 64 | Native BIGNUM left shifts |
| 0x77C100 | 64 | Native BIGNUM additions |
| 0x77AB30 | 65 | 64 limb assignments and one exponent assignment |

The harness preallocates zero-valued BIGNUM objects with spare capacity and skips
allocation/free calls. It executes the original BIGNUM arithmetic instructions:
no shift/add/set-word routines are replaced with Python implementations. The
native resulting BIGNUM is compared against a separate big-endian serialization
of the independently reconstructed schedule.

## Candidate comparison

**MATCH.** The user-supplied candidate is exactly 256 bytes and equals every
byte recovered from the native seed stores. No seed correction is indicated.
The candidate is not a source for the recovered values, modulus, or expected
native execution state.

## Appendix: every native seed store

The full instruction bytes are also in the JSON evidence. For row 63, the
immediate is loaded at `0x765495` and stored at the address shown below.

| seed index | Store VA | File offset | EBP displacement | DWORD |
|---:|---|---|---|---|
| 0 | 0x76526d | 0x36526d | -0x114 | 0xA0AF3D5C |
| 1 | 0x765277 | 0x365277 | -0x110 | 0xE4E808BC |
| 2 | 0x765281 | 0x365281 | -0x10c | 0x9A98AED1 |
| 3 | 0x76528b | 0x36528b | -0x108 | 0x4D1C9258 |
| 4 | 0x765295 | 0x365295 | -0x104 | 0xD67874FD |
| 5 | 0x76529f | 0x36529f | -0x100 | 0x38F09005 |
| 6 | 0x7652a9 | 0x3652a9 | -0xfc | 0x43D5CC26 |
| 7 | 0x7652b3 | 0x3652b3 | -0xf8 | 0xD6FC54BF |
| 8 | 0x7652bd | 0x3652bd | -0xf4 | 0xFF925081 |
| 9 | 0x7652c7 | 0x3652c7 | -0xf0 | 0x5E093B1A |
| 10 | 0x7652d1 | 0x3652d1 | -0xec | 0x66D6847D |
| 11 | 0x7652db | 0x3652db | -0xe8 | 0x7C56230B |
| 12 | 0x7652e5 | 0x3652e5 | -0xe4 | 0xEFA8FF7B |
| 13 | 0x7652ef | 0x3652ef | -0xe0 | 0xDF16845F |
| 14 | 0x7652f9 | 0x3652f9 | -0xdc | 0xC8305657 |
| 15 | 0x765303 | 0x365303 | -0xd8 | 0xC93ADB84 |
| 16 | 0x76530d | 0x36530d | -0xd4 | 0x5EBA3D88 |
| 17 | 0x765317 | 0x365317 | -0xd0 | 0x73FDE352 |
| 18 | 0x765321 | 0x365321 | -0xcc | 0xD4DD1637 |
| 19 | 0x76532b | 0x36532b | -0xc8 | 0xC3B868DA |
| 20 | 0x765335 | 0x365335 | -0xc4 | 0x5D3096C6 |
| 21 | 0x76533f | 0x36533f | -0xc0 | 0xC607CFD3 |
| 22 | 0x765349 | 0x365349 | -0xbc | 0x5F26C563 |
| 23 | 0x765353 | 0x365353 | -0xb8 | 0xCAC20732 |
| 24 | 0x76535d | 0x36535d | -0xb4 | 0x775CA0C8 |
| 25 | 0x765367 | 0x365367 | -0xb0 | 0x8319AC79 |
| 26 | 0x765371 | 0x365371 | -0xac | 0xD949D4DB |
| 27 | 0x76537b | 0x36537b | -0xa8 | 0xD07525C9 |
| 28 | 0x765385 | 0x365385 | -0xa4 | 0x39EA11AD |
| 29 | 0x76538f | 0x36538f | -0xa0 | 0xB8BEC361 |
| 30 | 0x765399 | 0x365399 | -0x9c | 0x2C7D40F3 |
| 31 | 0x7653a3 | 0x3653a3 | -0x98 | 0xFB59B009 |
| 32 | 0x7653ad | 0x3653ad | -0x94 | 0x073B2E79 |
| 33 | 0x7653b7 | 0x3653b7 | -0x90 | 0xCA20B997 |
| 34 | 0x7653c1 | 0x3653c1 | -0x8c | 0x84989586 |
| 35 | 0x7653cb | 0x3653cb | -0x88 | 0x462800CA |
| 36 | 0x7653d5 | 0x3653d5 | -0x84 | 0xA9B985AA |
| 37 | 0x7653df | 0x3653df | -0x80 | 0x4626A9D7 |
| 38 | 0x7653e6 | 0x3653e6 | -0x7c | 0xE02D9A30 |
| 39 | 0x7653ed | 0x3653ed | -0x78 | 0x87D84C16 |
| 40 | 0x7653f4 | 0x3653f4 | -0x74 | 0x4AE54676 |
| 41 | 0x7653fb | 0x3653fb | -0x70 | 0xC8452026 |
| 42 | 0x765402 | 0x365402 | -0x6c | 0x2D0C0698 |
| 43 | 0x765409 | 0x365409 | -0x68 | 0x5CBA68A1 |
| 44 | 0x765410 | 0x365410 | -0x64 | 0x9F8106B9 |
| 45 | 0x765417 | 0x365417 | -0x60 | 0x2846053A |
| 46 | 0x76541e | 0x36541e | -0x5c | 0x23C1A7DE |
| 47 | 0x765425 | 0x365425 | -0x58 | 0xFB41F3D7 |
| 48 | 0x76542c | 0x36542c | -0x54 | 0x45B44EE4 |
| 49 | 0x765433 | 0x365433 | -0x50 | 0xDEDFE2E8 |
| 50 | 0x76543a | 0x36543a | -0x4c | 0x4BA04466 |
| 51 | 0x765441 | 0x365441 | -0x48 | 0x8BB0E3B1 |
| 52 | 0x765448 | 0x365448 | -0x44 | 0x483AC8B2 |
| 53 | 0x76544f | 0x36544f | -0x40 | 0xE1E8C0FD |
| 54 | 0x765456 | 0x365456 | -0x3c | 0xEFF8BBDB |
| 55 | 0x76545d | 0x36545d | -0x38 | 0xAB1AFD68 |
| 56 | 0x765464 | 0x365464 | -0x34 | 0x51AAC7AF |
| 57 | 0x76546b | 0x36546b | -0x30 | 0x339F69EF |
| 58 | 0x765472 | 0x365472 | -0x2c | 0x93EC7EFB |
| 59 | 0x765479 | 0x365479 | -0x28 | 0xEBD13731 |
| 60 | 0x765480 | 0x365480 | -0x24 | 0x424BF0BB |
| 61 | 0x765487 | 0x365487 | -0x20 | 0xC8722802 |
| 62 | 0x76548e | 0x36548e | -0x1c | 0x8C8340B1 |
| 63 | 0x76549c | 0x36549c | -0x18 | 0x2220F2A7 |
