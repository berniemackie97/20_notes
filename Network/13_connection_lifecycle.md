# Connection Lifecycle — TCP Connect, DH Handshake, Authentication

## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Network\

## Overview

The full connection lifecycle: TCP socket creation, DH key exchange, authentication, and encrypted packet traffic. Every detail below is decompiled from the client binary.

### Connection Sequence Summary
```
1. CNetClient__Connect(host, port)           — Allocate CGameSocket, TCP connect
2. Server sends DH handshake challenge        — S→C raw bytes (pre-key encrypted)
3. Client processes handshake, derives key    — CClientSecurity__ProcessServerDhChallenge
4. Client sends DH response                   — C→S raw bytes (pre-key encrypted)
5. Post-handshake crypto initialized          — Symmetric encryption active
6. Client sends selected MsgAccount login     — C→S 1060/1084/1098/1102/1121
7. Server responds (login result)              — S→C (type TBD — see note below)
8. Normal encrypted packet communication      — All packets encrypted + 8-byte signature
```

## Phase 1: TCP Connection

### CNetClient__Connect (0x6DEF5F)
Entry point for initiating a connection to a game server.

```c
// Allocates CGameSocket and connects to server
int CNetClient__Connect(const char* host, uint16_t port) {
    CGameSocket* socket = (CGameSocket*)operator_new(0x124D4); // 74,964 bytes
    CGameSocket__Ctor(socket);
    CGameSocket__Connect(socket, host, port);
    // Sets global connection flag on success
}
```

### CGameSocket__Ctor (0x6E16B2)
Initializes all CGameSocket fields to default state.

```c
void CGameSocket__Ctor(CGameSocket* this) {
    memset(this->send_buffer, 0, 0x2000);           // Clear send buffer
    this->send_pos = 0;                               // Reset send write position
    this->socket_handle = INVALID_SOCKET;              // -1
    this->socket_valid = 0;                            // Not connected
    memset(this->recv_ring, 0, 0x10000);              // Clear receive ring buffer
    this->recv_available = 0;                          // No bytes available
    this->recv_read_pos = 0;                           // Read position = 0
    this->handshake_flag = 1;                          // Waiting for handshake
    this->enc_state = 0;                               // No encryption
    this->handshake_start_pos = -1;                    // No handshake position
    CClientSecurity__Ctor(&this->security);            // Initialize security subsystem
    DeleteFile("socket.h");                            // Remove debug log file
}
```

### CGameSocket__Connect (0x6E1715)
Performs actual TCP connection with non-blocking socket.

```c
int CGameSocket__Connect(CGameSocket* this, const char* host, uint16_t port) {
    // 1. Initialize Winsock
    WSADATA wsa;
    WSAStartup(0x0101, &wsa);  // Winsock 1.1

    // 2. Create TCP socket
    SOCKET s = socket(AF_INET, SOCK_STREAM, 0);  // AF_INET=2, SOCK_STREAM=1

    // 3. Configure socket
    int reuse = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &reuse, 4);
    u_long nonblock = 1;
    ioctlsocket(s, FIONBIO, &nonblock);  // Non-blocking mode

    // 4. Resolve host and build address
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(host);

    // 5. Initialize security subsystem
    CClientSecurity__Init(&this->security);

    // 6. Async connect with select() timeout
    connect(s, &addr, sizeof(addr));
    // Uses select() to wait for connection completion
    // Handles WSAEWOULDBLOCK (10035) gracefully

    // 7. On success: store socket handle, mark valid
    this->socket_handle = s;
    this->socket_valid = 1;
}
```

**Key details:**
- Winsock version 1.1 (0x0101) — not Winsock 2
- Non-blocking connect with select() for timeout handling
- WSAEWOULDBLOCK (10035) is expected and handled gracefully
- Input validation: `host` must be non-null and length `<= 15` (dotted IPv4 literal path).
- On successful connect, the function resets runtime transport counters:
  send queued bytes, recv available bytes, recv read cursor, and legacy cipher cursors.

## Phase 2: DH Key Exchange (Handshake)

### Server Challenge (S→C)
After TCP connection, the server immediately sends a DH handshake challenge. This is **not** a standard packet — it is a raw encrypted binary blob, not framed by the usual `PacketHeader` format.

The client receives it via `CGameSocket__RecvFromSocket` (0x6E246C). Because `handshake_flag == 1`, the received bytes are stored raw (no decryption applied).

### CClientSecurity__ProcessServerDhChallenge (0x753801)
Processes the server's DH challenge.

```c
int CClientSecurity__ProcessServerDhChallenge(CClientSecurity* this, char* data, int available) {
    // Returns: <0 = failure (disconnect), 0 = need more bytes, >0 = bytes consumed

    // 1. Decrypt first 15 bytes with pre-shared key
    //    Key: "BC234xs45nme7HU9" (hardcoded)
    //    Cipher: TQCipher64 in CFB-64 mode (0x778590), IV=0, feedback=0
    TQCipher64_CFB64__Crypt(data, decrypted, 15, prekey_cipher, zero_iv, &feedback, DECRYPT);

    // 2. Read little-endian dword at decrypted offset +11
    //    This is the declared handshake body length (includes the trailing 8-byte signature)
    int declared_len = *(int32_t*)(decrypted + 11);
    if (declared_len < 12 || declared_len > 1024)
        return -1;  // Invalid → disconnect

    // 3. Total bytes consumed by this handshake frame
    int consumed = declared_len + 11;
    if (available < consumed)
        return 0;

    // 4. Decrypt body region (native decrypt call uses declared_len bytes from data+15)
    TQCipher64_CFB64__Crypt(data + 15, decrypted + 15, declared_len, prekey_cipher, zero_iv, &feedback, DECRYPT);

    // 5. Verify server trailer at (declared_len + 3) == (consumed - 8)
    if (memcmp(decrypted + declared_len + 3, "TQServer", 8) != 0)
        return -1;  // Bad signature → disconnect

    // 6. Extract DH parameters from chunk list (index-based, no tag field)
    //    HandshakeChunkList__GetEntryByIndex(list, 1013, idx, &ptr)
    //    => returns entry length and ptr for index idx.
    //    1013 is max list size bound, not a chunk tag.
    //    list base pointer is decrypted + 11.
    get_entry(list, max=1013, index=1, &entry);  // server encrypt IV (8 bytes) -> client decrypt_iv
    get_entry(list, max=1013, index=2, &entry);  // server decrypt IV (8 bytes) -> client encrypt_iv
    get_entry(list, max=1013, index=3, &entry);  // DH prime P hex
    get_entry(list, max=1013, index=4, &entry);  // DH generator G hex
    get_entry(list, max=1013, index=5, &entry);  // server public key hex

    // 7. Generate client DH keypair
    DH_generate_key(dh);  // Generates client public + private key

    // 8. Compute shared secret
    int dh_size = DH_size(dh);
    unsigned char shared_secret[dh_size + 1];
    memset(shared_secret, 0, dh_size + 1);
    if (DH_compute_key(shared_secret, server_pubkey, dh) == -1)
        return -1;

    // 9. Expand key schedule from DH shared secret
    //    Output: 16 (subkey, rotation) pairs + round flag stored at cipher_key offset
    //    Important parity detail: native passes DH_size(dh) as keyLen here (not the
    //    DH_compute_key return length).
    TqCipher64_ExpandKeySchedule(this->cipher_key, dh_size, shared_secret);

    return consumed;
}
```

Handshake challenge envelope (decrypted layout):

| Offset | Size | Meaning |
|--------|------|---------|
| +0 | 11 | Opaque random/prefix bytes |
| +11 | 4 | `declared_len` (LE dword) |
| +15 | `declared_len - 4` | Declared body bytes |
| `declared_len + 3` | 8 | `"TQServer"` trailer |

Native quirk: the client decrypt call for step 4 uses `declared_len` bytes from `data+15`
while `consumed` is `declared_len + 11`, so the native routine reads 4 bytes beyond the
logical consumed boundary. Managed implementations should keep the logical frame boundary
(`consumed`) while avoiding out-of-bounds reads.

### CClientSecurity__GenerateClientDhResponse (0x753669)
Builds and encrypts the client's DH response.

```c
int CClientSecurity__GenerateClientDhResponse(CClientSecurity* this, char* output, int max_size) {
    // Returns: >0 = response size, <=0 = failure

    // 1. Convert client public key to hex string
    char* pubkey_hex = BN_bn2hex(dh->pub_key);

    // 2. Build chunk list payload at plaintext + 7:
    //    - plaintext[0..6] is random prefix
    //    - entry[0]: random padding (10-49 bytes)
    //    - entry[1]: client public key hex
    //    HandshakeChunkList__AppendEntry(list, 1017, ptr, len)
    //    appends [len:u32][bytes...]
    //    1017 is max list size bound, not a chunk tag.
    int padding_len = abs((int8_t)random50[0]) % 50;
    if (padding_len < 10) padding_len += 10;
    HandshakeChunkList__AppendEntry(list, 1017, random_bytes, padding_len);
    HandshakeChunkList__AppendEntry(list, 1017, pubkey_hex, strlen(pubkey_hex));

    // 3. Append "TQClient" signature and overwrite list dword:
    //    declared_len = chunk_total_len + 8
    //    *(uint32_t*)(plaintext + 7) = declared_len
    memcpy(plaintext + 7 + chunk_total_len, "TQClient", 8);

    // 4. Encrypt from plaintext start:
    //    total_len = chunk_total_len + 15
    //    CFB-64 IV=0, feedback=0
    TQCipher64_CFB64__Crypt(plaintext, output, chunk_total_len + 15, prekey_cipher, zero_iv, &feedback, ENCRYPT);

    return chunk_total_len + 15;
}
```

Handshake response envelope (plaintext before encryption):

| Offset | Size | Meaning |
|--------|------|---------|
| +0 | 7 | Opaque random prefix |
| +7 | 4 | `declared_len` (LE dword, set to `chunk_total_len + 8`) |
| +11 | variable | Chunk entries (`entry[0]` random padding, `entry[1]` client pubkey hex) |
| +`7 + chunk_total_len` | 8 | `"TQClient"` trailer |

### Handshake Completion Flow (in CGameSocket__ReceiveMsg, 0x6E1C83)
```c
// After ProcessHandshake returns > 0:
CGameSocket__SendMsg(this, response_buffer, response_size);
CGameSocket__FlushSendBuffer(this);

// Update state
this->recv_available -= bytes_consumed;
this->recv_read_pos = (this->recv_read_pos + bytes_consumed) % 0x10000;
this->handshake_flag = 0;  // Handshake complete → encrypted mode active

// Post-handshake initialization
CConnectionFlow__SendGameSessionBootstrap();  // Sends the current startup variant's game-session bootstrap packet
```

### Game-Session Bootstrap Proof Packets (C→S)

`CConnectionFlow__SendGameSessionBootstrap` (0x6DF1D0) is invoked immediately after DH handshake completion and selects one of two packet builders:

- startup-movie/Facebook variant (`g_startupMovieFacebookVariantEnabled != 0`): `CMsgLoginBootstrap1203__BuildAndSendGameLoginProof` (0x7559FC) → packet **type 1203**, size **96**.
- standard 5517 path (`g_startupMovieFacebookVariantEnabled == 0`): `CMsgLoginBootstrap1052__BuildAndSendGameLoginProof` (0x7544E8) → packet **type 1052**, size **28**.

Verified `CMsgLoginBootstrap1052__BuildGameLoginProof` (`0x75443E`) layout (C→S, size 28):

| Offset | Size | Field |
|--------|------|-------|
| +0 | 2 | size (`28`) |
| +2 | 2 | type (`1052`) |
| +4 | 4 | session UID (`CHero+0xA9C`) |
| +8 | 4 | authentication key (`CHero__GetLoginAuthKey`) |
| +12 | 2 | mode (`124` in call path) |
| +14 | 2 | locale tag (2 bytes) |
| +16 | 6 | hardware key bytes |
| +24 | 4 | `res.dat` version |

Verified `CMsgLoginBootstrap1203__BuildGameLoginProof` used by `CMsgLoginBootstrap1203__BuildAndSendGameLoginProof` layout (C→S, size 96):

| Offset | Size | Field |
|--------|------|-------|
| +0 | 2 | size (`96`) |
| +2 | 2 | type (`1203`) |
| +4 | 4 | session UID (`CHero+0xA9C`) |
| +8 | 4 | extra account-success field (`CHero+0xAA0`; semantics unresolved) |
| +12 | 4 | authentication key (`CHero__GetLoginAuthKey`) |
| +16 | 2 | mode (`124` in call path) |
| +18 | 2 | locale tag (2 bytes) |
| +20 | 6 | hardware key bytes |
| +28 | 4 | `res.dat` version |
| +32 | 64 | identity blob |

Notes:
- Both builders call `CNetMsg__ResetPacketBuffer` before field writes, so unspecified bytes remain zeroed.
- The 6-byte hardware key comes from `CHardwareAddressList_CollectNetBiosAdapterMacs`, defaulting to zeros on failure.
- The 64-byte identity blob for type 1203 is copied from the buffer returned through `sub_661F4C`.

### Socket Transport State Machine Notes (0x6E1A07 / 0x6E1C83 / 0x6E246C / 0x6E215C)

- `CGameSocket__RecvFromSocket` (`0x6E246C`) writes directly into the receive ring at
  `write_pos = (recv_read_pos + recv_available) % 0x10000`, then may issue a second
  `recv()` call if the first read did not fill the available contiguous window.
- In DH mode (`enc_state == 2`):
  - `handshake_flag == 1`: incoming bytes stay encrypted in-ring.
  - `handshake_flag == 0`: incoming bytes are decrypted in place via
    `CClientSecurity__DecryptCast5Cfb64` before `recv_available` is incremented.
- `CGameSocket__ReceiveMsg` (`0x6E1C83`) handshake path:
  - if `handshake_start_pos == -1`, stores current `recv_read_pos` into it.
  - calls `CClientSecurity__ProcessServerDhChallenge`.
  - on success, generates/sends handshake response, consumes `bytes_consumed`,
    flips `handshake_flag` to `0`, and calls `CConnectionFlow__SendGameSessionBootstrap`.
- `CGameSocket__ReceiveMsg` post-handshake DH path:
  - reads packet length from ring head, computes `frame_len = packet_len + 8`.
  - validates trailing signature against `CClientSecurity__GetExpectedFlag()`.
  - consumes full `frame_len` from ring.
  - wrap quirk parity: when frame spans ring end, copy path may return/copy full
    frame bytes (including signature) instead of stripped packet bytes.
- `CGameSocket__SendMsg` (`0x6E1A07`) + `CGameSocket__FlushSendBuffer` (`0x6E215C`):
  - send queue capacity is `0x2000`.
  - pre-queue guard uses `if (pending + new_size > 0x2000)`:
    call one `FlushSendBuffer`, then disconnect if still over capacity.
  - DH + handshake pending: payload is queued raw (already bootstrap-encrypted by
    handshake response builder).
  - DH + post-handshake: payload is encrypted, encrypted 8-byte signature trailer is
    appended, then queued.
  - flush performs exactly one `send()` attempt per call; on partial send, remaining
    queued bytes are compacted (`memmove`-style).
  - non-blocking `WSAEWOULDBLOCK` is treated as non-fatal inside `FlushSendBuffer`
    (buffer retained), but in the `SendMsg` overflow guard path this can still lead
    to disconnect because the post-flush capacity check is enforced immediately.

## Phase 3: Pre-Shared Key & Cipher Details

### Pre-Shared Key
```
Key string:  BC234xs45nme7HU9
Length:       16 bytes
Usage:        Encrypts/decrypts the DH handshake exchange ONLY
              NOT used for post-handshake packet encryption
```

### TQCipher64 (0x77F310)
**CAST5 / CAST-128**, identified from original instructions and all eight OpenSSL
CAST S-boxes. TQCipher64 is a historical project/analysis alias, not a modified
cryptographic variant. See the [2026-09-03 native audit](14_session_derived_legacy_cipher_mask.md).
- Block size: 8 bytes (64 bits)
- S-boxes: 8 total (4 runtime + 4 key schedule), **identical to RFC 2144 CAST-128 S1–S8**
- Rounds: 12 (key ≤ 10 bytes) or 16 (key > 10 bytes)
- Key schedule: native OpenSSL-compatible CAST_KEY representation (32 subkey/rotation words plus short-key flag); representation details are not a different algorithm.
- Used in **CFB-64** (Cipher Feedback, byte-granular) stream mode via `TqCipher64_Cfb64_Crypt` (0x778590)
- See `../Crypto/00_tqcipher64.md` for complete specification

### CFB-64 Stream Mode (0x778590)
```c
void TQCipher64_CFB64__Crypt(
    char* input,           // Source data
    char* output,          // Destination buffer
    int   length,          // Byte count
    char* key,             // Cipher key (at CClientSecurity+32)
    char* iv,              // 8-byte IV (encrypt: +21, decrypt: +13)
    int*  feedback_state,  // Feedback counter (encrypt: +8, decrypt: +4)
    int   mode             // 0 = decrypt, 1 = encrypt
);
```

### Signature Strings
| String | Length | Usage |
|--------|--------|-------|
| `TQServer` | 8 bytes | Server→Client: handshake trailer and post-handshake packet trailer |
| `TQClient` | 8 bytes | Client→Server: handshake trailer and post-handshake packet trailer |

### Signature Trailer Size
`ProtocolSignature__Len()` (0x43C42C) — always returns `8`.

Every encrypted post-handshake packet has an 8-byte signature trailer appended:
- **Send**: Packet data encrypted, then encrypted `TQClient` signature (8 bytes) appended
- **Receive**: Last 8 bytes of each packet verified against `TQServer` via `CClientSecurity__GetExpectedFlag` (0x753DD1), then stripped before returning plaintext to dispatch

## Phase 4: Authentication (MsgAccount)

After the DH handshake completes, the client sends a login packet. The type depends on the encryption mode:

### Facebook/UIN Session Mode — MsgAccount Type 1121 (C→S)
Used by the `g_startupMovieFacebookVariantEnabled != 0` Standard-auth branch.

```c
struct MsgAccount_1121 {       // 280 bytes total
    uint16_t size;              // +0:  280
    uint16_t type;              // +2:  1121
    uint32_t account_type;      // +4:  2 in the Facebook/UIN producer branch
    char     account_name[128]; // +8:  UIN / account name
    char     session[128];      // +136: encrypted session key / password
    char     server_name[16];   // +264: target server name
};
```

**Created by**: `CMsg1121__Create` (0x749324)
**Called from**: `CGameMain_AccountSetupAndSendLoginAuthPacket` (0x66D4C1)

The session/password field is encrypted using `CredentialBlob__EncryptField` (0x71459F) before being placed in the packet. The packet itself is then further encrypted by the DH-derived symmetric cipher during transmission.

Verified write semantics from `CMsg1121__Create`:
- Null checks only: `uin`, `session`, and `server` must be non-null.
- No `strlen` upper-bound validation is performed in this creator.
- Writes are:
  - `+4`  : `uint32 account_type` (caller passes `2`)
  - `+8`  : `strncpy(..., 0x80)` for account/UIN
  - `+136`: `strncpy(..., 0x80)` for session blob
  - `+264`: `strncpy(..., 0x10)` for server name
- Header fields are finalized as `size=280`, `type=1121`.

### Standard Account Login — MsgAccount Type 1060 (C→S)
Used by the ordinary Standard-auth branch when the Facebook variant is disabled and no
mobile-protection value is present, and by the separate `AccountSetup/Type == 1` OEM branch.

```c
struct MsgAccount_1060 {       // 276 bytes total
    uint16_t size;              // +0:  276
    uint16_t type;              // +2:  1060
    char     account_name[128]; // +4:  UIN / account name
    char     password[128];     // +132: password (encrypted via CredentialBlob__EncryptField)
    char     server_name[16];   // +260: target server name
};
```

**Created by**: `CMsg1060__Create` (0x7491E2)

Verified write semantics from `CMsg1060__Create`:
- Strict input validation before write:
  - `account_name != null && strlen(account_name) <= 0x80`
  - `password_blob != null && strlen(password_blob) <= 0x80`
  - `server_name != null && strlen(server_name) <= 0x10`
- Writes are:
  - `+4`  : `strncpy(..., 0x80)` for account name
  - `+132`: `memcpy(..., 0x80)` for encrypted credential bytes
  - `+260`: `strncpy(..., 0x10)` for server name
- Header fields are finalized as `size=276`, `type=1060`.

Parity note:
- `Msg1060` uses raw `memcpy` at `+132` (not `strncpy`), so embedded `0x00` bytes inside the encrypted 128-byte field are preserved exactly.

### Verified `1060` producer split inside `CGameMain_AccountSetupAndSendLoginAuthPacket`

`CGameMain_AccountSetupAndSendLoginAuthPacket` (`0x66D4C1`) reaches `CMsg1060__Create` through two different native
branches. The packet layout is identical in both cases, but the credential source region passed
to `CMsg1060__Create` is not.

BNinja anchors:

- config gate read: `0x66D54B..0x66D565`
- `Type == 1` `1060` path: `0x66D634..0x66D6C5`
- default non-Facebook `1060` path: `0x66DA89..0x66DAD4`

Verified branch table:

| Native path | Encrypt call | Credential bytes copied into packet field |
|---|---|---|
| `IniReadInt(... "ini/oem.ini", "AccountSetup", "Type", 0) == 1` | `CEncryptedCredentialBuffer_EncryptField(..., 0x80)` at `0x66D68C` | all 128 bytes come from RC5 output |
| default own-UI / non-Facebook `1060` path | `CEncryptedCredentialBuffer_EncryptField(..., 0x20)` at `0x66DA9B` | first 32 bytes from RC5 output, trailing 96 bytes remain zero from prior `memset` |

Implementation implication:

- a native-compatible account server can legitimately see `1060` packets whose `+132..+151`
  region carries the active credential block while `+152..+259` are zero;
- that does **not** imply a different packet type. It is still the ordinary `CMsg1060__Create`
  packet, reached through the default `Type != 1` startup branch.

### Alternate Account Packet Variants from `CGameMain_AccountSetupAndSendLoginAuthPacket`

`CGameMain_AccountSetupAndSendLoginAuthPacket` routes through additional account packet creators
according to the verified `LoginAccountAuthMode` enum (`Standard=0`, `BoundAccount=1`,
`PictureKeyChallenge=2`) and the optional mobile-protection value.

#### Type 1084 (C→S) — `CMsg1084__Create` (0x749474)

```c
struct MsgAccount_1084 {        // 524 bytes total
    uint16_t size;               // +0:  524
    uint16_t type;               // +2:  1084
    char     account_name[128];  // +4   memcpy(..., 0x80)
    char     encrypted_credential[128]; // +132 memcpy(..., 0x80)
    uint32_t account_record_value;      // +260 dword from local account record lookup
    char     picture_key_challenge[65]; // +264 memcpy(..., 0x41)
    char     picture_key_response[128]; // +329 memcpy(..., 0x80)
    char     server_name[32];           // +457 memcpy(..., 0x20)
};
```

- Null checks only for input pointers used by `memcpy`.
- No `strlen` bounds checks in creator.

#### Type 1098 (C→S) — `CMsg1098__Create` (0x7495DB)

```c
struct MsgAccount_1098 {        // 440 bytes total
    uint16_t size;               // +0:  440
    uint16_t type;               // +2:  1098
    char     account_name[128];  // +4   memcpy(..., 0x80)
    char     encrypted_credential[128]; // +132 memcpy(..., 0x80)
    uint32_t account_record_value;      // +260 dword from local account record lookup
    char     picture_key_challenge[65]; // +264 memcpy(..., 0x41)
    char     picture_key_response[32];  // +329 memcpy(..., 0x20)
    char     server_name[32];           // +361 memcpy(..., 0x20)
    uint8_t  reserved_zero_393;         // +393 forced 0
    uint32_t mobile_protect_value;      // +428 optional atol(mobileProtectValue)
    uint32_t reserved_zero_432;         // +432 forced 0
    uint16_t has_mobile_protect_value;  // +436 1 when non-empty else 0
};
```

- If `mobileProtectValue` is non-null and non-empty, set `has_mobile_protect_value=1` and
  `mobile_protect_value=atol(mobileProtectValue)`.
- Otherwise set both fields to `0`.
- This is bound-account authentication with mobile protection. It is not registration.

#### Type 1102 (C→S) — `CMsg1102__Create` (0x7497AF)

```c
struct MsgAccount_1102 {        // 480 bytes total
    uint16_t size;               // +0:  480
    uint16_t type;               // +2:  1102
    uint32_t account_type_zero;  // +4   forced 0
    char     account_name[128];  // +8   memcpy(..., 0x80)
    char     encrypted_credential[128]; // +136 memcpy(..., 0x80)
    char     picture_key_challenge[65]; // +264 memcpy(..., 0x41)
    char     picture_key_response[32];  // +329 memcpy(..., 0x20)
    char     server_name[32];           // +361 memcpy(..., 0x20)
    char     reserved_zero_393[32];     // +393 memset 0
    uint32_t mobile_protect_value;      // +428 forced 0
    uint32_t reserved_zero_432;         // +432 forced 0
    uint16_t has_mobile_protect_value;  // +436 forced 0
    char     reserved_zero_438[40];     // +438 memset 0
};
```

Input validation from creator:
- `field_008` source pointer must be non-null and `strlen <= 0x80`.
- `field_136` source pointer must be non-null.
- `field_264` source pointer must be non-null.
- `field_361` source pointer must be non-null and `strlen <= 0x20`.

#### Type 1102 + Mobile Protection (C→S) — `CMsg1102__CreateWithMobileProtectValue` (0x7498F6)

Same base layout as type-1102 creator above, except:
- Optional mobile-protection input applies `has_mobile_protect_value=1` and
  `mobile_protect_value=atol(mobileProtectValue)` when non-empty.
- If missing/empty, `has_mobile_protect_value=0` and `mobile_protect_value=0`.
- `reserved_zero_432` remains forced `0`.

Semantic source mapping note:
- Names above are derived from verified call flow in `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` (function start `0x4AEE6A`,
  call site `0x4AF0A1`) into
  `CGameMain_AccountSetupAndSendLoginAuthPacket` (0x66D4C1) and then into packet creators
  (0x749474/0x7495DB/0x7497AF/0x7498F6).

### OpenConquer Account Registration Extension (non-native)

Retail 5517 registers accounts through a website URL selected by the startup SWF and dispatched by
`CMD_GETURL`; it has no verified account-server registration packet. The rebuilt client and server
therefore use a reserved, explicitly non-native pair without reassigning a retail opcode:

```c
struct OpenConquerRegisterAccountRequest_F001 { // 260 bytes total
    uint16_t size;                              // +0: 260
    uint16_t type;                              // +2: 0xF001
    char account_name[128];                     // +4: native account field semantics
    uint8_t encrypted_credential[128];          // +132: native credential transform
};

struct OpenConquerRegisterAccountResponse_F002 { // 8 bytes total
    uint16_t size;                               // +0: 8
    uint16_t type;                               // +2: 0xF002
    uint32_t result_code;                        // +4: 0 success, 1 invalid, 2 taken, 3 failed
};
```

Both frames use the existing packet-1059/login-stream framing and encryption. Registration success
does not issue native `1055`, create a game-login ticket, or begin game-server handoff.

### Legacy Credential Field Cipher (used by Msg1060/1121 field pre-encryption)

The account/session field pre-encryption path is a custom RC5-based transform:

- `Rc5CredentialKeySchedule__Ctor` (0x749A76): zero-initializes key schedule object (`0x78` bytes).
- `Rc5CredentialKeySchedule__Init` (0x749A97): expands a 16-byte static seed (`0x93FD84` = `3C DC FE E8 C4 54 D6 7E 16 A6 F8 1A E8 D0 38 BE`) into 26 RC5 subkeys (12 rounds).
- `Rc5CredentialTransform__EncryptInPlace` (0x749B55): encrypts `floor(len/8)*8` bytes in 8-byte blocks.
- `CredentialBlob__EncryptField` (0x71459F): clamps requested output length to 256, copies a 256-byte source blob from `this+0x108`, applies the transform, then copies requested bytes to output.

Notes:
- Transform key material is read from the first `256` bytes of the same source object (`this+0x000`).
- Calls in `CGameMain_AccountSetupAndSendLoginAuthPacket` use output lengths `0x20` and `0x80`, both aligned to the 8-byte block size.

Reference:
- `../Crypto/01_rc5_credential_field.md` contains verified RC5 constants,
  full subkey vector for the default seed, and deterministic ciphertext fixtures.

### Server Login Response (S→C)
Resolved behavior from current IDA pass:

- Type `1063` (`CMsgAccount__Process`, 0x6F469F) is **not** login success/failure; it handles award and cross-flag-war update flows.
- Type `1052` (`CMsgMapInfo__Process`, 0x75464C) is part of the authenticated transition path:
  - validates map/connect payload,
  - performs `CNetClient_Connect(payload+12, 0x16B8, 30)`,
  - sends follow-up map-info validation packet(s).
- Type `1002` dispatches to a message class whose process entry is `CNetMsg__NoopProcess` (no-op in this build).
- Type `1006` (`CMsgUserInfo__Process`, 0x764276) executes full world-entry bootstrap (hero field population, role-view creation, UI posts, and initial action sends). Critically, it also builds and sends client `MsgData` `actionEnterMap` (`74`), making it the confirmed gate into the next world-entry phase.

Login failure display (both mapped in [`Architecture/03`](../Architecture/03_login_flash_startup_command_contract.md)
"`1055` failure-code text contract"):
- Account stage: `1055` UID 0 — code-only read, `STR_CONNECT_ERROR_MSG_TYPE_%03u` text.
- GameServer stage, before world entry: `1004` channel 2101, text ≠ `ANSWER_OK`/`NEW_ROLE` → login error text
  (`0x5DCD58`). TQ 15.10 refusals use this channel ([topology](../Server/historical-multi-server-topology.md)).
- Success: map-info transition (`1052`), then user bootstrap (`1006`).

### Kick notice (1115, CMsgKickoutNotice)

Verified 2026-10-13, Binja. Formerly indexed as `CMsgPKEliteInfo` (reference-import name, wrong).

| Address | Fact |
|---|---|
| `0x75D7EB` | `CMsgKickoutNotice__Parse`: type `0x45B` (1115) |
| `0x75D80E` | `CMsgKickoutNotice__Process`: payload `+0` u32 mode. 0 ⇒ text at payload `+0xC` (NUL-terminated, ≤ 255 B copied) ⇒ command `0xD8C(text)`; 1 ⇒ command `0xCC6`; other ⇒ ignored. `+4`, `+8` unread |
| `0x5B565E` | `CMyShellDlg_DispatchCommandCode` `0xD8C` (case `0x5E`, table `0x5B850C`, code − `0xBC5`): kick state 1 + text `dlg+0x179ABC` |
| `0x5B568F` | `0xCC6` (case `0x40`): kick state 2. Other poster: `0x453068` (untraced) |
| `0x5DCA51` | at the next queued disconnect message: state 1 ⇒ Flash `KICKOUT_OTHERIPLOGIN(text)`, 2 ⇒ `KICKOUT_PASSWORDCHANGED` |
| `0x6DEDCF` | socket loss clears queue `0x96B330`, enqueues StrRes 10249 "Error: Disconnected with game server. Please login the game again!" (game socket) |

Server meaning: TQ kick on login elsewhere (mode 0) / password change (mode 1). Text semantics unproven; clean
`start.dat` has no `KICKOUT_*` handler, so the native 5517 player sees only the socket-loss text. TQ 15.10 MsgServer
kicks with a channel-2100 talk instead (`CUserList__KickOutAccount` `0x4AA260`), which this client routes to the
create-role queue, so 1115 is the 5517-correct kick. OCS use: [multi-realm decision](../Server/multi-realm-architecture-5517.md#openconquerserver-status-2026-10-14).

### Post-`1052` packet consumers and EnterMap trigger (corrected 2026-09-15)

BNinja anchors:
- `CMsgTalk__Process` (`0x731371`)
- `CMyShellDlg_HandleLoginStatusSystemTalk` (`0x5DCC64`)
- `CMyShellDlg_HandleCreateRoleStatusSystemTalk` (`0x5DCDDF`)
- `CMsgAccountLoginAlert2078__Process` (`0x75B029`)
- `CMsgServerState__Process` (`0x75AF76`)
- `CMsgUserInfo__Process` (`0x764276`)
- `CMsgAction__Ctor` (`0x6FE8A3`)
- `CMsgAction__Create` (`0x6FE95F`)

Client-consumed flow in the working server order (not a retail packet capture):
1. `1004` with control text `"ANSWER_OK"` advances the startup/login callback path. This is a real control talk, not cosmetic text.
2. `2078` stores `[lastLoginTimestamp, locationAlert, lastLoginLocation]` for the account-login-alert dialog and posts UI refresh `0xD39`. These are not character-title fields.
3. `2079` (`CMsgServerState`) reads a single dword:
   - `state == 0` -> `g_ServerProtocolState = 2000`
   - `state == 1` -> `g_ServerProtocolState = 2001`
   - other values leave it unchanged; the clean global initially contains 2000.
   - recovered uses control status UI; neither value is a proven EnterMap prerequisite.
4. `1006` hydrates the local hero and constructs/sends client `MsgData` `actionEnterMap` at `0x764873/0x7648A3`, without checking receipt or payload values of `2078/2079`. Normal transport/callback checks still apply.
5. Embedded evidence inside `CMsgUserInfo__Process`:
   - `"msg.Create(g_objHero.GetID(), 0, 0, 0, actionEnterMap)"`
6. `CMsgAction__Process` then advances the verified post-map bootstrap request ladder using
   literal `MsgAction` subtypes, not the older low-numbered action enum from legacy sources:
   - incoming `0x4A` (`actionEnterMap`) branch `0x6FF44A..0x6FF594` sends
     `0x4B` with debug string
     `"msg.Create(g_objHero.GetID(), 0, 0, 0, actionGetItemSet)"`
   - incoming `0x4B` branch `0x6FF3D3..0x6FF440` sends `0x4C`
     (`actionGetGoodFriend`)
   - incoming `0x4C` branch `0x6FF36B..0x6FF3C1` sends `0x4D`
     (`actionGetWeaponSkillSet`)
   - incoming `0x4D` branch `0x6FF300..0x6FF356` sends `0x4E`
     (`actionGetMagicSet`)
   - incoming `0x4E` branch `0x6FF28A..0x6FF2EB` sends `0x61`
     (`actionGetSynAttr`)
   - incoming `0x61` branch `0x6FF5D6..0x6FF625` sends `0xFB`: silent-info
     checksum/version report, entity ID **zero**, checksum at `+8`, version at `+16`
   - incoming `0xFB` branch `0x7008EA..0x700949` sends `0x84 actionGetStatistic`

   - common gate `0x6FF173`: echo `+4` must resolve via `EntityRef_ResolveByIdOrLocalHero`
     (local hero or a matching existing role); unresolved -> `0x700974`, no advance,
     for `0x4B..0x4E`/`0x61`/`0xFB`. Use the local hero ID for bootstrap replies. `0x4A` echo
     `+4` is overwritten with the hero id at `0x6FEE14`.
   - `0x4C` rung requires only the `0x4C` echo (`+4` = hero id). MsgFriend rows optional.
   - A blind zero-ID echo of the client `0xFB` request fails that gate. Its reply
     needs a resolvable ID to advance to `0x84`; it does not finish login.

See [action-61 native evidence](21_msgaction_0061_syndicate_bootstrap.md) for the
38-byte request, ignored reply timestamp/data, independent 1106 updates, and
limits on claims about retail server packet ordering.

Verified implication:
- In 5517, the client's immediate post-enter-map item bootstrap request is `MsgAction 0x4B`.
- Any server enum or handler table that assigns `GetItemSet` to `52` instead of `0x4B/75`
  is incompatible with this client build.

Managed parity implication:
- The server must not send the initial world-entry burst eagerly before the client has processed `1006`.
- The verified safe gate is the client's post-`1006` `DataAction.EnterMap` (`74`).
- The server must also not push login item-table `1008` packets directly from the post-`1006`
  connect/bootstrap handler. Those rows belong on the verified follow-up `DataAction.GetItemSet`
  (`0x4B / 75`) request leg.
- Evidence for the managed correction:
  - native 5517 BNinja verifies the client always emits `0x4B` immediately after processing
    server `0x4A`;
  - managed packet trace captured `ServerToClient 1008` rows before the client's `0x4B`,
    proving the old server ordering was wrong.
- Previous managed modeling of `2078` as a synthetic seed blob was incorrect; `2078` is the account-login-alert packet described in [10_extended_packets.md](10_extended_packets.md).

Managed rewrite contract (`10_work`, own-UI branch):
- Because scene packet ingress does not execute until startup posts `WM_COMMAND 0x464 / 0x483`, the startup submit runtime owns the initial post-DH game-socket receive window.
- `1006` drives the managed client `74` send. The prior claim that native waits for `{1004 ANSWER_OK, 2078, 2079, 1006}` before sending it was incorrect. `2078/2079` update UI data independently; their receipt must not be treated as a proven native dependency.
- The managed startup readiness checks for map/weather/enter-map are separate implementation policy. The local-player-spawn requirement was previously removed; a native local-hero spawn is discarded.
- The same post-DH socket channel is then handed off to scene ingress after `0x483` enables the world-frame gate.
- After `0x483`, the managed scene now consumes that bootstrap state at the verified integration points:
  - `74/10014`-derived tile state is projected into scene role positions using
    `Map_ProjectTileToScreenCoordinates` (`0x61D850`) semantics
  - local hero map centering uses the projected local-hero state as the managed equivalent of
    `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor` (`0x65185D`)
  - `1016` weather state is observed by a real type-`5` map component runtime instead of a dead stub
- This is a managed startup/runtime contract derived from verified packet-consumption points plus the verified `0x483` world-frame gate. It does **not** claim the exact native post-`74` wire order is fully proven yet.

Remaining gap for perfect parity:
- Exact retail `2078` timestamp/location/alert values and the actual `2079` state choice are server history/policy, unrecoverable from these client consumers. This is an evidence boundary, not a hidden client constant awaiting a guess. OpenConquerPublic currently sends `(0,0,empty text)` and state `0`; that working policy is retained. See [the detailed native audit](10_extended_packets.md#successful-existing-character-login-audit-2026-09-15).
- Exact native server-side ordering after the client's `74` still needs packet capture or stronger server trace evidence; current managed work should preserve the verified gate and use the established map/weather/enter-map bootstrap order conservatively.

### Verified Alternate Post-`1052` Create-Role Gate (`1004 NEW_ROLE` -> callback mode `0x3EC` -> `WM_COMMAND 0x464 / 3`)

BNinja anchors:

- `CMsgTalk__Process` (`0x731371`)
- `CMyShellDlg_HandleLoginStatusSystemTalk` (`0x5DCC64`)
- `CMyShellDlg_WindowProc_DispatchMainWindowMessages` (`0x5BB79D`)

Verified branch:

1. The game socket still receives `1004` control talk after authenticated connect.
2. If the control text is `"NEW_ROLE"` instead of `"ANSWER_OK"`, `CMyShellDlg_HandleLoginStatusSystemTalk`
   does **not** enter the world-bootstrap sequence.
3. Native actions on this branch:
   - `CLoginFlashCallbackState_SetModeHandlerByCode(CLoginFlashDlg_GetSingletonPtr(), 0x3EC)`
   - `PostMessageA(mainWindow, 0x464, 3, 0)`
4. `CMyShellDlg_WindowProc_DispatchMainWindowMessages` handles `WM_COMMAND 0x464 / wParam=3` as the
   create-role startup transition branch.

Parity implication:

- The managed startup runtime must treat `NEW_ROLE` as a successful authenticated handoff into create-role mode.
- It must **not** keep waiting for `{2078, 2079, 1006, client 74, 1110, 1016, 10014}` on this branch.
- `0x483` world-frame enable remains reserved for the `ANSWER_OK` world-entry branch.

### Verified Create-Role Continuation On The Same Game Session (`1001` -> `1004 ANSWER_OK` -> `CConnectionFlow__SendGameSessionBootstrap`)

BNinja anchors:

- `CRoleCreateFlashDlg_HandleFlashCommandString` (`0x51C32E`)
- `CRoleCreateFlashDlg_SubmitCreatePlayerRequest` (`0x51C5C3`)
- `CRoleCreateFlashDlg_SendCreatePlayerCancelAndPostHostCommand481` (`0x51C54B`)
- `CMsgCreatePlayer1001__Ctor` (`0x720059`)
- `CMsgCreatePlayer1001__Build` (`0x7200BF`)
- `CMyShellDlg_HandleCreateRoleStatusSystemTalk` (`0x5DCDDF`)
- `CConnectionFlow__SendGameSessionBootstrap` (`0x6DF1D0`)

Verified native create-role order:

1. Server has already authenticated the game session and returned `1004 "NEW_ROLE"`.
2. `WM_COMMAND 0x464 / 3` opens the create-role host path.
3. Flash/create-role UI updates:
   - nickname buffer at `this+0x14C`
   - body-size selector at `this+0x138`
   - vocation index at `this+0x13C`
4. `CMD_ENTERGAME` on the create-role host calls `CRoleCreateFlashDlg_SubmitCreatePlayerRequest`.
5. Native submit path:
   - validates nickname length (`4..15`) and font/pixel shape,
   - sets callback mode `0x3EC`,
   - derives `body` and `profession`,
   - builds/sends packet `1001` on the current authenticated game socket.
6. `CMyShellDlg_HandleCreateRoleStatusSystemTalk` processes the next create-role control talk:
   - if message is `"ANSWER_OK"`:
     - clear startup connect flag (`this+0x179AAC = 0`);
     - set `LOADING_TRACE` to `STR_CREATE_ROLE_SUCCESS`;
     - call `CConnectionFlow__SendGameSessionBootstrap()` on the same session.
   - otherwise:
     - surface the returned text through `CRoleCreateFlashDlg_SetFlashVariableAndDispatch(..., "ERROR", text)`.
7. `CConnectionFlow__SendGameSessionBootstrap()` then re-enters the normal world bootstrap path by sending the
   post-DH `1052`/`1203` proof packet for the already-open game session.

Parity implications:

- Native create success is **not** a relogin-required path.
- Server implementations should not disconnect after successful `1001`; they should leave the session alive for the
  client's follow-up `1052`.
- Managed own-UI create-role flow should therefore:
  - send `1001` on the existing game-session channel;
  - wait for `1004 "ANSWER_OK"` or an error talk;
  - on success, send the verified post-DH `1052` proof again through the same channel;
  - only then resume the normal bootstrap gate that leads to `0x483`.

### Verified Legacy Account Success Handoff (`1055 -> 1100 -> 1052(simple) -> game connect -> DH -> 1052/1203`)

BNinja anchors:

- `CMsgAccountAuthResponse__Ctor` (`0x7548A3`)
- `CMsgAccountAuthResponse__Parse` (`0x754909`)
- `CMsgAccountAuthResponse__Process` (`0x75492C`)
- `CMsgAccountAuthResponse__ProcessConnectToGameServerBranch` (`0x754D4C`)
- `CMsgAccountMacAddress1100__Ctor` (`0x767D3B`)
- `CMsgAccountMacAddress1100__Build` (`0x767DA1`)
- `CMsgLoginBootstrap1052__Ctor` (`0x754364`)
- `CMsgLoginBootstrap1052__BuildAccountResourceVersionReport` (`0x7543CA`)
- `CMsgLoginBootstrap1052__BuildGameLoginProof` (`0x75443E`)
- `CMsgLoginBootstrap1052__BuildAndSendGameLoginProof` (`0x7544E8`)
- `CMsgLoginBootstrap1203__Ctor` (`0x7558CA`)
- `CMsgLoginBootstrap1203__BuildGameLoginProof` (`0x755930`)
- `CMsgLoginBootstrap1203__BuildAndSendGameLoginProof` (`0x7559FC`)
- `CConnectionFlow__SendGameSessionBootstrap` (`0x6DF1D0`)
- `CHero__SetLoginAuthKey` (`0x663795`)
- `CHero__GetLoginAuthKey` (`0x6637A2`)
- `CNetClient_SetSocketEncryptionMode` (`0x6DF1B0`)
- `CGameSocketLegacyCipher_ApplySessionXorMask` (`0x755DF3`)

Verified success order from `CMsgAccountAuthResponse__Process` (`0x75492C`) and
`CMsgAccountAuthResponse__ProcessConnectToGameServerBranch` (`0x754D4C`):

1. `1055` success gate is `packet+4 != 0`.
2. Persist fields:
   - `CHero+0xA9C <- packet+4` (session token)
   - `CHero__SetLoginAuthKey(hero, packet+8)` (auth key)
   - `CHero+0xAA0 <- packet+0x10` (additional session field, later forwarded by 1203; not a proven hash or mask)
3. Build/send packet `1100`.
4. Compute stack-local cookie: `cookie = uint32(packet+4 + packet+8) ^ 0x4321`; addition wraps modulo 2^32 at 0x754C19. This is not a packet checksum.
5. Read local `res.dat` integer, default `0` when file open fails.
6. Build/send simple-string packet `1052`.
7. Disconnect account socket (`0x6DF043`).
8. Copy game host string from `packet+0x14` to runtime cache `0x96AD5C`.
9. Connect game socket with host `packet+0x14`, port `packet+0x0C`, timeout `0x1E`.
10. On game-socket connect success:
    - set encryption mode `2`;
    - derive mask `packet+8 ^ cookie`;
    - apply `CGameSocketLegacyCipher_ApplySessionXorMask(socket+0x12014, mask)`;
    - this XORs the outbound legacy tables with mask and low32(mask²), not a stored scalar mask; mode 2 bypasses those tables before, during and after DH, so the mutation has no wire effect;
    - set callback mode `0x3EB`;
    - post `WM_COMMAND 0x464` with `0x4E5`, then `0x519`.
11. After the game-server DH handshake completes, `CConnectionFlow__SendGameSessionBootstrap` sends:
    - legacy/non-Facebook path: packet `1052` (`0x7544E8`);
    - Facebook/else-branch path: packet `1203` (`0x7559FC`).

#### Packet `1100` (`CMsgAccountMacAddress1100__Build`, `0x767DA1`)

Direction in this path: `C->AccountServer`

| Offset | Size | Field | Verified write |
|--------|------|-------|----------------|
| +0 | 2 | size | `52` |
| +2 | 2 | type | `1100` |
| +4 | 4 | session token | caller passes `1055.packet+4` |
| +8 | 40 | MAC-address text buffer | zeroed; on success writes 12 uppercase hex chars via `_snprintf("%02X...")` |

Notes:

- Local MAC source comes from the NetBIOS helper path; on failure the 40-byte field remains zero-filled.
- Only the first 12 printable bytes are meaningful in the success path (`AABBCCDDEEFF` style).

#### Packet `1052` simple-string account follow-up (`CMsgLoginBootstrap1052__BuildAccountResourceVersionReport`, `0x7543CA`)

Direction in this path: `C->AccountServer`

| Offset | Size | Field | Verified write |
|--------|------|-------|----------------|
| +0 | 2 | size | `28` |
| +2 | 2 | type | `1052` |
| +4 | 4 | session token | caller passes `1055.packet+4` |
| +8 | 4 | `res.dat` version | parsed from local `res.dat`, default `0` on file-open failure |
| +12 | 16 | resource string | `strncpy(..., 0x10)` with `"res.dat"` |

#### Packet `1052` post-DH game-login proof (`CMsgLoginBootstrap1052__BuildGameLoginProof`, `0x75443E`)

Direction in this path: `C->GameServer`, after DH handshake completes

| Offset | Size | Field | Verified write |
|--------|------|-------|----------------|
| +0 | 2 | size | `28` |
| +2 | 2 | type | `1052` |
| +4 | 4 | session token | caller passes `CHero+0xA9C` |
| +8 | 4 | login auth key | caller passes `CHero__GetLoginAuthKey()` |
| +12 | 2 | mode | caller passes `0x7C` |
| +14 | 2 | locale tag | copied from dataset buffer |
| +16 | 6 | hardware key | first collected NetBIOS MAC, or zeros |
| +24 | 4 | `res.dat` version | parsed from local `res.dat` |

#### Packet `1203` post-DH game-login proof (`CMsgLoginBootstrap1203__BuildGameLoginProof`, `0x755930`)

Direction in this path: `C->GameServer`, Facebook/else-branch only

| Offset | Size | Field | Verified write |
|--------|------|-------|----------------|
| +0 | 2 | size | `96` |
| +2 | 2 | type | `1203` |
| +4 | 4 | session token | caller passes `CHero+0xA9C` |
| +8 | 4 | extra success field | caller passes `CHero+0xAA0` |
| +12 | 4 | login auth key | caller passes `CHero__GetLoginAuthKey()` |
| +16 | 2 | mode | caller passes `0x7C` |
| +18 | 2 | locale tag | copied from dataset buffer |
| +20 | 6 | hardware key | first collected NetBIOS MAC, or zeros |
| +28 | 4 | `res.dat` version | parsed from local `res.dat` |
| +32 | 64 | identity blob | copied from helper `0x661F4C` |

Parity note for the managed own-UI rewrite:

- the verified non-Facebook/native startup path uses the post-DH `1052` builder, not `1203`;
- `1203` remains the verified else-branch/Facebook variant and should not be used by the own-UI startup path unless that exact branch is intentionally reproduced.

## Phase 5: Encrypted Packet Communication

After DH completes, GameServer mode 2 uses DH-derived CAST5-CFB64, including the
first login proof before authentication is accepted. The session-derived legacy
rekey is intentionally absent from the reconstruction's active transport. Only
modes 1/3/4 call the changed outbound tables at 0x6E1BDC; receive uses different
legacy state. [Full consumer and wire-path proof](14_session_derived_legacy_cipher_mask.md).

### Send Path — CGameSocket__SendMsg (0x6E1A07)
```c
int CGameSocket__SendMsg(CGameSocket* this, void* packet_data, int size) {
    // Send buffer: this+0x0000, 8192 bytes
    // Buffer write position: this+0x2000

    switch (this->enc_state) {
        case 0:  // No encryption — raw send
            break;

        case 2:  // DH mode
            if (this->handshake_flag) {
                // During handshake: send raw using 'size' parameter directly
                // (not PacketHeader.size — handshake data has no standard header)
            } else {
                // Post-handshake: encrypt packet
                CClientSecurity__EncryptCast5Cfb64(&this->security, data, encrypted, size);
                // Encrypt and append "TQClient" signature (8 bytes)
                encrypt_signature("TQClient", encrypted_sig, 8);
                // Total sent = encrypted_packet + 8 bytes
            }
            break;

        case 1: case 3: case 4:  // Legacy encryption modes
            CGameSocket__EncryptBuffer(&this->legacy_cipher, data, size, 0);
            break;
    }

    // Copy to send buffer at write position
    memcpy(this->send_buffer + this->send_pos, data, total_size);
    this->send_pos += total_size;

    // If buffer nearly full, flush immediately
    if (this->send_pos >= 8192) {
        CGameSocket__FlushSendBuffer(this);
        if (this->send_pos >= 8192) {
            CGameSocket__Disconnect(this);  // Buffer overflow → disconnect
        }
    }
}
```

### Receive Path — CGameSocket__RecvFromSocket (0x6E246C)
```c
int CGameSocket__RecvFromSocket(CGameSocket* this) {
    if (!this->socket_valid) return 1;
    if (this->recv_available >= 0x10000) return 1;  // Ring buffer full

    // Calculate available space in ring buffer
    int write_pos = (this->recv_read_pos + this->recv_available) % 0x10000;
    int recv_len = /* space until wrap or until buffer full */;

    // Receive from socket
    int received = recv(this->socket_handle, this->recv_ring + write_pos, recv_len, 0);

    if (received > 0) {
        // Decrypt based on enc_state
        switch (this->enc_state) {
            case 0:  // No encryption
                break;
            case 2:  // DH mode
                if (this->handshake_flag) {
                    // Raw — no decryption during handshake
                } else {
                    // Decrypt in-place with DH-derived key
                    CClientSecurity__DecryptCast5Cfb64(&this->security, data, decrypted, received);
                    memcpy(data, decrypted, received);
                }
                break;
            case 1: case 3: case 4:  // Legacy
                CGameSocket__EncryptBuffer(&this->legacy_cipher, data, received, 1);
                break;
        }
        this->recv_available += received;

        // Try a second recv() if first filled its chunk
        // (attempts to maximize data read per call)
        // ... same decryption logic ...
    }
    else if (received == 0) {
        CGameSocket__Disconnect(this);  // Connection closed
        return 0;
    }
    else if (WSAGetLastError() != WSAEWOULDBLOCK) {  // 10035
        CGameSocket__Disconnect(this);  // Real error
        return 0;
    }
    return 1;  // WSAEWOULDBLOCK is OK (non-blocking socket)
}
```

### Receive Path — CGameSocket__ReceiveMsg (0x6E1C83)
```c
int CGameSocket__ReceiveMsg(CGameSocket* this, char* out_buffer, int* out_size) {
    // 1. Ensure at least 2 bytes available (for packet size field)
    if (this->recv_available < 2) {
        CGameSocket__RecvFromSocket(this);
        if (this->recv_available < 2) return 0;  // Still not enough
    }

    // 2. Read packet size from ring buffer (already decrypted by RecvFromSocket)
    uint16_t pkt_size = read_uint16_from_ring(this->recv_ring, this->recv_read_pos);

    // For DH mode (enc_state == 2), add 8 bytes for signature trailer
    int total_size = pkt_size;
    if (this->enc_state == 2 && !this->handshake_flag)
        total_size = pkt_size + 8;  // ProtocolSignature__Len() = 8

    // 3. Validate size
    // Note: the binary validates pkt_size (header-declared length), not total_size.
    // So in DH mode, total_size can be 1032 (1024 packet + 8 signature) and still be valid.
    if (pkt_size <= 0 || pkt_size > 1024) {
        // Reset ring buffer, log error, return 0
        this->recv_available = 0;
        this->recv_read_pos = 0;
        return 0;
    }

    // 4. Wait for complete packet
    if (total_size > this->recv_available) {
        CGameSocket__RecvFromSocket(this);
        if (total_size > this->recv_available) return 0;
    }

    // 5. For DH mode: verify signature trailer
    if (this->enc_state == 2 && !this->handshake_flag) {
        // Extract last 8 bytes of packet
        char trailer[8];
        copy_from_ring(trailer, this->recv_ring, trail_offset, 8);

        // Compare against expected "TQServer"
        if (memcmp(trailer, CClientSecurity__GetExpectedFlag(), 8) != 0) {
            CGameSocket__Disconnect(this);
            return 0;  // Signature mismatch → disconnect
        }
    }

    // 6. Copy packet data to output.
    // In the non-wrap branch, DH mode strips the 8-byte signature.
    // In the wrap branch, the stock code copies total_size bytes and reports total_size.
    // (This appears to be a parity quirk/bug in the original implementation.)
    int copy_size = (this->enc_state == 2) ? (total_size - 8) : total_size;
    copy_from_ring(out_buffer, this->recv_ring, this->recv_read_pos, copy_size);
    *out_size = copy_size;

    // 7. Advance ring buffer
    this->recv_read_pos = (this->recv_read_pos + total_size) % 0x10000;
    this->recv_available -= total_size;

    return 1;
}
```

### Flush and Disconnect

**CGameSocket__FlushSendBuffer** (0x6E215C):
```c
int CGameSocket__FlushSendBuffer(CGameSocket* this) {
    if (this->send_pos <= 0) return 1;

    int sent = send(this->socket_handle, this->send_buffer, this->send_pos, 0);
    if (sent > 0) {
        // Shift remaining data to front of buffer
        if (this->send_pos - sent > 0)
            memmove(this->send_buffer, this->send_buffer + sent, this->send_pos - sent);
        this->send_pos -= sent;
        return 1;
    }
    if (WSAGetLastError() == WSAEWOULDBLOCK) return 1;  // Try again later
    CGameSocket__Disconnect(this);
    return 0;
}
```

**CGameSocket__Disconnect** (0x6E229A):
```c
void CGameSocket__Disconnect(CGameSocket* this) {
    if (!this->socket_valid) return;

    closesocket(this->socket_handle);
    this->socket_handle = INVALID_SOCKET;  // -1
    WSACleanup();

    // Reset all state
    this->recv_available = 0;
    this->recv_read_pos = 0;
    this->send_pos = 0;
    this->socket_valid = 0;
    this->handshake_flag = 1;         // Ready for new handshake
    this->enc_state = 0;              // No encryption
    CClientSecurity__Reset(&this->security);
    this->handshake_start_pos = -1;

    // Zero out buffers
    memset(this->send_buffer, 0, 0x2000);    // 8192 bytes
    memset(this->recv_ring, 0, 0x10000);     // 65536 bytes
}
```

## CGameSocket Memory Layout

Total size: **0x124D4 (74,964) bytes**

| Offset | Dec Offset | Size | Field |
|--------|-----------|------|-------|
| 0x0000 | 0 | 8,192 | Send buffer |
| 0x2000 | 8,192 | 4 | Send buffer write position |
| 0x2004 | 8,196 | 4 | Socket handle (SOCKET, init = -1) |
| 0x2008 | 8,200 | 4 | Socket valid flag (0/1) |
| 0x200C | 8,204 | 65,536 | Receive ring buffer (0x10000 bytes) |
| 0x1200C | 73,740 | 4 | Recv bytes available |
| 0x12010 | 73,744 | 4 | Recv read position |
| 0x1222C | 74,268 | 520+ | Legacy cipher context (for EncryptBuffer, enc_state 1/3/4) |
| 0x124A4 | 74,788 | 1 | Handshake flag (1 = waiting, 0 = complete) |
| 0x124A8 | 74,792 | 4 | EncState (0=none, 1=legacy, 2=DH, 3/4=other legacy) |
| 0x124AC | 74,796 | 4 | Handshake recv start position (init = -1) |
| 0x124B0 | 74,800 | 164 | CClientSecurity instance |

### EncState Values
| Value | Mode | Description |
|-------|------|-------------|
| 0 | None | No encryption (initial state, post-disconnect) |
| 1 | Legacy | Legacy cipher via `CGameSocket__EncryptBuffer` at +74268 |
| 2 | DH | DH-derived symmetric encryption via CClientSecurity |
| 3-4 | Legacy (alt) | Alternative legacy cipher modes, same EncryptBuffer path |

## CClientSecurity Memory Layout

Total size: **~164 bytes** (resides at CGameSocket+74800)

| Offset | Size | Field |
|--------|------|-------|
| 0 | 4 | Cipher context pointer (from `sub_777DC0`) |
| 4 | 4 | Decrypt feedback state (CFB-64 counter) |
| 8 | 4 | Encrypt feedback state (CFB-64 counter) |
| 12 | 1 | Initialized flag (0/1) |
| 13 | 8 | Decrypt IV (= server's "encrypt IV", chunk index 1) |
| 21 | 8 | Encrypt IV (= server's "decrypt IV", chunk index 2) |
| 32 | ~132 | Cipher key (derived from DH shared secret via `sub_778790`) |

### CClientSecurity__Init (0x7535CC)
```c
int CClientSecurity__Init(CClientSecurity* this) {
    if (this->initialized) return 1;  // Already init'd

    // Generate time-seeded key string
    char buffer[128];
    snprintf(buffer, 127,
        "AFX_CLIENTSECURITY_H__4556C08B_9069_4D74_83AB_94CF9498D606__%d",
        time(NULL));

    // Initialize cipher engine
    TqCipher64_EnsureEngineInit(buffer, 128); // Lazy-init global cipher vtable
    this->cipher_ctx = DH_new_wrapper();      // Create OpenSSL DH context
    if (!this->cipher_ctx) return 0;
    this->initialized = 1;
    return 1;
}
```

### CClientSecurity__EncryptCast5Cfb64 (0x753C5B)
```c
int CClientSecurity__EncryptCast5Cfb64(CClientSecurity* this, char* in, char* out, int len) {
    if (!this->initialized || !this->cipher_ctx || !in || !out || len <= 0)
        return 0;
    // CFB-64 encrypt: key=+32, IV=encrypt_iv(+21), feedback=+8, mode=1(encrypt)
    TQCipher64_CFB64__Crypt(in, out, len, this->cipher_key, this->encrypt_iv,
                            &this->encrypt_feedback, 1);
    return 1;
}
```

### CClientSecurity__DecryptCast5Cfb64 (0x753CA1)
```c
int CClientSecurity__DecryptCast5Cfb64(CClientSecurity* this, char* in, char* out, int len) {
    if (!this->initialized || !this->cipher_ctx || !in || !out || len <= 0)
        return 0;
    // CFB-64 decrypt: key=+32, IV=decrypt_iv(+13), feedback=+4, mode=0(decrypt)
    TQCipher64_CFB64__Crypt(in, out, len, this->cipher_key, this->decrypt_iv,
                            &this->decrypt_feedback, 0);
    return 1;
}
```

### CClientSecurity__Reset (0x753626)
```c
void CClientSecurity__Reset(CClientSecurity* this) {
    if (!this->initialized) return;
    if (this->cipher_ctx) {
        DH_free(this->cipher_ctx);     // Free OpenSSL DH context (embedded OpenSSL)
        this->cipher_ctx = NULL;
    }
    this->initialized = 0;
    memset(this->encrypt_iv, 0, 8);     // Clear encrypt IV
    this->encrypt_feedback = 0;
    memset(this->decrypt_iv, 0, 8);     // Clear decrypt IV
    this->decrypt_feedback = 0;
}
```

## DH Handshake Chunk List Format

The handshake messages use a binary length-prefixed entry array:

- `u32 total_len` at offset `0` (includes this header and all entries)
- repeated entries: `u32 entry_len` + `entry_len` raw bytes
- no tag field is present in the serialized list

`HandshakeChunkList__GetEntryByIndex(list, max_size, index, &ptr)` returns the entry
length at zero-based `index`
and writes `ptr` to entry bytes. `max_size` is a caller-supplied upper bound (1013 or 1017),
not a chunk tag.

`HandshakeChunkList__AppendEntry(list, max_size, src, src_len)` appends one entry as
`[src_len:u32][src bytes...]`
and updates `total_len`. It requires `src_len > 0`.

### Server Challenge Entries (`max_size = 1013`)
| Index | Content | Format |
|-------|---------|--------|
| 0 | Unknown/reserved | — |
| 1 | Server encrypt IV | 8 raw bytes → client stores as decrypt IV |
| 2 | Server decrypt IV | 8 raw bytes → client stores as encrypt IV |
| 3 | DH prime P | Hex string (parsed via BN_hex2bn) |
| 4 | DH generator G | Hex string (parsed via BN_hex2bn) |
| 5 | Server public key | Hex string (parsed via BN_hex2bn) |

### Client Response Entries (`max_size = 1017`)
| Index | Content | Format |
|-------|---------|--------|
| 0 | Random padding | 10-49 random bytes (anti-analysis) |
| 1 | Client public key | Hex string (from BN_bn2hex) |

### Chunk List Helper Functions
| Function | Address | Purpose |
|----------|---------|---------|
| HandshakeChunkList__GetEntryByIndex | 0x753D64 | Find entry by zero-based index in length-prefixed list |
| HandshakeChunkList__AppendEntry | 0x753CE6 | Append entry to length-prefixed list |

## OpenSSL / Crypto Function Addresses

| Function | Address | Usage |
|----------|---------|-------|
| BN_hex2bn | 0x779F90 | Parse hex string → BIGNUM (DH params) |
| BN_bn2hex | 0x779CF0 | BIGNUM → hex string (client pubkey) |
| BN_new | 0x77A7F0 | Allocate new BIGNUM |
| BN_free_local | 0x77A790 | Free BIGNUM (local symbol rename) |
| BN_num_bits | 0x77A6B0 | Get bit count of BIGNUM |
| DH_size | 0x778020 | Get DH output size in bytes |
| DH_generate_key | 0x77A290 | Generate DH public/private keypair |
| DH_compute_key | 0x77A2A0 | Compute shared secret from DH params |
| OpenSSL_CAST_encrypt | 0x77F310 | CAST5 / CAST-128 block primitive; historical alias TqCipher64_EncryptBlock |
| TqCipher64_Cfb64_Crypt | 0x778590 | CFB-64 stream cipher wrapper |
| TqCipher64_EnsureEngineInit | 0x778040 | Lazy-init global cipher vtable (global dword_96C7B4) |
| CryptoEngine_FillRandomBytes | 0x778110 | Engine-backed random byte fill used by handshake response framing |
| OpenSsl_Free | 0x778550 | OpenSSL heap free wrapper used for `BN_bn2hex` buffers |
| DH_new_wrapper | 0x777DC0 | Thin wrapper around embedded OpenSSL DH_new |
| TqCipher64_ExpandKeySchedule | 0x778790 | Full key schedule expansion: 16 key bytes → 16 (subkey, rotation) pairs + round flag |
| DH_free | 0x777F30 | **Embedded OpenSSL** DH_free — confirmed by source path ".\\crypto\\dh\\dh_lib.c" line 178 |

Deobfuscated helper symbols used inside `CClientSecurity__ProcessServerDhChallenge`:

| Function | Address | Description |
|----------|---------|-------------|
| SharedPtrControlBlock__InitCheckedArrayDeleterChar | 0x753DD7 | Initializes temporary shared-array control block for parsed ASCII DH fields |
| SharedPtrControlBlock__InitCheckedArrayDeleterByte | 0x753E43 | Initializes temporary shared-array control block for DH shared-secret buffer |
| SharedPtrControlBlock__InitFunctionDeleterBignum | 0x753EF7 | Initializes temporary shared control block with `BN_free_local` deleter |
| SharedPtrControlBlock__Release | 0x404CE4 | Interlocked shared control-block release helper (destroy at strong=0, free at weak=0) |

## Function Address Reference

| Function | Address | Size | Description |
|----------|---------|------|-------------|
| CNetClient__Connect | 0x6DEF5F | — | Entry point: allocate socket, connect |
| CGameSocket__Ctor | 0x6E16B2 | — | Initialize CGameSocket fields |
| CGameSocket__Connect | 0x6E1715 | — | TCP socket creation + async connect |
| CGameSocket__SendMsg | 0x6E1A07 | — | Encrypt + buffer packet for sending |
| CGameSocket__ReceiveMsg | 0x6E1C83 | — | Read + validate + decrypt incoming packet |
| CGameSocket__RecvFromSocket | 0x6E246C | — | Raw recv() + in-place decryption |
| CGameSocket__FlushSendBuffer | 0x6E215C | 0xAD | send() buffered data to socket |
| CGameSocket__Disconnect | 0x6E229A | 0xAA | Close socket, reset all state |
| CGameSocket__EncryptBuffer | +74268 | — | Legacy cipher encrypt/decrypt (enc_state 1/3/4) |
| CClientSecurity__Init | 0x7535CC | 0x5A | Seed cipher engine, create context |
| CClientSecurity__ProcessServerDhChallenge | 0x753801 | — | Process server DH challenge |
| CClientSecurity__GenerateClientDhResponse | 0x753669 | — | Build encrypted DH response |
| CClientSecurity__EncryptCast5Cfb64 | 0x753C5B | 0x46 | Encrypt outgoing packet (DH mode) |
| CClientSecurity__DecryptCast5Cfb64 | 0x753CA1 | — | Decrypt incoming packet (DH mode) |
| CClientSecurity__GetExpectedFlag | 0x753DD1 | 0x06 | Returns "TQServer" string |
| CClientSecurity__Reset | 0x753626 | — | Free cipher, zero all security state |
| ProtocolSignature__Len | 0x43C42C | — | Returns 8 (signature trailer size) |
| CGameMain_AccountSetupAndSendLoginAuthPacket | 0x66D4C1 | — | Login flow: selects, builds, and sends native account-auth packet |
| CMsg1121__Create | 0x749324 | 0xC7 | Build Facebook/UIN session MsgAccount (type 1121) |
| CMsg1060__Create | 0x7491E2 | — | Build legacy MsgAccount (type 1060) |
| CMsg1084__Create | 0x749474 | 0xDE | Build type 1084 account packet variant |
| CMsg1098__Create | 0x7495DB | 0x14B | Build type 1098 account packet variant |
| CMsg1102__Create | 0x7497AF | 0x147 | Build type 1102 account packet variant |
| CMsg1102__CreateWithMobileProtectValue | 0x7498F6 | 0x180 | Build type 1102 account-auth variant with optional mobile protection |
| CredentialBlob__EncryptField | 0x71459F | 0x89 | Encrypt account/session field before packet assembly |
| Rc5CredentialKeySchedule__Ctor | 0x749A76 | 0x21 | Zero-init RC5 key schedule object |
| Rc5CredentialKeySchedule__Init | 0x749A97 | 0xA1 | Expand 16-byte seed into RC5 subkeys |
| Rc5CredentialTransform__EncryptInPlace | 0x749B55 | 0x1D3 | Encrypt 8-byte blocks for credential field |
| RotateLeft32 | 0x749B38 | 0x1D | 32-bit rotate helper used by RC5 helpers |
| CConnectionFlow__SendGameSessionBootstrap | 0x6DF1D0 | — | Sends the selected game-session bootstrap packet (called after handshake and on create-role success) |

## Crypto Implementation Cross-Reference

For full TQCipher64 specification (S-box data, round function, key schedule), see:
`../Crypto/00_tqcipher64.md`

Current C# transport wiring in `10_work`:
- `src/Conquer.Core/Network/Security/DhHandshakeKeyAgreement.cs` — managed DH key agreement + client-public-key hex encoding with OpenSSL-style parity (`BN_bn2hex`-compatible no leading zero nibble).
- `src/Conquer.Network/Packets/Msg1060PacketBuilder.cs` and `src/Conquer.Network/Packets/Msg1121PacketBuilder.cs` — verified MsgAccount builders (`1060` and Facebook/UIN `1121`) with native `strncpy`/`memcpy` field behavior.
- `src/Conquer.Network/Packets/MsgAccount1084PacketBuilder.cs`, `MsgAccount1098PacketBuilder.cs`, and `MsgAccount1102PacketBuilder.cs` — verified alternate native authentication variants (`1084`, `1098`, `1102`) including optional mobile-protection (`atol`) field semantics.
- `src/Conquer.Network/Packets/OpenConquerRegisterAccountRequestPacketBuilder.cs` — project-owned registration request, explicitly separate from native packet IDs.
- `src/Conquer/Network/Transport/TqGameSocketTransportStateMachine.cs` — socket-level send/receive ring orchestration for DH handshake and post-handshake secured packet flow.
- `src/Conquer/Network/Security/TqHandshakeChallengeFrameDecoder.cs` — verified encrypted server-handshake envelope decode (prefix/length/signature checks).
- `src/Conquer/Network/Security/TqHandshakeResponseFrameBuilder.cs` — verified encrypted client-handshake envelope build (random prefix/padding + chunk list + trailer).
- `src/Conquer/Network/Security/TqHandshakeBootstrapCipher.cs` — bootstrap key CFB helper (`BC234xs45nme7HU9`, fresh IV/feedback per frame).
- `src/Conquer/Network/Transport/TqHandshakeTransportContext.cs` — bootstrap-key handshake stream encryption/decryption.
- `src/Conquer/Network/Transport/TqSessionTransportContext.cs` — post-handshake stream state + trailer-signature packet encode/decode.
- `src/Conquer/Network/Transport/TqGameSocketChannel.cs` — socket I/O orchestration including `AdvanceHandshakeAsync` (recv -> decode challenge -> derive DH/session material -> queue response via native-equivalent pre-queue overflow guard -> one flush -> activate DH session) and `QueueOutboundPacketAsync` (flush once then disconnect on persistent overflow).
- `src/Conquer.Crypto/TqCipher64Cfb64.cs` and `src/Conquer.Crypto/TqCipher64StreamCipher.cs` — verified CFB-64 primitive + stateful stream core.

**Embedded OpenSSL confirmed**: `DH_free` (0x777F30) contains the source path
`".\\crypto\\dh\\dh_lib.c"` (line 178 assertion), proving TQ Digital statically linked
OpenSSL for DH operations. The C# reimplementation uses `System.Numerics.BigInteger.ModPow`
in place of OpenSSL's BIGNUM + DH_compute_key.

## Important Notes for Implementation

1. **Winsock 1.1**: The original client uses `WSAStartup(0x0101)` — Winsock 1.1, not 2.0. A modern implementation should use Winsock 2.2 or platform-native sockets.

2. **Non-blocking connect**: The client uses non-blocking sockets with `select()` for connection timeout. Modern implementations can use async I/O or connection timeouts directly.

3. **Ring buffer**: The receive buffer is a 64KB circular/ring buffer. This is a performance optimization for the original single-threaded event loop. Modern implementations may use different buffering strategies.

4. **Max packet size**: 1024 bytes (validated in ReceiveMsg). Packets exceeding this cause the ring buffer to be reset and an error logged.

5. **Signature trailer**: The 8-byte `TQServer`/`TQClient` trailer is **encrypted** along with the packet data, not appended in plaintext. Both send and receive paths must account for these extra 8 bytes in the encrypted stream.

6. **IV naming convention**: The "server encrypt IV" from the handshake becomes the **client's decrypt IV** and vice versa. This is because what the server encrypts with, the client must decrypt with.

7. **Packet type asymmetry**: Login packets use different types for C→S vs S→C:
   - C→S: selected native account-auth packet; `1121` is specifically the Facebook/UIN session variant
   - S→C: Type 1063 (server response)

   Packet selection and transport encryption mode are independent concerns. The corrected
   `CGameMain_AccountSetupAndSendLoginAuthPacket` producer does not select `1121` merely because
   the socket uses DH-derived transport encryption.

8. **Pre-shared key**: `BC234xs45nme7HU9` is used ONLY during the DH handshake exchange. All post-handshake encryption uses the DH-derived shared secret key.

9. **Random padding**: The client response includes 10-49 random bytes as anti-analysis padding. This means the response size varies between connections.

10. **WSACleanup on disconnect**: The original client calls `WSACleanup()` on every disconnect. This is technically incorrect if multiple sockets are active — a modern implementation should manage Winsock lifecycle separately.
