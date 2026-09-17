# Login Flash Startup Command Contract (Verified)

## Scope

Full verified command surface between `CLoginFlashDlg` (C++) and `start.dat` (Flash SWF), including all
Flash variables pushed from C++ and all `CMD_*` callbacks handled in C++.

- Binary: `00_clean/clean/5517/Conquer.exe`
- Active BNinja view: `17`
- Primary handler: `CLoginFlashDlg_HandleFlashCommandString` (`0x4AA0AE`)
- Startup init: `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` (`0x4AB5C5`)

## Architecture Overview

The pre-world startup UI is entirely Flash-driven (`start.dat` = compressed SWF, CWS version 6).
The C++ side acts as a host: it pushes data variables to Flash, and Flash calls back with `CMD_*`
command strings when the user interacts with the UI.

Music playback during startup is handled by the Flash SWF itself, not by NDsound.dll calls from C++.
The C++ side only communicates the music-enable preference via the `SELECTBGMUSIC` variable.

For the cross-platform rewrite, the Flash SWF is replaced by a native startup presentation that
emits the same verified command set.

## Own-UI Connect/Login/World-Load Sequencing (Verified, `main-own-ui`)

BNinja verification anchors in `CLoginFlashDlg_HandleFlashCommandString` (`0x4AA0AE`) and close handler:

- `CMD_NAME` branch (`0x4AA72D..0x4AA79B`) updates the login-name buffer (`this+0x198`).
- `CMD_PASSWORD` branch (`0x4AA7B3..0x4AA852`) encodes each byte through
  `CGameInput_EncodePasswordCharForLoginBuffer` (`0x59EECA`) and writes the encoded buffer at `this+0x414`.
- `CMD_ENTERGAME` / `CMD_GAMESTART` branch (`0x4AA228..0x4AA253`) posts
  `Conquer_PostMainWindowMessage464(0x480, 0)`.
- `CMD_CLOSE` branch (`0x4AA69F..0x4AA6A3`) calls
  `CLoginFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` (`0x4AC62B`), which posts:
  - `Conquer_PostMainWindowMessage464(0x483, 0)` (`0x4AC69C`)
  - `Conquer_PostMainWindowMessage464(0xC6B, 0)` (`0x4AC6A7`)
  - `CLoginFlashCallbackState_SetModeHandlerByCode(..., 0x3F2)` tail (`0x4AC6C3`)

Managed own-UI runtime contract mirrors this ordering:

1. `SetLoginUser` command persists normalized account name to `ini/GameSetup.Ini` `[Account] AccountRecord`.
2. `SetLoginPassword` command encodes password with the verified native cipher table/algorithm and stores encoded buffer in startup credential state.
3. `Connect` command posts `WM_COMMAND 0x464` with `wParam=0x480`.
4. `EnterWorld` is **not** inferred from `LOADING_TRACE` text callbacks. It is only legal on an explicit
   world-ready transition matching native close-sequence intent. In the managed own-UI path that means:
   verified login/bootstrap packets are consumed through the startup runtime (`1004 -> 2078 -> 2079 -> 1006 -> client 74`
   then the conservative post-`74` set `10010/1110/1016/10014`), and only after that does startup post
   world-enable/close messages (`0x483`, `0xC6B`, `0x3F2`) and stop the startup BGM sink.
5. If authenticated game-socket handoff yields `1004 "NEW_ROLE"` instead, startup follows the separate native
   create-role branch:
   - `CLoginFlashCallbackState_SetModeHandlerByCode(..., 0x3EC)`
   - `WM_COMMAND 0x464 / wParam=3`
   - no `0x483` world enable on that branch
   - no waiting for the world-bootstrap packet set on that branch
6. Once create-role mode is active, the verified native command surface moves to `role.dat` host commands:
   - `CMD_NICK` -> update nickname buffer
   - `CMD_BODYSIZE` -> update body-size selector
   - `CMD_VOCATION` -> update vocation index
   - `CMD_ENTERGAME` -> validate + send `1001`
   - `CMD_DRIVERBACK` -> send cancel `1001` and post `0x481`
   - `CMD_CLOSE` -> `0x483`, `0xC6B`, `0x3F2`

Verified `WM_COMMAND 0x464` branch handlers in `CMyShellDlg_WindowProc_DispatchMainWindowMessages`
(`0x5BB79D`) for startup command ids:

- submit branch at `0x5BC81B..0x5BC846`:
  - visibility gate through `CFlashHostDialog_IsWindowVisibleOrPendingActivation` (`0x5964C1`);
  - visible-path call to `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` (`0x4AEE6A`) at `0x5BC841`.
- submit prep inside `0x4AEE6A` resolves account/login endpoint using
  `CLoginFlashDlg_GetServerEndpointByServerRowAndRole` (`0x4AFE37`) with role code `2`
  (`ServerIP` / `ServerPort`) into local host/port buffers before auth packet setup.
- `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` (`0x4AEE6A`) calls
  `CGameMain_AccountSetupAndSendLoginAuthPacket` (`0x66D4C1`) and then posts
  `Conquer_PostMainWindowMessage464(0x482, 0)` at `0x4AF108`.
- `0x5C6EB0`:
  `CMyShellDlg_HandleStartupCommand0x480_SetStartupConnectFlag` (`this+0x179AAC = 1`).
- `0x5C6EC5`:
  `CMyShellDlg_HandleStartupCommand0x482_ClearStartupConnectAndOverlayFlags`
  (`this+0x179AAC = 0`, `this+0x179AB8 = 0`).
- `0x5C6EE4`:
  `CMyShellDlg_HandleStartupCommand0x481_ApplyFlashHostShowStateAndDispatchVariable`
  (startup host show/hide lifecycle + variable dispatch path).
- `0x5CAA2D`:
  `CMyShellDlg_HandleStartupCommand0x483_EnableWorldFrameGateAfterStartupLayoutChecks`
  (`this+0x179AB9 = 1` only on converged success path after startup checks).
- command `3` branch inside `0x5BB79D`:
  create-role transition path reached from server control talk `"NEW_ROLE"` after callback mode `0x3EC` is set.

## Verified Create-Role Host Contract (`role.dat`, own-UI replacement boundary)

BNinja anchors:

- `CRoleCreateFlashDlg_InitializeFlashMovieAndSeedVariables` (`0x51C0AB`)
- `CRoleCreateFlashDlg_HandleFlashCommandString` (`0x51C32E`)
- `CRoleCreateFlashDlg_SubmitCreatePlayerRequest` (`0x51C5C3`)
- `CRoleCreateFlashDlg_SendCreatePlayerCancelAndPostHostCommand481` (`0x51C54B`)
- `CRoleCreateFlashDlg_SetFlashVariableAndDispatch` (`0x51C1C3`)
- `CRoleCreateFlashDlg_SetProgressVariable` (`0x51C289`)

Verified native role-create host initialization:

- movie path: `%s/data/main/role.dat`
- seeded variables:
  - `PATH`
  - `USERACCOUNT`
  - `HIDERETURNBTN`

Verified command surface:

| Command | Verified native effect |
|---|---|
| `CMD_NICK` | writes nickname buffer at `this+0x14C` |
| `CMD_BODYSIZE` | parses integer and stores selector at `this+0x138` |
| `CMD_VOCATION` | parses integer and stores vocation index at `this+0x13C` |
| `CMD_DRIVERBACK` | sends cancel `1001` and posts `WM_COMMAND 0x464 / 0x481` |
| `CMD_ENTERGAME` | validates nickname, sets callback mode `0x3EC`, builds/sends `1001`, then pushes `PROGRESS` |
| `CMD_CLOSE` | posts `0x483`, `0xC6B`, `0x3F2` |
| `CMD_EXIT` | posts main-window command `0x55` |
| `CMD_GAMESTART` | posts `WM_COMMAND 0x464 / 0x480` |

Verified create submit field mapping:

- nickname length gate: `4..15`
- body mapping from `(vocation_index % 2, body_size == 1)`:
  - even vocation index -> `2001` / `2002`
  - odd vocation index -> `1003` / `1004`
- profession mapping from vocation index:
  - `0,1 -> 100`
  - `2,3 -> 10`
  - `4,5 -> 40`
  - `6,7 -> 20`
  - `8,9 -> 50`
  - `10,11 -> 60`

Verified status/result handling:

- create success is `1004 "ANSWER_OK"` handled by `CMyShellDlg_HandleCreateRoleStatusSystemTalk`.
- that branch clears startup connect flag, pushes `STR_CREATE_ROLE_SUCCESS` through `LOADING_TRACE`, and calls
  `CConnectionFlow__SendGameSessionBootstrap`.
- non-success create talk is surfaced to the role-create host as `ERROR`.

Own-UI replacement contract:

- our native UI may diverge visually from the Flash movie, but it must expose the full verified option surface
  above and send the same verified `1001` fields.
- option labels/descriptions for the own-UI screen may be sourced from shipped asset file
  `ini/selectCharacter.ini` (`affirmPanel`, `info`, `infoII`), while packet/body/profession mapping remains the
  BNinja-verified native contract.
- create success must continue on the same authenticated game session; do not force relogin in the own-UI path.

Status/progress callback contract in own-UI path (anchored to `0x5DCEA3` branch behavior):

- no `LOADING_TRACE`/`PROGRESS` while idle pre-connect login UI is shown;
- on submit/connect begin, own-UI enters connecting state and dispatches one ready pulse:
  `PROGRESS=80` + `LOADING_TRACE(0x2BE8)`;
- after ready pulse, connecting status uses `LOADING_TRACE(0x2BE7)` only;
- callback payloads remain presentation-only and are not permitted to trigger world enable.

## Verified timeout/error signal path and own-UI replacement

BNinja anchors in `CLoginFlashDlg_HandleFlashCommandString` (`0x4AA0AE`):

- `CMD_TIMEOUT` compare branch:
  - compare at `0x4AA582`;
  - zero `lParam` pushed at `0x4AA58D`;
  - `Conquer_PostMainWindowMessage464(0x55, 0)` reached through shared call site
    (`0x4AAA08 -> 0x4AA24D`).
- `CMD_ERROR_RET` compare branch:
  - compare at `0x4AA9E1`;
  - when `g_startupMovieFacebookVariantEnabled != 0`, zero `lParam` is pushed at `0x4AAA07`,
    then same `0x55` post path executes (`0x4AAA08 -> 0x4AA24D`).

This confirms native startup error/timeout signaling is routed by command id `0x55`, not by direct
world-frame enable commands.

Managed own-UI replacement contract (`main-own-ui`):

1. connect request validates selected startup endpoint shape (`host` non-empty, `port` range) and enters submit/connecting flow;
2. submit flow preserves native command ordering (`SetLoginUser` -> `SetLoginPassword` -> `0x480`);
3. runtime does not open a pre-submit TCP probe socket before posting `0x480` (matches native host behavior);
4. if endpoint shape is invalid or connect watchdog expires, connecting state is cleared and an explicit
   user-visible failure status is emitted (no indefinite spinner);
5. world-enable flow (`0x483`, `0xC6B`, `0x3F2`) remains a distinct success-stage transition and is
   not coupled to startup status-text callbacks.

Account-first routing requirement derived from the verified message split:

- `0x480` is the startup submit command routed through the `0x5BC81B..0x5BC846` branch
  (host-visible gate + submit call to `0x4AEE6A`), and submit completion posts `0x482`.
- startup flag writers remain explicit:
  - `0x5C6EB0`: sets `this+0x179AAC = 1`;
  - `0x5C6EC5`: clears `this+0x179AAC = 0`, `this+0x179AB8 = 0`.
- world-frame enable is a separate success-path command (`0x483` at `0x5CAA2D`).
- therefore startup submit endpoint must target the login/account service first; game/world endpoint
  activation is downstream from login success and must not be pre-wired as the first startup connect
  target in own-UI defaults.
- local own-UI hardwired default endpoint is `127.0.0.1:9958` (AccountServer login port), not game port `5816`.
- authenticated handoff then splits cleanly:
  - `"ANSWER_OK"` -> world bootstrap gate -> `0x483`
  - `"NEW_ROLE"` -> create-role transition -> `0x464 / 3`

## Own-UI registration extension (non-native feature, `main-own-ui`)

Retail 5517 does not register an account over the account-server packet stream. The startup SWF
Register button selects the OEM registration URL when configured, otherwise the default registration
URL, and calls `fscommand("CMD_GETURL", url)`. `CLoginFlashDlg_HandleFlashCommandString` handles
`CMD_GETURL` at `0x4AA86E` by passing that URL to `ShellExecuteA`. Account creation therefore remains
a website operation in the shipped client; packets `1084`, `1098`, `1102`, and `1121` are login
authentication variants, not registration requests.

The rebuilt client adds registration as an explicitly project-owned extension:

- `LOGIN` button keeps the verified native-equivalent submit route:
  `SetLoginUser` -> `SetLoginPassword` -> post `WM_COMMAND 0x464 / wParam=0x480`.
- `REGISTER` uses the same account endpoint, packet-1059 seed exchange, login-stream cipher, and
  native credential-field transform as login, but uses reserved OpenConquer packet IDs:
  - request `0xF001` (`260` bytes): `[length][id][accountName:128][encryptedCredential:128]`;
  - response `0xF002` (`8` bytes): `[length][id][resultCode:uint32]`.
- response result codes are `0=Success`, `1=InvalidRequest`, `2=AccountNameTaken`, and `3=Failed`.
- AccountServer now treats login and registration as separate operations:
  - login path authenticates only (no account auto-create);
  - register path creates an account only and returns failure when the username already exists;
  - registration never emits native auth response `1055`, creates a game-login ticket, or enters
    the post-authentication game handoff.

UI status contract for register:

- success: `ACCOUNT REGISTERED`
- duplicate username: `ACCOUNT NAME TAKEN`
- transport/endpoint failure: same endpoint/offline status family as login submit.

## Verified startup submit credential-buffer + legacy transport cipher contract (2026-03-11)

BNinja anchors added for the startup submit packet path that executes after `WM_COMMAND 0x464 / 0x480`:

- password command producer:
  - `CLoginFlashDlg_HandleFlashCommandString` (`0x4AA0AE`) `CMD_PASSWORD` branch
    (`0x4AA7B3..0x4AA852`);
  - calls `CGameInput_ResetPasswordKeypadSeedFromAccount` (`0x59F02D`) before per-byte
    `CGameInput_EncodePasswordCharForLoginBuffer` (`0x59EECA`);
  - writes encoded password into startup encrypted buffer object at `this+0x414` via
    `CEncryptedCredentialBuffer_SetPlaintext` (`0x7148B0`) at `0x4AA852`.
- submit credential field encrypt call:
  - `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` (`0x4AEE6A`) passes `this+0x414` into
    `CGameMain_AccountSetupAndSendLoginAuthPacket` (`0x66D4C1`);
  - `0x66D4C1` invokes `CEncryptedCredentialBuffer_EncryptField` (`0x71459F`) before packet create/send.

### Encrypted credential buffer object layout and write contract (`this+0x414`)

Verified from `CEncryptedCredentialBuffer_SetPlaintext` (`0x7148B0`) and
`CEncryptedCredentialBuffer_EncryptField` (`0x71459F`):

| Offset | Field | Verified behavior |
|---|---|---|
| `+0x000..+0x0FF` | stream key material (256 bytes) | consumed by per-byte XOR phase (`index mod 0x100`) |
| `+0x104` | plaintext length | set to `strlen(input)` (assert `< 0x100`) |
| `+0x108..+0x207` | mixed plaintext working bytes | zeroed then `strncpy` copy of encoded password |

`CEncryptedCredentialBuffer_SetPlaintext` (`0x7148B0`) applies this per-byte mix on indices
`0..length` inclusive (NUL included):

```
mixed[i] ^= ((i - 0x29) * i * 0x67) ^ key[i & 0xFF] ^ (((i >> 4) * 0x66) & 0xFF)
```

`CEncryptedCredentialBuffer_EncryptField` (`0x71459F`) then:

1. clamps requested output length to `0x100`;
2. copies 256 bytes from `buffer+0x108` into local scratch;
3. calls RC5 transform (`Rc5CredentialTransform_EncryptInPlace`, `0x749B55`) with key bytes sourced from `buffer+0x000`;
4. copies requested output bytes to destination (caller uses `0x20` or `0x80` in `0x66D4C1` branches).

### Verified `CGameMain_AccountSetupAndSendLoginAuthPacket` authentication matrix (2026-08-10)

The corrected 12-argument prototype at `0x66D4C1` exposes an explicit native auth-mode input:

- `LoginAccountAuthMode_Standard = 0`;
- `LoginAccountAuthMode_BoundAccount = 1`;
- `LoginAccountAuthMode_PictureKeyChallenge = 2`.

Verified packet selection:

| Native condition | Packet | Verified purpose |
|---|---:|---|
| `AccountSetup/Type == 1` | `1060` | OEM account setup; full `0x80` credential transform |
| default type, Standard mode, ordinary login | `1060` | standard login; `0x20` transformed credential prefix and zero-filled remainder |
| default type, Standard mode, non-empty mobile-protection value | `1102` | standard login with mobile protection |
| default type, Standard mode, Facebook startup variant | `1121` | account type `2`, UIN, encrypted session, and server |
| default type, BoundAccount mode, no mobile-protection value | `1084` | bound-account authentication |
| default type, BoundAccount mode, non-empty mobile-protection value | `1098` | bound-account authentication with mobile protection |
| default type, PictureKeyChallenge mode | `1102` | picture-key challenge authentication, optionally with mobile protection |

None of these branches performs account registration. Packet `1075` is the server-to-client
picture-key challenge packet used by the challenge path.

The two native `1060` producers share the same `CMsg1060__Create` writer, but they do **not** use
the same `CEncryptedCredentialBuffer_EncryptField` output length.

BNinja anchors:

- `IniReadIntFromResolvedStoreOrDefault(..., "ini/oem.ini", "AccountSetup", "Type", 0)` at `0x66D54B..0x66D565`
- `Type == 1` branch entry at `0x66D634`
- default / `Type != 1` branch entry at `0x66D59C`
- default non-Facebook `1060` create path at `0x66DA89..0x66DAD4`
- `Type == 1` `1060` create path at `0x66D67B..0x66D6C5`

Verified `1060` credential branch table:

| Native condition | Credential encrypt length | Packet creator | Notes |
|---|---:|---|---|
| `IniReadInt(... "AccountSetup","Type", 0) == 1` | `0x80` | `CMsg1060__Create` | legacy `1060`, full 128-byte encrypted field |
| `IniReadInt(... "AccountSetup","Type", 0) != 1`, Standard mode, ordinary non-Facebook login without mobile protection | `0x20` | `CMsg1060__Create` | default `1060`, encrypted prefix zero-padded to 128 bytes |

Evidence details:

- the config read at `0x66D54B..0x66D565` uses default value `0`;
- when the returned value equals `1`, code allocates RC5 state, calls
  `CEncryptedCredentialBuffer_EncryptField(arg2, ..., &var_148, 0x80)` at `0x66D68C`,
  then calls `CMsg1060__Create` at `0x66D6BD`;
- in the default non-Facebook submit path, code calls
  `CEncryptedCredentialBuffer_EncryptField(arg2, ..., &var_c4, 0x20)` at `0x66DA9B`,
  with the surrounding local `0x80` destination buffer zero-initialized at `0x66D761..0x66D797`,
  then calls `CMsg1060__Create` at `0x66DACC`.

Managed own-UI implication:

- the ordinary startup submit path used in this workspace must stay on the default
  `1060` branch: first `0x20` bytes encrypted, remaining `0x60` bytes zero-filled,
  then copied into the native `1060` packet field via `memcpy(..., 0x80)`;
- the separate `Type == 1` `1060` branch is real, but it is not interchangeable with the
  default no-session startup branch.

### Startup constructor-time initialization of `this+0x414`

Verified from login dialog constructor `sub_4A9A5F` (`0x4A9A5F`), which initializes the
startup credential buffer before any password entry:

1. `CEncryptedCredentialBuffer_Initialize(this+0x414)` at `0x4A9B8C`;
2. `srand(timeGetTime())` at `0x4A9C62..0x4A9C68`;
3. generate `16` random dwords, each composed from four `rand() % 0x100` bytes
   (`0x4A9C7F..0x4A9CD6`);
4. `CEncryptedCredentialBuffer_RepeatRandomWordsIntoKeyMaterial(this+0x414, randomWords, 0x10)`
   at `0x4A9CE3`;
5. `CEncryptedCredentialBuffer_GeneratePseudoRandomByteInRange(0x64, 1)` at `0x4A9CEE`;
6. `CEncryptedCredentialBuffer_SetPlaintext(this+0x414, "")` at `0x4A9CFB`.

This means the startup password buffer key material is not a fixed static table and is not
the pure LCG-only path unless that helper is explicitly called later.

### Legacy socket transport cipher contract for startup submit

Verified from `CGameSocket_SendBufferedPacket` (`0x6E1A07`),
`CGameSocketLegacyCipher_InitKeySchedule` (`0x6E2344`),
and `CGameSocketLegacyCipher_TransformBuffer` (`0x6E23A5`):

- send branch by `enc_state` in `0x6E1A07`:
  - `enc_state == 1` or `enc_state in {3,4}` -> calls
    `CGameSocketLegacyCipher_TransformBuffer(..., nSize, 1)` and queues exactly `nSize` bytes;
  - `enc_state == 2` and handshake complete -> uses DH/session transform path and appends encrypted
    `TQClient` trailer (`+8` bytes);
  - therefore legacy path does **not** append `TQClient` trailer bytes.
- key schedule init (`0x6E2344`):
  - stream A seed starts at `0x9D`, recurrence:
    `k = (((k * 0xFA) & 0xFF) + 0x0F) * k + 0x13` (byte-wrap each step);
  - stream B seed starts at `0x62`, recurrence:
    `k = ((0x79 - (k * 0x5C)) * k + 0x6D)` (byte-wrap each step);
  - both produce 256-byte tables.
- per-byte transform (`0x6E23A5`) using dual counters `(a,b)`:
  1. `x ^= tableA[a]`;
  2. `x ^= tableB[b]`;
  3. nibble-swap `x`;
  4. `x ^= 0xAB`;
  5. increment `a`; on wrap increment `b` (both wrap at `0x100`).

Own-UI implication for startup submit parity:

- startup account submit must use the legacy socket stream transform above for legacy-mode account packets;
- using DH `enc_state==2` framing/signature behavior for this submit stage alters on-wire bytes and breaks
  account-server frame parsing.
- because password encoding is keyed by the current account buffer (`this+0x198`) in the native
  `CMD_PASSWORD` path, the managed own-UI bridge must treat cached encoded-password bytes as
  account-dependent:
  - bootstrap/pre-filled `LOGINUSER` must seed the managed credential account state before first password submit;
  - any account-name change must invalidate the cached encoded-password buffer so submit re-encodes from the
    current `[account, password]` pair instead of reusing stale bytes.

## Verified startup account auth-response contract (`0x41F` / `1055`) (2026-03-11)

BNinja anchors for the account response path immediately after startup submit:

- `CMsgAccountAuthResponse__Ctor` (`0x7548A3`)
- `CMsgAccountAuthResponse__Parse` (`0x754909`)
  - calls `CNetMsg__ValidateHeaderAndCopy` (`0x6DF2AE`)
  - enforces `type == 0x41F` (`1055`)
- `CMsgAccountAuthResponse__Process` (`0x75492C`)
- `CMsgAccountAuthResponse__ProcessConnectToGameServerBranch` (`0x754D4C`)
- `CNetClient_ConnectWithEndpointAndTimeout` (`0x6DEF5F`)
- `CNetClient_SetSocketEncryptionMode` (`0x6DF1B0`)
- `CGameSocketLegacyCipher_ApplySessionXorMask` (`0x755DF3`)

### `1055` field layout consumed by native process path (`0x75492C`)

`CMsgAccountAuthResponse__Process` reads payload fields from `packet+4` (`this+0x404` pointer target):

| Payload offset | Type | Native use |
|---|---|---|
| `+0x00` | `u32` | session token / success gate (`!= 0` means success path) |
| `+0x04` | `u32` | auth key on success; response code on failure |
| `+0x08` | `u32` | game server port passed to `CNetClient_ConnectWithEndpointAndTimeout` |
| `+0x0C` | `u32` | hash/session field copied into hero runtime (`CHero+0xAA0`) |
| `+0x10` | `char[16]` | game server host C-string used for game-server connect |

### Branch table (`0x75492C` + `0x754D4C`)

Failure branch (`session token == 0`):

1. stop startup connect spinner/callback state (`CLoginFlashDlg_GetSingletonPtr` -> `0x578995`);
2. resolve/login-failure text using response code (`payload+0x04`);
3. write failure text to startup loading trace sink (`0x730D6C`, target `0x96B330`);
4. dispatch login-failure code handler (`0x6AA6A4`, target `0x96B328`).

Success branch (`session token != 0`):

1. persist success fields into hero runtime:
   - `CHero+0xA9C <- session token`
   - `CHero+0xAA0 <- payload+0x0C`;
2. call `0x663795(hero, payload+0x04)` with success-key field;
3. build/send first follow-up net packet using success token (`0x767D3B` -> `0x767DA1` -> `CNetMsg__Send`);
4. compute local XOR cookie: `cookie = (session token + payload+0x04) ^ 0x4321`;
5. read `res.dat` integer and build/send second follow-up packet (`0x754364` -> `0x7543CA` -> `CNetMsg__Send`);
6. disconnect account net client (`0x6DF043`);
7. copy game host (`payload+0x10`) to runtime host cache (`0x96AD5C`);
8. connect net client to game endpoint:
   - host = `payload+0x10`
   - port = `payload+0x08`
   - timeout = `0x1E` seconds
   - call target `CNetClient_ConnectWithEndpointAndTimeout` (`0x6DEF5F`);
9. if connect succeeds:
   - set net-client encryption mode `2` (`CNetClient_SetSocketEncryptionMode`, `0x6DF1B0`);
   - derive mask `payload+0x04 ^ cookie` and apply via
     `CGameSocketLegacyCipher_ApplySessionXorMask(socket+0x12014, mask)`;
   - set flash callback mode `0x3EB`;
   - post main-window messages `0x4E5` then `0x519`.
10. if connect fails:
    - clear startup connect callback state and write dataset string `0x18704` to loading trace sink.

### Verified post-`1055` success follow-up packets (`0x767DA1`, `0x7543CA`, `0x75443E`)

#### `1100` account follow-up (`CMsgAccountMacAddress1100__Build`, `0x767DA1`)

| Offset | Size | Field | Verified source |
|---|---|---|---|
| `+0x00` | `u16` | size = `52` | fixed |
| `+0x02` | `u16` | type = `1100` | fixed |
| `+0x04` | `u32` | session token | `1055.packet+0x04` |
| `+0x08` | `char[40]` | uppercase MAC text buffer | NetBIOS adapter MAC formatted as 12 hex chars, zero-filled on failure |

#### `1052` simple-string account follow-up (`CMsgMapInfo1052__BuildSimpleString`, `0x7543CA`)

| Offset | Size | Field | Verified source |
|---|---|---|---|
| `+0x00` | `u16` | size = `28` | fixed |
| `+0x02` | `u16` | type = `1052` | fixed |
| `+0x04` | `u32` | session token | `1055.packet+0x04` |
| `+0x08` | `u32` | local `res.dat` version | parsed with `fopen/fscanf`, default `0` on failure |
| `+0x0C` | `char[16]` | resource string | `"res.dat"` |

#### Post-DH game login proof (`CMsgMapInfo1052__Build`, `0x75443E`)

Verified caller `CMsgMapInfo1052__BuildAndSend` (`0x7544E8`) passes:

- `primaryMapValue = CHero+0xA9C` (session token)
- `secondaryMapValue = CHero__GetLoginAuthKey()` (auth key)
- `mode = 0x7C`
- `localeTag = GameDataSetQuery()->vtable+0x34(0x3F)` local buffer (two bytes copied)
- `hardwareKey = first NetBIOS MAC or zeros`
- `resourceVersion = local res.dat integer`

This confirms the managed own-UI startup path must transition from successful account auth into:

1. send `1100` on the account socket;
2. send simple-string `1052` on the account socket;
3. disconnect the account socket;
4. connect the game socket;
5. complete the native DH handshake path;
6. send the post-DH game `1052` (non-Facebook path).

### `1055` failure-code text contract (`code == 1` vs Facebook-only branch) (verified 2026-03-11)

BNinja anchors:

- `CMsgAccountAuthResponse__Process` (`0x75492C`)
  - Facebook-variant gate read at `0x75497E` (`g_startupMovieFacebookVariantEnabled`, `0x96AB34`)
  - response-code compare `== 1` at `0x754999`
  - generic formatter call `CMsgAccountAuthResponse_FormatLoginFailureTraceText` (`0x754011`)
    at `0x754ABD`
  - final failure-code sink call `CLoginFlashCallbackState_SetLoginFailureCode` (`0x6AA6A4`)
    at `0x754B48`.
- `CMsgAccountAuthResponse_FormatLoginFailureTraceText` (`0x754011`)
  - builds key `STR_CONNECT_ERROR_MSG_TYPE_%03u`
  - fallback key `STR_CONNECT_ERROR_MSG_TYPE_UNKNOWN`
  - wraps final text through `STR_LOGIN_FAIL`.

Failure text branch behavior:

1. when `g_startupMovieFacebookVariantEnabled != 0` **and** response code is `1`, startup path uses
   `STR_FACEBOOK_LOGIN_ERR` + `STR_LOGIN_FAIL` composition path in `0x75492C`;
2. all other cases (including non-Facebook startup for code `1`) route through
   `CMsgAccountAuthResponse_FormatLoginFailureTraceText`, which resolves
   `STR_CONNECT_ERROR_MSG_TYPE_%03u`.

Verified string-key payload values from clean `ini/Cn_Res.ini` (local asset source):

| Key | Text |
|---|---|
| `STR_CONNECT_ERROR_MSG_TYPE_001` | `Invalid Account ID or Password` |
| `STR_CONNECT_ERROR_MSG_TYPE_012` | `This account has been banned.` |
| `STR_CONNECT_ERROR_MSG_TYPE_057` | `Invalid Account ID` |

Parity implication for managed login/auth flow:

- wire code `1` is the generic invalid-credentials error code;
- `FacebookLoginError` wording is a presentation branch gated by the Facebook startup variant flag,
  not a distinct on-wire failure code.
- own-UI startup replacement should format visible login-failure text using the same non-Facebook
  composition contract:
  - resolve `STR_CONNECT_ERROR_MSG_TYPE_%03u`;
  - fall back to `STR_CONNECT_ERROR_MSG_TYPE_UNKNOWN`;
  - wrap final text through `STR_LOGIN_FAIL`;
  - therefore user-facing wrong-password / banned / invalid-account states must not collapse into a
    single generic `LOGIN FAILED` label.

### Evidence snippet (disassembly)

- `0x754951`: `cmp [eax+0x4], 0` (success gate on payload first dword).
- `0x754E1C..0x754E21`: `call 0x6DEF5F` with host `payload+0x14`, port `payload+0x0C`, timeout `0x1E`.
- `0x754E98`: `call 0x6DF1B0` with mode `2`.
- `0x754EFB` and `0x754F09`: `Conquer_PostMainWindowMessage464(0x4E5,0)` then `(0x519,0)`.

## Startup Visual Resource Handoff (Verified)

`CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` (`0x4AB5C5`) selects one startup movie payload:

- `%s/data/main/start.dat` (`0x4AB674`)
- `%s/data/main/start-facebook.dat` (`0x4AB68E`)

and passes the selected path to `CFlashControl_SetMoviePath(this+0xF8, path)` at `0x4AB6B9`.

Movie variant selection flag contract:

- source flag: `g_startupMovieFacebookVariantEnabled` (`0x96AB34`);
- producer: `ConquerApp_ParseLaunchArgumentsAndSetStartupMovieVariantFlag` (`0x5AAF10`) sets this
  flag to `1` when `sscanf(lpCmdLine, "%s %s %s %s %s", ...) == 5`;
- reset path: `CMyShellDlg_DispatchCommandCode` case `0x55` (`0x5B2A6B`) writes flag `0`.

### `start.dat` embedded Flash movie references

Verified by decompressing clean-5517 `start.dat` (CWS) and extracting `data/main/flash/*.swf` strings:

| Payload | Embedded SWF handoff set |
|---|---|
| `data/main/start.dat` | `data/main/flash/defaultR.swf` |
|  | `data/main/flash/defaultS.swf` |
|  | `data/main/flash/loginFlash.swf` |
|  | `data/main/flash/logo.swf` |
|  | `data/main/flash/unopenedR.swf` |
|  | `data/main/flash/unopenedS.swf` |
| `data/main/start-facebook.dat` | `data/main/flash/defaultR.swf` |
|  | `data/main/flash/defaultS.swf` |
|  | `data/main/flash/loginFlashFaceBook.swf` |
|  | `data/main/flash/logo.swf` |
|  | `data/main/flash/unopenedR.swf` |
|  | `data/main/flash/unopenedS.swf` |

This is the concrete startup visual resource handoff boundary used by the managed non-Flash startup visual stage.

### Startup `loadMovie` target-anchor contract (verified from startup SWF payload)

Clean `start.dat` action-script strings include deterministic `loadMovie` target names for startup
submovies:

- `data/main/flash/loginFlash.swf` -> target clip `loginFlashMC`
- `data/main/flash/logo.swf` -> target clip `logoMC`
- region slot chain (`defaultR`/`unopenedR`) -> target clip `sr`
- server slot chain (`defaultS`/`unopenedS`) -> target clip `ss`

Root timeline `PlaceObject2`/`PlaceObject3` named-anchor placements in `start.dat` stage coordinates:

- `loginFlashMC`: `(0, 0)`
- `logoMC`: `(0, 0)`
- `sr`: `(150, 381)`
- `ss`: `(685, 373)`
- extracted anchor matrices:
  - `sr`: `M00≈0.9803`, `M11≈0.9801`, `M01≈0`, `M10≈0`
  - `ss`: `M00≈1`, `M11≈1`, `M01≈0`, `M10≈0`

Managed non-Flash startup renderer contract:

- place startup referenced SWFs by mapped anchor name (`loginFlashMC`, `logoMC`, `sr`, `ss`);
- place selected group/server `FlashIcon` SWFs on `sr`/`ss` stage anchors respectively;
- preserve anchor matrix scale terms when drawing mapped overlays (width/height scale follows
  extracted `PlaceObject` matrix basis magnitude, not XY translation-only placement);
- do not center these overlays in viewport space when an anchor is resolved.

### Startup `loadMovie` frame-activation contract (verified host cadence + payload decode boundary)

- Native startup cadence:
  `SetTimer(this, id=1, 0x14ms, null)` in `CLoginFlashDlg_StartFlashLoopTimer` (`0x4AC610`) drives
  `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` (`0x4B04CE`) which calls
  `CLoginFlashDlg_TickFlashHostStateAndInputBridge` (`0x4AD9A9`), then `CWnd::Default`.
- Native startup timer cadence is independent from app idle frame gate (`ConquerApp_OnIdle`
  uses `timeGetTime` gate `+0x19` at `0x5AB543`); managed startup host therefore keeps a timer
  boundary schedule at 20ms slices instead of collapsing callback progression to 25ms idle cadence.
- Native startup host surface sizing:
  - `CLoginFlashDlg_OnInitDialog` (`0x4B0604`) calls
    `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport` (`0x4AEC64`);
  - `0x4AEC64` resizes both login dialog and embedded Flash control (`this+0xF8`) to the main shell
    viewport rect (`MoveWindow(..., 0,0,width,height, TRUE)` for both).
- Native C++ does not perform startup SWF `loadMovie` scheduling itself; it delegates movie execution to
  Flash host (`CFlashControl_SetMoviePath` / `SetVariable` / `GetVariableAsCString` via `CWnd::InvokeHelper`):
  - `SetMoviePath`: DISPID `0x66`;
  - `SetVariable`: DISPID `0x97`;
  - `GetVariableAsCString`: DISPID `0x98`;
  - supporting wrappers touched in this stage: `CFlashControl_StopActiveMoviePlayback` (DISPID `0x7E`)
    and `CFlashControl_GetFlashPlayerVersionCode` (DISPID `0x84`).
- Managed non-Flash replacement contract for referenced startup SWF overlays:
  - parse AVM1 action records (`DoAction`/`DoInitAction`) opcode-by-opcode:
    `ActionConstantPool`, `ActionPush`, `ActionStoreRegister`, `ActionGetVariable`,
    `ActionSetVariable`, `ActionDefineLocal`, `ActionDefineLocal2`,
    `ActionGetMember`, `ActionSetMember`, `ActionCallFunction`, `ActionCallMethod`;
  - preserve symbol identity for unresolved locals/member chains during decode:
    `ActionDefineLocal2` + `ActionGetVariable` keep variable-name expressions when concrete runtime
    values are unavailable, so object-chain targets (for example `self.son`) remain recoverable;
  - preserve symbolic register identity (`reg[N]`) when concrete register value is unknown so
    later `DefineLocal`/`GetVariable` object aliases can still resolve member-key chains;
  - resolve member chains from `ActionSetMember`/`ActionGetMember` into deterministic
    `object.member` keys before `ActionCallMethod`, so `loadMovie` method-object targets can
    decode to slot-like clip identifiers (`sr*` / `ss*`) without static path heuristics;
  - member-name fallback is retained for unresolved object aliases (`*.tagBmp`, `*.son`, etc.) so
    path/member values set earlier in the same action block remain readable at call time;
  - when `loadMovie` method target resolves to `.son` and immediate follow-up actions publish a
    slot-like `_name` literal (`ss1`/`sr1` etc.), decoder applies that deferred slot alias to the
    current callsite target clip in the same action branch;
  - recurse nested SWF tag streams in `DefineSprite` payloads so action blocks attached to embedded
    sprite timelines are included in decode;
  - recurse nested AVM1 function action blocks (`ActionDefineFunction`, `ActionDefineFunction2`) so
    `loadMovie` callsites inside helper functions are included in extraction;
  - decode `loadMovie` call arguments from action-stack state to recover referenced SWF path and
    target clip name;
  - extract earliest frame index per referenced `data/main/flash/*.swf` from these decoded
    `loadMovie` callsites;
  - frame indexing is 1-based SWF timeline space (`frame=1` prior to first `ShowFrame`);
  - draw a referenced startup SWF overlay only after primary startup movie frame reaches/exceeds that
    extracted activation frame;
  - when primary startup poster extraction is currently single-frame (`1/1`) but startup manifest
    frame count is known (`parsedFrames > 1`), activation frame progression uses manifest-frame
    timing on the startup movie clock instead of freezing at frame `1`;
  - if no activation frame is extractable for a referenced path, keep existing manifest-order behavior
    (no extra suppression) to avoid synthetic disappearance.
  - for a given startup target clip (`loginFlashMC`, `logoMC`, `sr*`, `ss*`), treat `loadMovie`
    events as replacement-over-time semantics: at frame `N`, render only the latest decoded
    referenced SWF bound to that target clip up to frame `N` (do not stack every historical movie
    loaded into the same clip).
  - target-clip ownership in replacement composition is single-surface:
    - startup referenced layer pass owns startup host clips (`loginFlashMC`, `logoMC`);
    - selected region/server presentation pass owns selection clips (`sr*`, `ss*`);
    - renderer must not draw `sr/ss` from both passes in the same frame, because native Flash host
      maintains one active display-list binding per target clip.
- Managed non-Flash slot-gating extension for selected region/server overlays:
  - slot activation is decoded from startup action bytecode `targetClip` values only;
  - region slot (`sr`) activation frame is the earliest extracted `loadMovie` with `targetClip=sr`;
  - server slot (`ss`) activation frame is the earliest extracted `loadMovie` with `targetClip=ss`;
  - slot-target matching accepts indexed clip aliases emitted by startup scripts
    (`sr1..srN`, `ss1..ssN`) by prefix rule;
  - selected `REGION` and selected `SERVER` SWF overlays are not drawn before their slot activation
    frame is reached on the primary startup timeline.
  - no static path-heuristic fallback (`defaultR/defaultS/unopened*`) is used in managed slot gating.
  - if startup decode yields no slot target event for `sr` or `ss`, that slot remains unresolved and
    managed runtime does not inject a synthetic gate window for it.
- Managed non-Flash stage-fit contract:
  - primary startup movie timeline is drawn into the full pre-world viewport using aspect-preserving
    stage fit (Flash-host `showAll` equivalent);
  - startup referenced overlays and selected `sr`/`ss` overlays keep startup stage-space anchor
    coordinates and are rendered with the same stage scale/offset transform.
  - final startup-layer presentation keeps source alpha during composition; transparent layer pixels
    do not replace lower startup layers with opaque black in the non-Flash host surface.

### Startup movie manifest extraction contract (managed replacement)

For non-Flash runtime parity instrumentation, `start.dat` / `start-facebook.dat` extraction now
tracks deterministic SWF structural events from the CWS/FWS payload:

- header contract: SWF signature (`CWS`/`FWS`), version, declared file length, declared frame count;
- timeline frame boundaries: `ShowFrame` tags;
- display placement operations: `PlaceObject` / `PlaceObject2` / `PlaceObject3` tags;
- audio events: `DefineSound`, `StartSound`, `SoundStreamHead`, `SoundStreamHead2`, `SoundStreamBlock` tags;
- command-hook token candidates from script payload tags (`DoAction`, `DoInitAction`) using stable ASCII token extraction;
- embedded startup referenced SWF paths extracted with case-insensitive prefix/extension matching
  (`data/main/flash/` + `.swf`) and normalized to forward slashes for deterministic runtime
  resolution on case-sensitive hosts.

Runtime consumption boundary in this slice is read-only state/diagnostic use: no synthetic behavior
is injected into command dispatch, timer cadence, or callback ordering.

BNinja callback anchors for hook parity during startup tick (`CLoginFlashDlg_TickFlashHostStateAndInputBridge`,
`0x4AD9A9`):

- reads `VAR_FOCUS` via `CFlashControl_GetVariableAsCString` at `0x4ADBC0`, `0x4ADDC1`, `0x4AE01B`;
- reads `VAR_STARTTOVC` / `VAR_ENDTOVC` in text-select branches and mirrors into
  `STARTTOFLASH` / `ENDTOFLASH` dispatches (`0x4ADCED`, `0x4ADD26`, `0x4ADF46`, `0x4ADF7F`,
  `0x4AE12F`, `0x4AE164`);
- this is the native host/Flash hook surface the manifest-driven non-Flash runtime must preserve.

## C++ → Flash Variables (Init Path)

Pushed during `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` (`0x4AB5C5`):

| Variable | Value source | Address | Purpose |
|---|---|---:|---|
| `PATH` | `this+0x1A4` (client root path, normalized) | `0x4AB6C7` | Asset root for Flash to resolve file paths |
| `SELECTBGMUSIC` | `[FlashMusic] Enable` from `ini/GameSetup.Ini` (default=1) | `0x4AB7BE` | "1" enable / "0" disable background music |
| `CURWORLD` | `this+0x190` (saved group index) | `0x4AB814` | Pre-select last-used server group |
| `CURSERVER` | `this+0x194` (saved server index) | `0x4AB84E` | Pre-select last-used server |
| `LOGINUSER` | `this+0x198` or `[Account] AccountRecord` from ini | `0x4ABF55` | Pre-fill saved account name |
| `ACCOUNT0`–`ACCOUNT9` | `[AccountList] Account0..9` from `ini/GameSetup.Ini` | `0x4ABCED` | Saved account dropdown list (max 10) |
| `RETURNLOGIN` | `"1"` when `this+0x159` flag set | `0x4ABF85` | Flag: returning to login from game session |
| `REGION` | Built by `CLoginFlashDlg_BuildAndPushServerListToFlash` | `0x4AD442` | Server group list (delimited string) |
| `SERVER` | Built by `CLoginFlashDlg_BuildAndPushServerListToFlash` (per group) | `0x4AD93E` | Server list per group (delimited string) |

`CURWORLD` / `CURSERVER` dispatch is raw-value pass-through in native:

- `0x4AB7FC` formats `this+0x190` then dispatches `CURWORLD` at `0x4AB814`;
- `0x4AB836` formats `this+0x194` then dispatches `CURSERVER` at `0x4AB84E`;
- no clamp/sanitize to positive range before these variable writes.

Managed replacement path-root contract from this producer boundary:

- startup movie + startup submovie references are treated as client-root-relative assets under
  `PATH` (`this+0x1A4`);
- server list producer base directory comes from `this+0x400` (`.\\Server` / `.\\Server%d`);
- runtime path resolution must reject rooted values and any normalized path escaping client root.

## C++ → Flash Variables (Runtime/Interaction)

| Variable | Source | Purpose |
|---|---|---|
| `LOGINPASS` | Cleared to empty | Clear password field in Flash |
| `LOGINMOBILEPROTECT` | Cleared to empty | Clear mobile protect field |
| `SHOW_SOFTKB` | Enable/disable flag | Show/hide soft keyboard overlay |
| `CHANGE_PICKEY` | Flag | Picture key change state |
| `SET_BINDTOOL_INSTALLED` | "1" or "0" | Whether bind tool is installed |
| `SHOW_SHORTPWDTIP` | "1" or "0" | Short password warning tip |
| `FOCUSTOFLASH` | Account selection focus state | Return focus to Flash after account select |
| `STARTTOFLASH` / `ENDTOFLASH` | Selection range | Text selection range for input fields |

## Variable Transport Encoding (`CLoginFlashDlg_SetFlashVariableAndDispatch`)

All logical variable writes above are transported through one Flash variable key:

- Flash variable key: `VCTOFLASH`
- Payload format: `<VariableName>|<VariableValue>`
- Delimiter byte: `0x7C` (`'|'`) at `0x92611C`

Disassembly/decompile anchors:

- `CLoginFlashDlg_SetFlashVariableAndDispatch` (`0x4AC6C4`) builds payload by concatenating:
  1. variable name argument
  2. delimiter (`0x7C`)
  3. variable value argument
- then calls `CFlashControl_SetVariable(this+0xF8, "VCTOFLASH", payload)` at `0x4AC77E`.

## REGION Variable Format

Built by `CLoginFlashDlg_BuildAndPushServerListToFlash` (`0x4AD12F`):

```
count#name1%icon1$name2%icon2$...
```

- `count` = number of groups (integer)
- `#` = header separator
- For each group: `FlashName%FlashIcon` (attributes from data source tree)
- `$` = group separator
- Data source: tree structure accessed via vtable `+0x04` (GetChildCount) and `+0x14` (GetAttribute)
- Attribute keys: `"Child"` (child node count), `"FlashName"`, `"FlashIcon"`
- Emission cadence:
  - init call path emits once at `0x4ABF91` (third arg `0`)
  - refresh call path emits once at `0x4AD9D7` when `this+0x61D != 0 && this+0x61C == 0`.

`FlashIcon` is transported as an opaque attribute string from server data source (`GetAttribute("FlashIcon")`).
Native C++ host code does not parse/icon-map this value before dispatch:

- group path appends `FlashIcon` when `eax_28 != null && _stricmp(eax_28, "NULL") != 0` at `0x4AD3FD..0x4AD423`
- server path appends `FlashIcon` when `eax_59 != null && _stricmp(eax_59, "NULL") != 0` at `0x4AD717..0x4AD739`
- no extension/pattern gate exists in this C++ producer path.

Managed non-Flash replacement contract (this slice):

- resolve `FlashIcon` as an opaque startup asset token (`.bmp` or `.swf`)
- resolution order for relative values:
  1. `<clientRoot>/<FlashIcon>`
  2. `<clientRoot>/data/main/<FlashIcon>`
  3. `<clientRoot>/data/main/flash/<FlashIcon>`
- no inferred numeric/icon-name remapping (for example no synthetic `LoginG{N}Img.bmp` mapping).
- for `.swf` icon payloads, non-Flash runtime extracts deterministic poster candidates from
  SWF `DefineBitsLossless2` (`tag 36`, format `5`) records and renders frame-stepped timeline output.
  Current managed parity stage composes the full resolved display-list layer stack per frame
  (depth order) instead of sampling only a single topmost symbol.
- managed SWF timeline decode scope for icon resources:
  `PlaceObject`/`PlaceObject2`/`PlaceObject3`, `RemoveObject`/`RemoveObject2`, `ShowFrame`,
  nested `DefineSprite`, shape-to-bitmap indirection (`DefineShape`/`DefineShape2`/`DefineShape3`
  bitmap fill styles), and `DefineButton2` display-state records (state-up preferred for
  initial non-interaction composition; button-record filter lists are parsed/skipped for
  startup decode instead of forcing symbol rejection),
  JPEG symbol images (`DefineBitsJPEG2`/`DefineBitsJPEG3` + JPEG3 alpha stream), and lossless
  symbol images (`DefineBitsLossless2` ARGB32), with managed depth-order alpha compositing of
  resolved display-list posters into the per-frame output surface.
- managed shape bitmap-fill rasterization contract:
  - for `DefineShape*` symbols that use bitmap fill styles (`0x40..0x43`), runtime must parse
    `SHAPEWITHSTYLE` records and rasterize fill geometry (not just bind the bitmap character id);
  - shape `StateNewStyles` segments are parsed as appended style arrays with updated fill/line bit
    widths, so style switches inside the same shape keep authored bitmap atlas mappings;
  - bitmap fill sampling uses the style matrix as a shape-to-bitmap mapping (inverse matrix sample),
    preserving atlas sub-rect placement/scale semantics used by startup UI assets;
  - rasterized shape posters preserve non-zero shape-bounds minima as local transform offsets on the
    resolved layer, so symbol origin placement matches Flash-host bounds semantics;
  - per-symbol fallback to shape->bitmap substitution is allowed only when the shape uses
    currently unsupported record features; no global icon remap or synthetic shape atlas table.
- managed clipping contract for `PlaceObject2`/`PlaceObject3`:
  when `HasClipDepth` is present, that entry is treated as a mask layer for subsequent display-list
  entries with depth in `(maskDepth, clipDepth]`; mask layers are not drawn as visible color layers.
  Nested mask scopes combine multiplicatively on destination alpha.
- managed placement contract (replacement stage):
  - SWF `RECT` header is decoded for stage bounds (pixel canvas sizing);
  - per-entry placement matrix from `PlaceObject`/`PlaceObject2`/`PlaceObject3` is decoded
    (`scale`, `rotate/skew`, `translate`) and applied during compositing;
  - `PlaceObject2`/`PlaceObject3` `CXFORMWITHALPHA` is applied as alpha modulation
    (`mult` + `add`) on each display-list layer;
  - frame output is rendered on stage-space coordinates (matrix placement), not implicit centered
    symbol stacking.
  - nested sprite/local timelines (no explicit stage rect) derive composition canvas from
    transformed display-list bounds (`min/max` over affine-transformed layer extents), so translated
    child layers are not clipped to untransformed symbol dimensions.
- startup host update cadence remains the verified native timer path:
  `SetTimer(id=1, interval=0x14)` (`0x4AC620`) -> timer callback (`0x4B04CE`) -> host tick (`0x4AD9A9`);
  managed SWF frame stepping aligns to this cadence boundary.
- managed startup SWF decode orchestration:
  - timeline extraction is queued asynchronously per startup SWF path;
  - startup movie warm-up is issued at `SetMoviePath` boundary (managed mirror of native
    `CFlashControl_SetMoviePath` handoff timing) before steady frame callbacks;
  - pre-loop initialization hook (before steady pre-world ticks) warms selected
    `REGION`/`SERVER` icon SWF paths using produced payload + selection seed (`CURWORLD`/`CURSERVER`);
  - frame callback path samples only ready timelines and never blocks on first-load decode;
  - while pending, runtime draws a `DlgLogo/BgFormat` fallback or already-ready startup layers.
    **Non-parity:** only the `DlgLogo/BgFormat` *resolution rule* is native (`0x4B08B9`). Native never
    draws that bitmap outside `CStartupLogoDialog`'s one-shot init lifetime, and never in the pre-world
    frame loop — see `20_notes/Architecture/02_conquer_client_startup_chain.md`,
    "Ownership: initialization-only, single instance".
- native Flash host boundary remains COM/ActiveX invocation:
  - `CFlashControl_SetMoviePath` (`0x5EA89A`) -> `CWnd::InvokeHelper` DISPID `0x66`
    with signature descriptor `CFlashControl_InvokeHelperSignature_SetMoviePath_Bstr` (`0x93907C`)
  - `CFlashControl_SetVariable` (`0x5EA8EB`) -> `CWnd::InvokeHelper` DISPID `0x97`
    with signature descriptor `CFlashControl_InvokeHelperSignature_SetVariable_BstrBstr` (`0x9390DC`)
  - `CFlashControl_GetVariableAsCString` (`0x5EA90F`) -> `CWnd::InvokeHelper` DISPID `0x98`
    with signature descriptor `CFlashControl_InvokeHelperSignature_GetVariableAsCString_OutBstr` (`0x9390E0`)
  - no C++ SWF tag-level renderer exists in this path.

Managed pre-world visual host layering contract (replacement-only, native host boundary preserved):

1. `start.dat` / `start-facebook.dat` timeline is the primary host surface.
2. startup movie referenced SWFs from manifest order (`ReferencedFlashMovieRelativePaths`) are sampled as
   startup overlays.
3. selected `REGION` and selected `SERVER` `FlashIcon` SWFs are sampled as top overlays.
4. only when startup SWF layers are unresolved, fallback is the `DlgLogo/BgFormat` bitmap.
   **Replacement-only:** native has no pre-world logo fallback; the bitmap's *path resolution* is the
   only verified part.
5. file path lookup uses case-insensitive resolution parity for startup asset paths
   (`FlashIcon` and startup referenced SWFs) to match native Windows file-open semantics.
6. referenced startup SWFs and selected region/server SWFs use startup-stage anchor placement
   (`loginFlashMC`/`logoMC`/`sr`/`ss`) when anchors are available from startup movie root timeline.
7. startup movie variant selection mirrors native launch-token gate:
   - `start-facebook.dat` when launch token count is at least 5;
   - otherwise `start.dat`.

## SERVER Variable Format (Per Group)

```
groupIndex#childCount#name1%icon1%hint1%status1$name2%icon2%hint2%status2$...
```

- `groupIndex` = 1-based group index
- `childCount` = number of servers in this group
- For each server:
  - `FlashName` = display name
  - `FlashIcon` = icon identifier
  - `FlashHint` = server description/hint
  - status = integer from `ServerListEntry_ResolveFlashStatusCode` (`0x5EA5A2`, server load/status check)
  - `ServerName` attribute used for connection target lookup
- Server indices start at `0x65` (101) per group, incrementing by `0x64` (100) per group
- `$` = server separator, `%` = field separator
- Emission cadence/order:
  - emitted inside per-group loop at `0x4AD93E` (one dispatch per group iteration)
  - payload buffer is initialized once (`0x4AD452`) and appended cumulatively across group iterations
    before each dispatch (not reset per group).
- Status value contract:
  - default status seed is `3` when build arg3 is `0` (`0x4AD835`)
  - when arg3 is non-zero, status is resolved by
    `ServerListEntry_ResolveFlashStatusCode(this+0x404, ServerName)` at `0x4AD8B4`.
- One-shot refresh gate:
  - refresh thread sets `this+0x61D = 1` via `CLoginFlashDlg_SetLoadThreadRunningFlag` (`0x4B05B3`)
  - build refresh call consumes that state and sets `this+0x61C = 1` at `0x4AD963`.

## Flash → C++ Command Contract

All commands dispatched via `CLoginFlashDlg_HandleFlashCommandString` (`0x4AA0AE`).
`_Str1` = command name, `_Format_3` = command value/parameter.

### Server/Group Selection

| Command | Parameter | Side Effects | Address |
|---|---|---|---:|
| `CMD_SELECTGROUP` | group index (int string) | Stores `atoi(param)` to `this+0x190`, calls `CHero_GetSingletonPtr()` with group+server | `0x4AA0E7` |
| `CMD_SELECTSERVER` | server index (int string) | Stores `atoi(param)` to `this+0x194`, calls hero singleton, checks bind tool, may show soft KB | `0x4AA127` |
| `CMD_SAVEWORLD` | group index | Same handler as `CMD_SELECTGROUP` | `0x4AA0E7` |
| `CMD_SAVESERVER` | (trigger) | Writes `[Server] ServerRecord`, `[Group] GroupRecord`, `[Account] AccountRecord` to `ini/GameSetup.Ini` | `0x4AB5C7` |
| `CMD_DELETESAVE` | (trigger) | Calls `CLoginFlashDlg_ClearSavedGroupServerAndAccountRecords` | `0x4AA686` |

### Account/Login

| Command | Parameter | Side Effects | Address |
|---|---|---|---:|
| `CMD_NAME` | username string | `snprintf` to local buffer → stores to `this+0x198` (French locale: special encoding) | `0x4AA749` |
| `CMD_PASSWORD` | password string | `snprintf` → per-char encrypt via `CGameInput_EncodePasswordCharForLoginBuffer` (`0x59EECA`) → stores to `this+0x414` (French locale handling) | `0x4AA7D7` |
| `CMD_SELECTACCOUNT` | account name | If differs from current: clears fields, copies to `this+0x198`, pushes `LOGINUSER`/`FOCUSTOFLASH`/`STARTTOFLASH`/`ENDTOFLASH` | `0x4AA4BA` |
| `CMD_CLEARACCOUNT` | (trigger) | Calls `CLoginFlashDlg_DeleteSavedAccountAndRefreshAccountList` | `0x4AA572` |
| `CMD_RECORDACCOUNT` | (trigger) | Calls `CLoginFlashDlg_RecordAccountAndPushAccountListToFlash` — manages max-10 account list in ini, pushes `ACCOUNT0`–`ACCOUNT9` to Flash | `0x4AA26C` |

### Game Start / Navigation

| Command | Parameter | Side Effects | Address |
|---|---|---|---:|
| `CMD_ENTERGAME` | (trigger) | Posts `Conquer_PostMainWindowMessage464(0x480, 0)`, then `CLoginFlashDlg_RecordAccountAndPushAccountListToFlash` | `0x4AA228` |
| `CMD_GAMESTART` | mode (1/2/3) | Reads `VAR_STARTTOVC`/`VAR_ENDTOVC` from Flash, stores to mode-specific fields, calls login handler, posts `0x480` | `0x4AA23C` |
| `CMD_CLOSE` | (trigger) | `KillTimer(1)`, clears Flash movie, posts `0x483` (world enable), `0xC6B`, `0x3F2` | `0x4AA69F` → `0x4AC621` |
| `CMD_PREV` | (trigger) | Navigation previous | `0x4AA1D8` |
| `CMD_NEXT` | (trigger) | Navigation next | `0x4AA1ED` |
| `CMD_RETURN` | (trigger) | Return/back navigation, calls `CLoginFlashDlg_HandleReturnNavigation` or `CRoleCreateFlashDlg_PostMainWindowMessage55` | `0x4AA20B` |
| `CMD_TEXTSELECT` | mode (1/2/3) | Reads `VAR_STARTTOVC`/`VAR_ENDTOVC`, stores selection range to mode-specific fields | `0x4AA285` |
| `CMD_TIMEOUT` | (trigger) | Posts `Conquer_PostMainWindowMessage464(0x55, 0)` | `0x4AA582` |

### Settings/Persistence

| Command | Parameter | Side Effects | Address |
|---|---|---|---:|
| `CMD_SELECTBGMUSIC` | "0" or "1" | `WritePrivateProfileStringA("FlashMusic", "Enable", value, "ini/GameSetup.Ini")` | `0x4AAA15` |

### External Actions (ShellExecute)

| Command | URL Source | Address |
|---|---|---:|
| `CMD_MODIFYPASSWORD` | `STR_DISCONNECT_MODIFYPAGE` string resource | `0x4AA3AF` |
| `CMD_BANACCOUNT` | `STR_BANACCOUNT_URL` or `STR_DISCONNECT_REQUESTPAGE` | `0x4AA42B` / `0x4AA88D` |
| `CMD_RELEASEACCOUNT` | `STR_RELEASEACCOUNT_URL` string resource | `0x4AA8EE` |
| `CMD_GETURL` | parameter directly as URL; used by the retail SWF Register action | `0x4AA86E` |

### Input/UI Control

| Command | Parameter | Side Effects | Address |
|---|---|---|---:|
| `CMD_SHOW_SOFTKB` | (trigger) | Show soft keyboard, calls `CLoginFlashDlg_ShowSoftKeyboardAndSyncFlags` | `0x4AA947` |
| `CMD_SOFTKEYDOWN` | key string or "backspace" | Sends key to focused control via `CGameInput_SendSoftKeyboardTextOrBackspace` | `0x4AA95B` |
| `CMD_INSTALL_PWDPROTECT` / `CMD_ACTIVE_PWDPROTECT` | (trigger) | Password protection flow, calls `CLoginFlashDlg_HandlePasswordProtectCommand` | `0x4AA9BC` |

### Error/Debug

| Command | Parameter | Side Effects | Address |
|---|---|---|---:|
| `CMD_ERRORWINDOW` | flag (int string) | Sets `this+0x3E8` error byte (AND or direct set depending on value) | `0x4AA6BC` |
| `CMD_ERROR_RET` | (trigger) | If `data_96AB34 != 0`, posts `Conquer_PostMainWindowMessage464(0x55, 0)` | `0x4AA9E1` |
| `CMD_CRITICAL_RET` | (trigger) | Posts `Conquer_PostMainWindowMessage464(0x55, 0)` | `0x4AA9F2` |
| `TRACE` | message | Shows `CWnd::MessageBoxA` with trace content | `0x4AA6F2` |

## CLoginFlashDlg Field Layout (Verified Subset)

| Offset | Type | Name | Evidence |
|---:|---|---|---|
| `+0x0F8` | CFlashControl | flashControl | `CFlashControl_SetMoviePath` calls |
| `+0x138` | int32 | boundAccountRecordIndex | read by `CLoginFlashDlg_ReadBoundAccountRecordValue` |
| `+0x150` | int32 | pictureKeyState | auth mode: `0` standard, `1` bound-account metadata recovery, `2` picture-key challenge |
| `+0x154` | byte | successfulAccountBindResult | queried by `CLoginFlashDlg_HasSuccessfulAccountBindResult` |
| `+0x155` | byte | unknown_155 | cleared in CMD_CLOSE handler |
| `+0x156` | byte | bindToolInstalledFlag | checked in CMD_SELECTSERVER |
| `+0x158` | byte | unknown_158 | checked in login field visibility |
| `+0x159` | byte | returnLoginFlag | checked/cleared in init, sets `RETURNLOGIN` var |
| `+0x15C` | ptr | gameInputHandle | GameInput control handle |
| `+0x190` | int32 | selectedGroupIndex | CMD_SELECTGROUP/SAVEWORLD target |
| `+0x194` | int32 | selectedServerIndex | CMD_SELECTSERVER target |
| `+0x198` | CString | currentAccountName | CMD_NAME/SELECTACCOUNT target |
| `+0x1A4` | CString | clientRootPath | normalized path, pushed as `PATH` |
| `+0x1B0` | CString | mobileProtectValue | cleared by ClearPasswordAndMobileProtectFields |
| `+0x1BC` | CString | pictureKeyChallenge | populated from packet `1075` and passed to account auth setup |
| `+0x1D4` | CString | facebookUin | passed to the native `1121` creator path |
| `+0x1E0` | CString | facebookSessionKey | passed to the native `1121` creator path |
| `+0x3E8` | byte | errorWindowFlag | set by CMD_ERRORWINDOW |
| `+0x3EC`–`+0x3F8` | int32×4 | textSelectRangeFields | set by CMD_GAMESTART/CMD_TEXTSELECT mode branches |
| `+0x400` | ptr | serverListDataSource | tree-structured server config data |
| `+0x404` | obj | flashMovieLoadState | load progress object |
| `+0x414` | CString | encryptedPasswordBuffer | CMD_PASSWORD target (per-char encrypted) |
| `+0x61C` | byte | serverListPushedFlag | set after first server list push |
| `+0x61D` | byte | loadThreadStartedFlag | prevents duplicate load thread |

### `serverListDataSource` root seed and dispatch call chain (verified)

`CLoginFlashDlg_PrepareServerRootAndSelectionFromIni` (`0x4AAA49`) seeds
`CLoginFlashDlg+0x400` before startup variable dispatch:

- reads `ini/oem.ini` `[Oem] id` into `this+0x3FC`;
- `id == 0`: writes `this+0x400 = ".\\Server"` (`0x4AAB65`);
- `id != 0`: formats `this+0x400 = ".\\Server%d"` (`0x4AB0DF`);
- seeds `this+0x190` / `this+0x194` from `ini/GameSetup.Ini` or fallback
  `ini\\DefaultGameSetup.ini` group/server records.

`CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` (`0x4AB5C5`) then calls
`CLoginFlashDlg_BuildAndPushServerListToFlash` at `0x4ABF91`.
`CLoginFlashDlg_BuildAndPushServerListToFlash` reads root path from `this+0x400`
(`0x4AD152`) and dispatches `REGION` (`0x4AD442`) and `SERVER` (`0x4AD93E`) payloads.

`CLoginFlashDlg_StartFlashLoopTimer` (`0x4AC5FA`) verified call order before timer arm:

1. `CLoginFlashCallbackState_InvokeProviderMethod8IfPresent(CLoginFlashDlg_GetSingletonPtr())` at `0x4AC604`
2. `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` at `0x4AC60B`
3. `SetTimer(this+0x20, id=1, interval=0x14)` at `0x4AC620`

This is the exact producer path ordering used before steady startup timer ticks.

## BNinja Renames Applied (This Slice)

| Address | Verified Name |
|---:|---|
| `0x59E59F` | `CGameInputString_ProcessFrameInputAndSelection` |
| `0x59F1C7` | `CGameInputString_IsKeyCodePressed` |
| `0x59F0EE` | `CGameInputString_GetTextByOutputMode` |
| `0x59F19C` | `CGameInputString_SetTextFromCString` |
| `0x59F1B5` | `CGameInputString_WriteTextToBuffer` |
| `0x5EA5EB` | `ServerStatusCatalog_LoadFromCommonIniUrl` |
| `0x5EA504` | `ServerStatusEntryVector_ClearAndFree` |
| `0x5EA468` | `ServerStatusEntry_ctor` |
| `0x5EA7D8` | `ServerStatusEntryVector_PushBack` |
| `0x4AC3FA` | `CLoginFlashDlg_ClearPasswordAndMobileProtectFields` |
| `0x4AFA67` | `CLoginFlashDlg_UpdateLoginFieldVisibilityAndShortPwdTip` |
| `0x4AC7A3` | `CLoginFlashDlg_RecordAccountAndPushAccountListToFlash` |
| `0x4AD12F` | `CLoginFlashDlg_BuildAndPushServerListToFlash` |
| `0x4AEC64` | `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport` |
| `0x4AEB9E` | `CLoginFlashDlg_ClearSavedGroupServerAndAccountRecords` |
| `0x4AE304` | `CLoginFlashDlg_DeleteSavedAccountAndRefreshAccountList` |
| `0x4ABFBD` | `CLoginFlashDlg_HandleReturnNavigation` |
| `0x51C09D` | `CRoleCreateFlashDlg_PostMainWindowMessage55` |
| `0x4AF616` | `CLoginFlashDlg_ShowSoftKeyboardAndSyncFlags` |
| `0x4AECC5` | `CLoginFlashDlg_HandlePasswordProtectCommand` |
| `0x4AAA49` | `CLoginFlashDlg_PrepareServerRootAndSelectionFromIni` |
| `0x59E590` | `CGameInput_SendSoftKeyboardTextOrBackspace` |
| `0x59E565` | `CGameInput_HasFocusableTextEntryControl` |
| `0x59EF03` | `CGameInput_TryMapAsciiToVirtualKeyAndShiftFlag` |
| `0x59EF7B` | `CGameInput_MapVirtualKeyToLoginCipherByte` |
| `0x59EECA` | `CGameInput_EncodePasswordCharForLoginBuffer` |
| `0x6639B1` | `CHero_SetSelectedGroupAndServerIndices` |
| `0x5789BC` | `CLoginFlashCallbackState_InvokeProviderMethod8IfPresent` |
| `0x4AF2C7` | `CLoginFlashDlg_BeginAccountBindServerHandshake` |
| `0x4AF75C` | `CLoginFlashDlg_HandleAccountBindResult` |
| `0x4AF924` | `CLoginFlashDlg_StorePictureKeyChallenge` |
| `0x4AFD83` | `CLoginFlashDlg_GetServerChargeType` |
| `0x4AFBD7` | `CLoginFlashDlg_ReadBoundAccountRecordValue` |
| `0x4B04AF` | `CLoginFlashDlg_HasSuccessfulAccountBindResult` |
| `0x76A0CA` | `AccountBinding_VerifyLocalAccountMetadata` |
| `0x59E546` | `CGameInput_CopyPictureKeyResponse` |
| `0x715061` | `CMsgPictureKey1075__Ctor` |
| `0x7150A0` | `CMsgPictureKey1075__DeletingDtor` |
| `0x7150BC` | `CMsgPictureKey1075__Dtor` |
| `0x7150C7` | `CMsgPictureKey1075__ValidateAndCopy` |
| `0x7150EA` | `CMsgPictureKey1075__Create` |
| `0x715125` | `CMsgPictureKey1075__ProcessAndPostLoginUiCommands` |
| `0x7498F6` | `CMsg1102__CreateWithMobileProtectValue` |

## Native Startup Replacement Contract (Strict Minimum)

This section is the runtime contract used by the non-Flash startup presenter replacement.
Only verified fields/commands from `CLoginFlashDlg_HandleFlashCommandString` are included.

### Required inbound variables (via `VCTOFLASH` payloads)

| Variable | Required | Native source/effect |
|---|---|---|
| `PATH` | yes | startup asset root (`this+0x1A4`) |
| `SELECTBGMUSIC` | yes | startup music enable (`ini/GameSetup.Ini` `[FlashMusic] Enable`) |
| `CURWORLD` | yes | selected group index seed (`this+0x190`) |
| `CURSERVER` | yes | selected server index seed (`this+0x194`) |
| `LOGINUSER` | yes | login account seed (`this+0x198` or ini fallback) |
| `ACCOUNT0`–`ACCOUNT9` | optional but expected | account list values from `[AccountList]` |
| `REGION` / `SERVER` | yes (startup visual parity) | built server/group list payload strings |

### Required outbound command callbacks

| Command | Verified native effect |
|---|---|
| `CMD_SELECTGROUP` | writes `this+0x190 = atoi(value)` and updates hero selection pair |
| `CMD_SELECTSERVER` | writes `this+0x194 = atoi(value)` and updates hero selection pair |
| `CMD_NAME` | writes account string into `this+0x198` |
| `CMD_PASSWORD` | transforms each char with `CGameInput_EncodePasswordCharForLoginBuffer`, writes result to `this+0x414` |
| `CMD_ENTERGAME` | posts `Conquer_PostMainWindowMessage464(0x480, 0)` |
| `CMD_SELECTBGMUSIC` | writes `[FlashMusic] Enable=<value>` to `ini/GameSetup.Ini` |
| `CMD_CLOSE` | posts `0x483`, then `0xC6B`, then `0x3F2` |

### Fixed startup tick cadence

`CLoginFlashDlg_StartFlashLoopTimer` sets `SetTimer(id=1, interval=0x14 ms, callback=null)`.
Managed replacement must keep the same `20 ms` cadence for startup presenter tick/render.

### Managed pre-loop producer hook contract (this slice)

`CLoginStartupPresentationNonFlashBridgeRuntime.InvokePreLoopInitializationHook()` now mirrors
native producer ordering by seeding `REGION`/`SERVER` before first steady frame ticks:

- producer: `CLoginStartupServerDatPayloadProducerRuntime(<clientRoot>)`
- runtime source path: `<clientRoot>/Server.dat` (managed default root resolves to `10_work/assets/5517`)
- decode contract:
  - RSA public block decode over `256-byte` blocks with key-profile auto-detection:
    1) tooling-generated public profile first, 2) native constructor-derived profile fallback;
    native schedule + `e=0x10001` evidence remains documented in `Architecture/05`
  - PKCS#1 type-1 payload extraction
  - gzip inflate to XML
  - `table_data[name=outenserver]` row parse
- payload build with native id walk (`group ids 1..N`, server ids `0x65 + (group-1)*0x64 + offset`)
- emitted payload grammar: native `REGION`/`SERVER` delimiter contracts above
  - `REGION` header formatter is `%d#` at `0x4AD25B` (declared group count).
  - `SERVER` group header formatter is `%d#%d#` at `0x4AD54B`:
    - first `%d` is producer loop index `1..N` (`[ebp-0x40]`, increment at `0x4AD943`);
    - second `%d` is declared server count for that producer group (`[ebp-0x4C]`).
  - native `SERVER` payload group markers are producer-order indices, not XML row `id`.
- startup status parity: init-path status field fixed to `3` (matches native `0x4ABF91` -> `arg3=0` path)
- no synthetic fallback payloads on decode/parse failure or missing asset.
- seed parity: group/server seed defaults are `-1` on missing key (`GetPrivateProfileIntA` default at `0x4AB19E` / `0x4AB277`).
  Native startup paths treat `-1` as the unset sentinel (for example, `0x4ABEEB` compares against `0xFFFFFFFF`);
  values `>= 0` are valid persisted selections.
- managed non-Flash selection mapping (pre-world background stage):
  - `CURWORLD < 0`: unresolved selection;
  - `CURWORLD == 0`: first `REGION` slot (index `0`) for seed compatibility with shipped INIs;
  - `CURWORLD > 0`: matched against parsed `REGION` group ids.
  - server-layer selection uses the same raw seed semantics:
    - `CURWORLD == 0` resolves first parsed `SERVER` group slot;
    - `CURWORLD > 0` matches parsed `SERVER` group marker;
    - this is aligned to native producer `%d#%d#` group-marker ordering (`0x4AD54B`).

### Managed non-blocking startup movie contract (this slice)

- `SetMoviePath` parity handoff is still immediate (`0x4AB6B9` native boundary); managed path now
  queues startup movie manifest decode and timeline decode asynchronously from that handoff.
- frame callback path (`0x4B04CE -> 0x4AD9A9`) remains non-blocking:
  - startup movie manifest is polled from cache each tick (`ResolveNonBlocking`);
  - SWF timeline posters are polled from cache each tick (`ResolveAtElapsedNonBlocking`), with
    two-stage decode:
    1. first-frame prime timeline for immediate visible startup surface;
    2. background upgrade to full loop timeline on the same cache key.
- pre-world visual fallback rule: when no SWF layer resolves for a tick (primary movie, referenced
  submovies, selected group/server overlays), renderer draws the `DlgLogo/BgFormat` bitmap for
  that tick; no black-frame idle surface is allowed while decode is pending.
  **Replacement-only behavior** — "verified" here refers to the path-resolution contract at `0x4B08B9`
  only, not to any native pre-world draw.

### Timer callback body + per-frame callback contract (verified)

Startup timer callback body:

- `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` (`0x4B04CE`)
  calls `CLoginFlashDlg_TickFlashHostStateAndInputBridge` (`0x4AD9A9`) then `CWnd::Default`.

Per-frame callback chain while world gate is off:

- `CMyShellDlg_SetFrameTickContext` (`0x5789A2`)
  -> callback vtable `+0x10`
  -> `CMyShellDlg_RunPreWorldFlashHostFrameCallbacksIfNonNull` (`0x5780EC`)
  -> `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`).

`CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` dispatches `PROGRESS` and `LOADING_TRACE`
through login/role-create Flash hosts using:

- `CLoginFlashDlg_SetProgressVariable` (`0x4B04B6`)
- `CLoginFlashDlg_SetFlashVariableAndDispatch` (`0x4AC6C4`)
- `CRoleCreateFlashDlg_SetProgressVariable` (`0x51C289`)
- `CRoleCreateFlashDlg_SetFlashVariableAndDispatch` (`0x51C1C3`).

### Pre-world callback branch contract (exact)

`CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`) uses two shell fields as a one-shot
selector for the loading trace message id:

| Shell offset | Width | Branch role |
|---:|---:|---|
| `+0x179AAC` | dword | must equal `1` to enter special branch |
| `+0x179AB8` | byte | must be non-zero to enter special branch |

Per visible host branch (login host `this+0x820`, else role-create host `this+0xE40`):

1. If `(+0x179AAC == 1 && +0x179AB8 != 0)`:
   - dispatch `PROGRESS` with payload pointer `0x93883C` (`"80"`),
   - clear `+0x179AAC = 0`, `+0x179AB8 = 0`,
   - dispatch `LOADING_TRACE` with string id `0x2BE8`.
2. Otherwise:
   - dispatch `LOADING_TRACE` with string id `0x2BE7`.

String id resolution is still via `GameDataSetQuery()->vtable+0x3C`.
The callback does not draw UI directly; it is variable transport only.

### Managed parity mapping (implemented slice)

- `Role3DClientScenePreWorldStartupStageRuntime` executes the pre-world callback transport every pre-world tick
  before startup presenter tick/dequeue.
- `CMyShellDlgPreWorldFlashHostFrameCallbacksRuntime` mirrors `0x5DCEA3` login-host branch:
  - `PROGRESS="80"` only on the special branch
  - `LOADING_TRACE` each callback using id `0x2BE7` or `0x2BE8`
  - one-shot clear of `+0x179AAC/+0x179AB8` only when special branch is consumed.
- `CMyShellDlgPreWorldLoadingTraceBranchStateRuntime` is the managed holder for those two shell fields.
- `CStartupLoadingTraceStringByIdFromStrResIniRuntime` resolves trace text by id from `ini/StrRes.ini`
  (clean 5517 values: `11239=Creating maps...`, `11240=Starting... Please wait...`).
- `CLoginStartupPresentationNonFlashBridgeRuntime` now consumes both `PROGRESS` and `LOADING_TRACE`
  from `VCTOFLASH` payloads into typed startup state (`ProgressPayload`, `LoadingTracePayload`).

`DlgLogo` note (verified timing):

- `CStartupLogoDialog` is created/shown/hidden/destroyed in `CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate`
  (`0x5AE8D8`) during init.
- concrete visibility teardown sites: `ShowWindow(SW_SHOW)` at `0x5AEBE6`, `ShowWindow(SW_HIDE)` at `0x5AF4E7`,
  `DestroyWindow` at `0x5AF4F2`.
- The pre-world frame callback (`0x5DCEA3`) is a variable-dispatch bridge; it does not draw or keep the logo dialog alive.
- For managed replacement parity, do not keep a persistent frame-loop logo renderer in the pre-world stage.
- No minimum visible duration exists natively: the `0x5AE8D8`..`0x5AF7B5` range contains no
  `Sleep`/wait/timer/tick-count call and no `0x1F4` constant, and the logo dialog's message map
  (`0x855220`) has only `WM_DESTROY` and `WM_CTLCOLOR`. Visible time == the cost of the synchronous
  init block.

## `CMD_PASSWORD` Character Transform (Verified)

`CMD_PASSWORD` does not copy plaintext directly into `this+0x414`.
Each source byte goes through `CGameInput_EncodePasswordCharForLoginBuffer` (`0x59EECA`):

0. `CGameInput_ResetPasswordKeypadSeedFromAccount` (`0x59F02D`) runs first on the current
   account string:
   - zeroes the 16-byte runtime seed buffer at `0x957F1C`;
   - sums the current account bytes;
   - calls `srand(sum)`;
   - fills `0x957F1C[0..15] = rand() % 0x100`.
1. `CGameInput_TryMapAsciiToVirtualKeyAndShiftFlag` (`0x59EF03`):
   - searches keyboard map table at `0x936768` (48 entries, 8-byte stride: virtual-key dword + uppercase/lowercase char bytes)
   - outputs `virtualKey` + `uppercaseFlag`
2. `CGameInput_MapVirtualKeyToLoginCipherByte` (`0x59EF7B`):
   - builds a 255-entry sortable map using the runtime-seeded `0x957F1C[0..15]` bytes
   - applies optional `virtualKey -= 0x80` path when `uppercaseFlag != 0` and `virtualKey < 0x80`
   - returns 1-based mapped byte index (or 0 on miss)

Raw table evidence used for managed parity extraction:

- keyboard map table bytes: `Conquer.exe` file offset `0x536768`, length `0x180` (VA `0x936768`)
- runtime keypad-seed buffer: VA `0x957F1C`, written by `CGameInput_ResetPasswordKeypadSeedFromAccount`
  (`0x59F05A..0x59F0A6`) before each password encode pass

## Startup Flow Summary (User Experience)

1. `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` loads `start.dat` SWF
2. SWF renders intro animation and plays background music (if enabled)
3. C++ pushes server list (`REGION`/`SERVER`), saved account list (`ACCOUNT0`–`9`), saved selections
4. User selects server group → `CMD_SELECTGROUP` → C++ stores group index
5. User selects server → `CMD_SELECTSERVER` → C++ stores server index
6. User enters account name → `CMD_NAME` → C++ stores to `this+0x198`
7. User enters password → `CMD_PASSWORD` → C++ encrypts and stores to `this+0x414`
8. User clicks login → `CMD_ENTERGAME` → C++ posts `0x480` (login request), records account
9. After successful login: `CMD_CLOSE` → C++ kills timer, posts `0x483` (world-frame enable), `0xC6B`, `0x3F2`
10. World gate byte (`this+0x179AB9`) set to 1 → world rendering begins

## Cross-Platform Replacement Strategy

The native startup presentation must:

1. **Emit the same command set** — `CMD_SELECTGROUP`, `CMD_SELECTSERVER`, `CMD_NAME`, `CMD_PASSWORD`, `CMD_ENTERGAME`, `CMD_CLOSE` at minimum
2. **Consume the same variable set** — server/group lists, saved accounts, music preference
3. **Handle the same persistence** — `ini/GameSetup.Ini` sections for saved state
4. **Not depend on Flash** — use native OpenGL rendering or immediate-mode UI (e.g., ImGui)
5. **Music playback** — use OpenAL (Silk.NET.OpenAL) since the SWF's embedded audio is unavailable
