# Startup Data Files and Native Replacement Plan

## Scope

Documents the data files consumed during the startup/login sequence and the strategy
for replacing the Flash-hosted UI with a native sprite-based implementation.

## server.dat

**2026-09-03 independent public-key audit:** all 256 candidate seed bytes
**MATCH** the native constructor. The recovered 2048-bit modulus has SHA-256
`76acb04b08190b129985f8dee2b466efcd686eb1662cb598bd1a8154cb9196f1`,
and e = 65537. See [exact seed, modulus and per-instruction evidence](../Crypto/02_server_dat_rsa_public_key_5517.md).
Original-x86 seed/schedule and BIGNUM arithmetic checks passed, and the recovered
key validates all 11 clean Server.dat blocks. No application code changed.

### Loader: `CMyShellDlg_ValidateServerDatAndNotifyHero` (`0x5AFAFC`)

Runs on a background thread (`AfxBeginThread`):

1. Opens `server.dat` via `CFile::Open(path, 0x8000)`
2. Reads up to 0x400 bytes
3. Validates every byte: `IsDBCSLeadByte()` for DBCS lead bytes, else `isprint()` or `isspace()`
4. If all valid: sets `data_958648 = 1`
5. If invalid or missing: flag stays `0`

### Decoded Content Baseline (Verified)

Practical decode for clean 5517 assets is verified:

- `Server.dat` is 11 blocks × 256 bytes (RSA block payload layout).
- Post-RSA block decode uses PKCS#1 type-1 block payload extraction.
- Concatenated decoded payload is a gzip stream.
- Gunzip payload expands to XML with table `outenserver`.
- Rows provide startup server metadata fields used by native producer logic:
  `id`, `Child`, `FlashName`, `FlashIcon`, `FlashHint`, `ServerName`, `ServerIP`, `ServerPort`.
- Root row (`id=0`) declares `Child=14` startup groups.

### Binary Verification Detail: RSA + PKCS#1 + gzip Path

#### Conquer.exe (`Conquer.exe.bndb`)

`CMyShellDlg_ValidateServerDatAndNotifyHero` (`0x5AFAFC`) is only the startup guard
(printable-text sanity check over first `0x400` bytes). Real decode/parse work is in
`CConfigDataTableQueryProvider`:

1. `CConfigDataTableQueryProvider_ctor` (`0x765232`)
   - Loads a `0x100`-byte modulus seed table into stack locals
     (`0x76526D..0x76549C`; final immediate load is at `0x765495`,
     final seed-table store at `0x76549C`).
   - Builds a 64-entry dword schedule with adjacent XOR:
     `schedule[(0x11 + i) & 0x3F] = seed[i] ^ seed[i+1]` for `i=0..62`
     (`0x7654AD..0x7654C6`).
   - Writes `0x2220F2A7` as the last schedule assignment, to index `0x10`
     because `(0x11+63)&0x3F == 0x10` (`mov edx, 0x2220F2A7` at
     `0x765495`, schedule store at `0x7654CB`). It is not schedule[63].
   - Constructs RSA key object at `this+0x4`:
     - `RsaKey_New` (`0x77BB80`) -> key ptr
     - `BigNum_New` (`0x77A7F0`) to `key+0x10` (modulus `n`)
     - `BigNum_New` (`0x77A7F0`) to `key+0x14` (public exponent `e`)
   - Reconstructs `n` by 64 rounds of `n = (n << 32) + schedule[i]`
     (`0x765504..0x765532`). Schedule[0] is the most significant limb;
     export each DWORD big-endian to obtain the unsigned 256-byte modulus.
   - Sets `e = 0x10001` at `0x76553D..0x765547`.
   - No private components (`d/p/q/dmp1/dmq1/iqmp`) are assigned here.

2. `CConfigDataTableQueryProvider_LoadEncryptedDatToMemoryBuffer` (`0x764E8B`)
   - Uses `Rsa_GetModulusByteLength` (`0x77BE20`) at `0x764F8D`.
   - Reads encrypted blocks via `Bio_Read` (`0x77B240`) at `0x764FBA`.
   - Enters RSA decode loop (`CConfigDataTableQueryProvider_DecryptRsaBlocksAndAppendLoop`,
     `0x765111`).

3. RSA decode loop evidence
   - `CConfigDataTableQueryProvider_DecryptRsaBlockDispatch` (`0x765108`) pushes
     padding type `1` at `0x765109` and dispatches to
     `Rsa_PublicDecryptDispatch` (`0x77BE70`) at `0x76511D`.
   - `Rsa_PublicDecryptDispatch` calls RSA method slot `+0x8`
     (`call [ecx+0x8]` at `0x77BE8C`), matching public-decrypt dispatch.
   - `CConfigDataTableQueryProvider_HandleRsaDecryptResult` (`0x76515A`):
     - if decrypt result `<= 0`: fail branch (`0x765161..0x765181`);
     - if decrypt result `> 0`: append plaintext chunk with `memcpy`
       (`0x7651A0`), accumulate output size (`0x7651A8..0x7651B3`),
       read next RSA block with `Bio_Read` (`0x7651BE`), loop.

4. gzip stage
   - `CConfigDataTableQueryProvider_IsGzipBuffer` (`0x764C18`) checks
     `buf[0]==0x1F && buf[1]==0x8B` at `0x764C61`.
   - `CConfigDataTableQueryProvider_TryInflateGzipBuffer` (`0x764C66`) opens
     temp gzip file, inflates via `GzipFileReadInflatedBytes`, and verifies
     inflated byte count.

5. XML table parse stage
   - `CConfigDataTableQueryProvider_LoadDatIntoTreeIfMissing` (`0x76557B`)
     walks `mysqldump -> database -> table_structure -> table_data -> row`.
   - String evidence present in binary: `mysqldump`, `database`,
     `table_structure`, `table_data`.
   - `outenserver` is not a literal binary string in `Conquer.exe`; it is
     observed in inflated XML payload rows (`table_data[name=outenserver]`).

#### GameData.dll (`GameData.dll.bndb`)

Checked after `Conquer.exe` path audit:

- no `server.dat`, `outenserver`, RSA/PKCS/gzip function names, or crypto file-path strings;
- no `0x2220F2A7` constant occurrence in raw DLL bytes;
- imports are CRT + basic Win32 only (no external crypto/inflate provider).

Conclusion: server.dat key/signature logic is in `Conquer.exe`, not `GameData.dll`.

### Re-signing Feasibility Verdict (Current Evidence)

- Server.dat decode path uses only public-key decrypt/verify dispatch
  (`Rsa_PublicDecryptDispatch`, `0x77BE70`).
- Private dispatch wrapper exists in OpenSSL code
  (`Rsa_PrivateEncryptDispatch`, `0x77BE40`), but only as generic crypto-library
  capability (xref from `Rsa_SignDigest`, `0x793F90`), not in server.dat loader path.
- `CConfigDataTableQueryProvider_ctor` provisions only `n` and `e`, with no private
  key material assignment.

Therefore the shipped client path can verify/decrypt server.dat blocks, but does not
carry the private key material needed to produce new valid signed/encrypted blocks.

### Startup Producer Call Chain and Dispatch Contract (Verified)

Server-list producer chain in startup login host:

1. `CLoginFlashDlg_PrepareServerRootAndSelectionFromIni` (`0x4AAA49`) seeds:
   - `this+0x3FC` from `ini/oem.ini [Oem] id`;
   - `this+0x400` as root path `.\\Server` or `.\\Server%d`;
   - `this+0x190` / `this+0x194` selected group/server from
     `ini/GameSetup.Ini` with fallback `ini\\DefaultGameSetup.ini`.
2. `CLoginFlashDlg_StartFlashLoopTimer` (`0x4AC5FA`) call order:
   - `CLoginFlashCallbackState_InvokeProviderMethod8IfPresent` at `0x4AC604`;
   - `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` at `0x4AC60B`;
   - `SetTimer(id=1, interval=0x14)` at `0x4AC620`.
3. `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` calls
   `CLoginFlashDlg_BuildAndPushServerListToFlash` at `0x4ABF91` (arg `0`).
4. `CLoginFlashDlg_BuildAndPushServerListToFlash` (`0x4AD12F`):
   - reads root source from `this+0x400` (`0x4AD152`);
   - dispatches `REGION` at `0x4AD442`;
   - dispatches `SERVER` at `0x4AD93E`.
5. Refresh path:
   `CLoginFlashDlg_TickFlashHostStateAndInputBridge` calls
   `CLoginFlashDlg_BuildAndPushServerListToFlash` at `0x4AD9D7` when
   `this+0x61D != 0 && this+0x61C == 0`.

`SERVER` status field contract:

- init-path call with arg `0` uses fixed status code `3` (`0x4AD837`);
- refresh-path call with non-zero arg resolves status via
  `ServerListEntry_ResolveFlashStatusCode` (`0x5EA5A2`).

### play.exe cross-check (verified not producer)

`play.exe` does not provide startup server-list payload data to Conquer login host:

- No `server.dat` string usage in `play.exe` (`list_strings_filter` returns none).
- No `GroupRecord` / `ServerRecord` string usage in `play.exe`.
- `PlayLauncherDialog_OnStartNormalModeLaunchAutoPatch` (`0x40596A`) and
  `PlayLauncherDialog_OnStartLowModeLaunchAutoPatch` (`0x405ABC`) only:
  - read/increment `ini/GameSetup.ini` `[GameMode]` counters (`NormalTimes` / `LowTimes`);
  - write `[GameMode] GameModeRecord`;
  - launch `AutoPatch.exe` via `ShellExecuteA`.
- `PlayLauncher_EnsureGameModeUserDataVersionInitialized` (`0x4051D6`) only writes
  `[GameMode] LowTimes`, `HighTimes`, `UserDataVer`.

Conclusion: startup `REGION`/`SERVER` list payload absence in Conquer runtime is not caused by
missing `play.exe` handoff.

### Native Replacement

Cross-platform startup producer replacement uses a runtime decode path from
`<clientRoot>/Server.dat` (managed default client root: `10_work/assets/5517`) and keeps
native payload grammar parity (`REGION` / `SERVER`) after table decode.

### Own-UI endpoint availability/watchdog contract (`main-own-ui`)

For the active non-Flash startup UI branch, endpoint availability/error handling is enforced in the
own-UI submit pipeline (without Flash callbacks):

1. startup submit validates selected account/login endpoint shape (`host:port`) before entering steady
   connecting state;
2. submit command order remains native-compatible (`SetLoginUser` -> `SetLoginPassword` -> `0x480`);
3. own-UI does not open a pre-submit TCP probe socket (submit path posts `0x480` directly);
4. invalid endpoint shape failures surface explicit user-facing status and clear connecting state;
5. connecting state has a bounded timeout watchdog that fails the attempt with explicit timeout
   status if success-stage world transition never occurs.

This remains the own-UI replacement for native Flash `CMD_TIMEOUT` / `CMD_ERROR_RET` signaling that
routes through `Conquer_PostMainWindowMessage464(0x55, ...)`.

### Own-UI startup presentation contract (`main-own-ui`)

The active own-UI startup branch does not reuse native DDS/BMP control chrome for
buttons, fields, or panel framing.

Current own-UI presentation contract:

- startup background remains native bitmap-driven (`Data/Main/Logo*.bmp`);
- startup controls are rendered procedurally in managed code;
- control visuals are branch-local and intentionally decoupled from Flash/SWF or
  native dialog texture slices;
- skinning experiments using static DDS button/field art were removed because they
  produced mislabeled and visually inconsistent controls;
- no SWF asset is used in the active own-UI runtime path.

### Own-UI account auth vs registration split (`main-own-ui`)

For current first-party startup UI flow, account operations are intentionally split:

- login submit (`LOGIN` button):
  - credential encode path unchanged;
  - account packet `1060` over startup account endpoint (`127.0.0.1:9958` default);
  - expected behavior: authenticate existing account only.
- registration submit (`REGISTER` button):
  - same credential encode path and endpoint;
  - project-owned request `0xF001` and response `0xF002` over the same packet-1059/login-cipher
    transport and native credential-field transform;
  - expected behavior: create new account only, fail if username already exists.

Server-side login auto-create is removed in this branch; registration is no longer implicit in login.
The extension is deliberately outside the retail opcode set. Native packet `1098` remains
bound-account authentication with mobile protection, and native retail registration opens a website
through the SWF `CMD_GETURL` action instead of sending an account-server registration packet.

#### Native key profile (binary-verified reference)

Native 5517 key derivation remains documented in this file and is preserved as the reference contract:

- modulus schedule reconstructed in `CConfigDataTableQueryProvider_ctor` (`0x765232`) from
  0x100-byte seed table + adjacent XOR schedule + final word `0x2220F2A7`;
- exponent set to `0x10001`;
- server.dat path dispatches public decrypt/verify flow (`Rsa_PublicDecryptDispatch`, `0x77BE70`);
- no private key material assignment found in shipped client path.

#### Managed key profile behavior in `10_work` (intentional divergence for tooling encode)

Managed decoder now supports both verified public-key decode profiles with auto-detection in
`10_work/src/Conquer.Assets/Startup/ServerDatOutenserverTableDecoder.cs`:

- first attempt: tooling-generated public profile (`n_tooling`, `e=0x10001`);
- fallback attempt: native 5517 public profile reconstructed from the verified seed/schedule algorithm
  (`seed[0x40]`, `schedule[(0x11+i)&0x3F]=seed[i]^seed[i+1]`, final word `0x2220F2A7`,
  modulus accumulation `n=(n<<32)+schedule[i]`);
- successful decode reports matched profile (`ToolingGenerated` or `Native5517Public`) so tools can
  identify which key profile decrypted the payload.

Tooling divergence remains encode-only:

- tooling-generated RSA-2048 keypair (generated on 2026-03-10) is used for managed fixture/tool
  encryption output;
- tooling helper uses tooling private exponent to encode encrypted `Server.dat` fixtures for tests/tools;
- native private key is still unavailable, so native-compatible signing/encryption output is not supported.

Shared decode semantics remain parity-anchored across both profiles:

- block payload semantics remain native-parity: PKCS#1 type-1 extraction -> gzip inflate -> XML
  `table_data[name=outenserver]`;
- row walk and output payload grammar remain native-parity:
  - groups: `id=1..Child(id=0)`;
  - servers per group: start id `0x65 + (groupIndex-1)*0x64`, count=`Child(groupRow)`.

Selection seed/status behavior remains parity-anchored:

- `CURWORLD`/`CURSERVER` are raw `this+0x190`/`this+0x194` values (`0x4AB7FC..0x4AB84E`);
- missing key defaults are `-1` on native Group/Server record reads (`0x4AB19E`, `0x4AB277`);
- native unset sentinel is `-1` (`0xFFFFFFFF` compare site in init path around `0x4ABEEB`);
- native producer payload headers are:
  - `REGION`: `%d#` at `0x4AD25B`;
  - `SERVER`: `%d#%d#` at `0x4AD54B` where first `%d` is producer loop index `1..N`.
- managed non-Flash pre-world stage treats `CURWORLD=0` as first parsed group-slot compatibility
  for both `REGION` and `SERVER`, and only negative group seeds as unresolved;
- startup status parity remains fixed to `3` on init path (`0x4ABF91` arg=`0` path parity).

No synthetic fallback payloads are emitted on decode/parse failure or missing file.

### Startup Movie (`start.dat`) Replacement Runtime Contract (Verified)

- Native handoff remains `CFlashControl_SetMoviePath` at `0x4AB6B9`; there is no native C++ SWF tag
  decode on the timer callback body.
- Native movie-variant gate:
  - `ConquerApp_ParseLaunchArgumentsAndSetStartupMovieVariantFlag` (`0x5AAF10`) sets
    `g_startupMovieFacebookVariantEnabled` (`0x96AB34`) when launch token count reaches 5;
  - `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` branches to
    `start.dat` vs `start-facebook.dat` by this flag;
  - `CMyShellDlg_DispatchCommandCode` case `0x55` clears the flag.
- Managed non-Flash path mirrors this by keeping frame callbacks non-blocking:
  - startup movie manifest parse (`start.dat`/`start-facebook.dat`) is queued asynchronously and
    resolved through cache polling on frame ticks;
  - SWF timeline poster extraction is queued asynchronously and resolved through cache polling on
    frame ticks;
  - timeline decode is two-stage on one cache key:
    - startup movie payloads (`start.dat` / `start-facebook.dat`) prime to first 4 frames;
    - non-startup referenced payloads prime to first 1 frame;
    - both paths upgrade in background to full loop timeline (`<=600` frames).
  - startup host timer progression follows 20ms boundary slices (`SetTimer id=1, 0x14`) even when
    outer scene updates arrive on the 25ms `ConquerApp_OnIdle` gate (`0x5AB543`), with bounded
    same-frame catch-up to preserve timer-phase ordering without runaway loop stalls.
- Managed SWF compositor honors `PlaceObject2`/`PlaceObject3` `HasClipDepth` mask scopes
  (mask depth range `(depth, clipDepth]`) so startup timeline panels are clipped correctly instead
  of overdrawn as raw layers.
- Managed bitmap-shape fill matrix normalization contract:
  - SWF bitmap fill matrices are interpreted in shape-space twips terms;
  - managed shape rasterizer normalizes bitmap fill matrix scale/rotation terms into pixel-space
    before inverse sampling (translation remains twips-to-pixel converted),
    preventing 20x under-sampled flat-color panel artifacts in startup SWF composition.
- Managed nested-sprite composition contract:
  when composing a timeline with no explicit stage dimensions (sprite/button-local timelines),
  canvas extents are computed from transformed display-list bounds instead of max raw symbol sizes,
  and blend/mask sampling uses that canvas origin offset; this preserves translated child layers.
- Pre-world draw fallback contract: while startup SWF layers are still unresolved, renderer draws
  `DlgLogo/BgFormat` bitmap fallback for that tick (no intentional black-frame wait state).
- Startup submovie anchor contract (verified from clean `start.dat` payload):
  - action-script `loadMovie` targets: `loginFlashMC`, `logoMC`, `sr`, `ss`;
  - root timeline anchor placements: `loginFlashMC(0,0)`, `logoMC(0,0)`, `sr(150,381)`,
    `ss(685,373)`;
  - root anchor matrices include non-unit scale terms (`sr`: `M00≈0.9803`, `M11≈0.9801`).
- Managed non-Flash placement contract:
  - startup referenced SWFs resolve by mapped anchor name using startup movie root timeline
    `PlaceObject2`/`PlaceObject3` named anchors;
  - overlay draw width/height applies anchor matrix scale terms in addition to startup stage fit;
  - selected `REGION`/`SERVER` SWF overlays are drawn on `sr`/`ss` anchors (not centered).
- Managed startup host surface contract (verified + replacement):
  - native `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport` (`0x4AEC64`) resizes both
    login dialog and embedded Flash control (`this+0xF8`) to shell viewport;
  - managed non-Flash renderer therefore treats startup movie as a viewport-hosted stage surface:
    primary timeline is drawn with aspect-preserving stage fit across viewport, and all stage anchor
    overlays (`loginFlashMC`/`logoMC`/`sr`/`ss`) are transformed by the same stage scale/offset.
  - presentation pass preserves per-layer alpha in the startup surface compositing step; transparent
    pixels in upper startup layers do not punch opaque black into lower layers.
- Managed non-Flash startup overlay activation contract:
  - referenced startup SWFs are frame-gated by earliest extracted `loadMovie` frame index from
    startup AVM1 action bytecode parse (`DoAction`/`DoInitAction`);
  - action parse decodes `ActionConstantPool`/`ActionPush` values and resolves
    `ActionStoreRegister`/`ActionGetVariable`/`ActionSetVariable`/`ActionDefineLocal`/
    `ActionDefineLocal2`/`ActionGetMember`/`ActionSetMember` flows and
    `ActionCallFunction`/`ActionCallMethod` `loadMovie` argument tuples (`path`, `targetClip`);
  - decode keeps symbolic identifier expressions for unresolved locals/member chains so
    `ActionCallMethod loadMovie` targets encoded via object-member indirection (for example
    `self.son`) can still resolve deterministic slot clips (`sr*` / `ss*`) without synthetic
    static path heuristics;
  - decode keeps symbolic register identities (`reg[N]`) when concrete register value is unknown so
    later local aliases preserve object-member path continuity in the same action branch;
  - member-name fallback (`tagBmp`, `son`, etc.) is used when object alias is unresolved, allowing
    prior `ActionSetMember` writes from the same branch to feed later `loadMovie` argument decode;
  - deferred slot alias contract: if a `loadMovie` call target resolves to `.son` and immediate
    follow-up pushes include a slot-like clip literal (`ss1`/`sr1`), that slot literal is bound to
    the same callsite target clip;
  - startup decode traverses nested `DefineSprite` tag streams so sprite-timeline script blocks are
    part of activation extraction;
  - action parse also traverses nested `ActionDefineFunction`/`ActionDefineFunction2` bodies so
    startup helper-function `loadMovie` callsites contribute activation metadata;
  - activation frame space is 1-based SWF timeline indexing;
  - when primary startup poster extraction is currently `1/1` but startup manifest has
    `parsedFrames > 1`, activation progression uses manifest-frame timing on the startup movie clock
    so slot/reference activation does not freeze at frame 1 during asynchronous timeline upgrades;
  - per-target-clip replacement semantics are preserved: for each startup clip target
    (`loginFlashMC`, `logoMC`, `sr*`, `ss*`), only the latest decoded `loadMovie` path active at
    the current frame is rendered for that clip (historical loads into same clip are replaced, not
    cumulatively layered);
  - composition ownership is split by clip class to mirror Flash host display-list behavior:
    - startup referenced overlay pass renders startup-owned clips (`loginFlashMC`, `logoMC`);
    - selected region/server pass renders selection clips (`sr*`, `ss*`);
    - `sr/ss` are not rendered twice in one frame (no duplicated generic+selected slot composition).
  - gating is evaluated on the same runtime tick boundary as startup host updates
    (`SetTimer id=1 interval=0x14` -> `0x4B04CE` -> `0x4AD9A9`);
  - selected region/server slot overlays (`sr`/`ss`) are additionally gated by decoded slot
    activation:
    - `sr`: earliest decoded `loadMovie` with `targetClip=sr`;
    - `ss`: earliest decoded `loadMovie` with `targetClip=ss`;
    - indexed aliases (`sr1..srN`, `ss1..ssN`) are treated as slot-target matches by prefix;
    - selected group/server SWF overlays are suppressed until slot activation frame is reached;
    - no static path-heuristic fallback (`defaultR/defaultS/unopened*`) is used for slot activation;
    - if no slot target clip activation is decoded for `sr` or `ss`, that slot remains unresolved
      and is rendered without synthetic activation delay.
  - paths without extractable activation metadata remain manifest-order drawable to avoid synthetic
    suppression.
- Managed startup movie selection parity:
  - choose `start-facebook.dat` when launch argument token count is at least 5;
  - otherwise choose `start.dat`.
- Managed pre-loop warm-up extension:
  - after `REGION`/`SERVER` payload production, runtime resolves selected group/server icon paths
    and pre-warms their SWF timelines before steady frame ticks.
- Managed startup asset-root policy (enterprise replacement contract):
  - startup runtime reads from configured client-root assets (project runtime root:
    `10_work/assets/5517`) and does not rely on `00_clean` fallback paths;
  - startup referenced SWF paths and `FlashIcon` payload values are resolved as client-root-relative
    inputs only;
  - rooted paths and normalized out-of-root traversal (`..`) are rejected in real runtime path
    resolution.

## flashLogin.ini

### Format

Standard INI file at `ini/flashLogin.ini`. Defines the Flash login screen layout,
audio, and UI strings.

### Sections

| Section | Purpose | Key Fields |
|---|---|---|
| `[logo]` | Logo position | `xPos=776, yPos=2` |
| `[loginFlash]` | Flash container position | `xPos=0, yPos=0` |
| `[topDragon]` | Dragon animation position | `xPos=267, yPos=26` |
| `[bottomDragon]` | Dragon animation position | `xPos=426, yPos=620` |
| `[rsDragon]` | Dragon animation position | `xPos=183, yPos=73` |
| `[poetry]` | Poetry overlay position | `xPos=900, yPos=230` |
| `[bgMusic]` | Background music | `path=music.mp3, loopTime=0, volume=40` |
| `[sound]` | Sound volume | `volume=100` |
| `[facebookTxt]` | Facebook mode text | `txt=facebook` |
| `[dialogBox]` | Dialog sound effects | `show/hide/rollOver/click` for OK and Cancel |
| `[serverSelection]` | Server picker sounds | `show/rollOver/click` for region, server, page |
| `[accountPanel]` | Account panel sounds | `rollOver/click` for all buttons + keyboard |
| `[tip]` | Tooltip strings | `saveAccount, clearAccount, enterGame, exitGame, register, paid, help, leftPage, rightPage, capsLock` |
| `[URL]` | External links | `URL_charge, URL_help` |

### Audio Assets Referenced

Background music:
- `sound/music.mp3` — 424 KB, MP3

Dialog sounds:
- `sound/error.mp3` — dialog show/hide
- `sound/Button_1.mp3` — click OK / account panel clicks
- `sound/Button_2.mp3` — rollover / cancel / misc clicks

Server selection sounds:
- `sound/Dragon.mp3` — server selection show + dragon movement
- `sound/Glide.mp3` — rollover region/server
- `sound/click_2.mp3` — click server
- `sound/page.mp3` — click page left/right

Account panel sounds:
- `sound/Confirm.mp3` — enter button click
- `sound/key_1.mp3`, `key_2.mp3`, `key_3.mp3` — keyboard press variants

### Native Replacement

Parse `flashLogin.ini` as standard INI. Use positions for UI element placement.
Audio paths resolve relative to game root (all in `sound/` directory).

## Retail Login Screen Assets

### Images (in `data/main/` via WDF or loose)

| Pattern | Count | Format | Purpose |
|---|---|---|---|
| `LoginG[1-10]Img.bmp` | 10 | BMP | Server group background images |
| `servericon[03-81].jpg` | 79 | JPG | Individual server status icons |
| `Logo1.bmp`, `Logo2.bmp` | 2 | BMP | TQ logo images |
| `NewLoginBtn*.bmp/dds` | varies | BMP/DDS | Login button states (normal/hover/pressed) |

### ANI Sprite Resources

| File | Keys | Purpose |
|---|---|---|
| `ani/Control.Ani` | `HorseUp_MainBG`, `Dialog4`, `ExChat_TopBG` etc. | General UI controls |
| `ani/Server.Ani` | (server-selection specific) | Server selection UI sprites |

### Flash SWF Files (reference only)

| File | Purpose |
|---|---|
| `data/main/start.dat` | CWS v6 — main startup Flash (login + server select + intro) |
| `data/main/start-facebook.dat` | CWS v6 — Facebook variant |
| `data/main/flash/loginFlash.swf` | Login Flash container |
| `data/main/flash/logo.swf` | Logo animation |
| `data/main/flash/characterInAndOut.swf` | Character creation transition |

## Startup Logo Dialog Resource Contract (Verified)

`CStartupLogoDialog_OnInitDialogLoadLogoBrush` (`0x4B08B9`) resolves the startup bitmap path from:

- file: `ini/info.ini`
- section: `DlgLogo`
- key: `BgFormat`
- fallback format when key is missing: `Data/Main/Logo%d.bmp`
- runtime variant select: `(timeGetTime() & 1) + 1`

Resolved path is loaded via `LoadImageA(..., IMAGE_BITMAP, ..., LR_LOADFROMFILE)` and wrapped with
`CreatePatternBrush`. The brush is returned from `CStartupLogoDialog_OnCtlColorReturnLogoBrush`
for `CTLCOLOR_DLG`.

Cross-platform parity note:

- Native 5517 executes this lookup on Windows where the filesystem path match is case-insensitive.
- Managed runtime therefore resolves `DlgLogo/BgFormat` path segments case-insensitively before
  file-open, so clean-data `Data/Main/Logo%d.bmp` also resolves on case-sensitive hosts when
  files are stored as `data/main/Logo*.bmp`.

Dialog template id `0x111` (`RT_DIALOG`) layout payload:

| Field | Value |
|---|---:|
| `x` | `0` |
| `y` | `0` |
| `cx` | `250` |
| `cy` | `188` |
| `cdit` | `0` |

This dialog is shown and centered from `CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate`
before startup flow transitions to the Flash-hosted login surface.

Verified ordering/lifetime details:

- `ShowWindow(SW_SHOW)` then `CenterWindow(NULL)` for the startup logo dialog (`0x5AEBE6` -> `0x5AEBF3`).
- teardown is explicit `ShowWindow(SW_HIDE)` then `DestroyWindow` (`0x5AF4E7` -> `0x5AF4F2`).
- there is no fixed delay loop between show and hide in this function; visible duration is bounded by
  the init workload in the same call.

## Post-Logo Startup Host Surface Contract (Verified)

After startup logo teardown, native startup visuals run through the login flash host dialog,
not through a persistent `CStartupLogoDialog` draw path.

Concrete call path and evidence:

- `CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate` (`0x5AE8D8`)
  - `0x5AF1B5`: `CFlashHostDialog_ApplyShowHideStateAndLifecycleCallbacks(this+0x820, 5)` (show/start host lifecycle)
  - `0x5AF4E7`: `ShowWindow(SW_HIDE)` on `CStartupLogoDialog`
  - `0x5AF4F2`: `DestroyWindow` on `CStartupLogoDialog`
  - `0x5AF705`: `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport(this+0x820)`
  - `0x5AF721`: world-frame gate byte `this+0x179AB9 = 0` (pre-world gate remains off)
- `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport` (`0x4AEC64`)
  - `0x4AEC85`: reads main shell rect from `*(data_95807c + 0x60)` via `GetWindowRect`
  - `0x4AEC9F`: `MoveWindow(loginDlg, 0,0,width,height, TRUE)`
  - `0x4AECBC`: `MoveWindow(loginDlg+0xF8 /*flash control*/, 0,0,width,height, TRUE)`
- `CLoginFlashDlg_StartFlashLoopTimer` (`0x4AC5FA`)
  - `SetTimer(hwnd, id=1, interval=0x14, callback=NULL)` (20 ms cadence)
- `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` (`0x4B04CE`)
  - ticks startup host state/input bridge each timer event.

Parity implication:

- Native post-logo startup visual ownership is a full-viewport host surface.
- A centered logo in steady pre-world frame loop is not a native draw-path behavior.
- In cross-platform non-Flash replacement, any fallback visual should map to the host viewport
  contract (full viewport), while keeping native gate/callback sequencing intact.

## Startup Timer/Input Bridge Ordering (Verified)

Timer/callback chain:

1. `CLoginFlashDlg_StartFlashLoopTimer` (`0x4AC5FA`) arms `SetTimer(id=1, interval=0x14 ms)`.
2. `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` (`0x4B04CE`) calls
   `CLoginFlashDlg_TickFlashHostStateAndInputBridge` (`0x4AD9A9`) every timer tick.
3. Frame path (`CMyShellDlg_TickMapRoleAndEffectPipeline`, `0x5AFD4C`) executes:
   - `CMyShellDlg_SetFrameTickContext(CLoginFlashDlg_GetSingletonPtr(), shell)` (`0x5AFEA4`)
   - `GameDataSetQuery()->vtable+0x0C` (`0x5AFEB3`)
4. `CMyShellDlg_SetFrameTickContext` (`0x5789A2`) dispatches login-host callback vtable `+0x10`,
   which resolves to `CMyShellDlg_RunPreWorldFlashHostFrameCallbacksIfNonNull` (`0x5780EC`) and then
   `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`) when non-null.

Variable dispatches in `CLoginFlashDlg_TickFlashHostStateAndInputBridge` (`0x4AD9A9`) are emitted via
`CLoginFlashDlg_SetFlashVariableAndDispatch` (`0x4AC6CE`) with `VCTOFLASH` payload `NAME|VALUE`.

Verified emitted variable names in this tick path:

- `LOGINUSER` (`0x4ADC62`)
- `LOGINPASS` (`0x4ADE97`)
- `LOGINMOBILEPROTECT` (`0x4AE0B0`)
- `STARTTOFLASH` (`0x4ADCE8`, `0x4ADF41`, `0x4AE12A`)
- `ENDTOFLASH` (`0x4ADD21`, `0x4ADF7A`, `0x4AE15F`)
- `FOCUSTOFLASH` (`0x4ADD74`, `0x4ADFCD`, `0x4AE1AE`)
- `SETKEYDOWN` (`0x4ADB33`, `0x4AE1F7`)
- `ERROROK` (`0x4ADB11`, `0x4AE257`)

Pre-world frame callback dispatch (`CMyShellDlg_RunPreWorldFlashHostFrameCallbacks`, `0x5DCEA3`)
emits loading variables through the same bridge:

- `PROGRESS` via `CLoginFlashDlg_SetProgressVariable` branch (`0x5DCEDF` path)
- `LOADING_TRACE` at `0x5DCEFB`/`0x5DCF02`.

This confirms two independent producers while world gate is disabled:

- timer tick producer: login input/focus bridge variables
- frame callback producer: loading/progress trace variables.

Additional consumer-order confirmation (this slice):

- `CMyShellDlg_TickMapRoleAndEffectPipeline` (`0x5AFD4C`) always performs
  `CMyShellDlg_SetFrameTickContext(CLoginFlashDlg_GetSingletonPtr(), shell)` at `0x5AFEA4`
  immediately before `GameDataSetQuery()->vtable+0x0C` at `0x5AFEB3`.
- `CMyShellDlg_SetFrameTickContext` (`0x5789A2`) only writes the frame context and invokes
  callback vtable `+0x10`; the concrete callback remains
  `CMyShellDlg_RunPreWorldFlashHostFrameCallbacksIfNonNull` (`0x5780EC`) ->
  `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`).
- `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`) dispatches
  `PROGRESS`/`LOADING_TRACE` through `SetFlashVariableAndDispatch`; it does not natively draw
  REGION/SERVER startup visuals in C++.

Managed non-Flash implication applied in code this slice:

- pre-world stage resolves `REGION[selectedGroup].FlashIcon` as an opaque startup asset token:
  - `.bmp`: render selected group icon bitmap directly when the path resolves;
  - `.swf`: resolve selected SWF path and decode deterministic poster candidates from
    `DefineBitsLossless2` (`tag 36`, format `5`) for non-Flash draw stage use.
    Managed runtime now composes resolved display-list layers by depth (alpha blended) per frame,
    rather than selecting only one symbol from the frame display list.
- SWF frame stepping in managed replacement is pinned to the verified startup host timer cadence:
  `SetTimer(id=1, interval=20ms)` from `CLoginFlashDlg_StartFlashLoopTimer` with callback
  `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` -> `CLoginFlashDlg_TickFlashHostStateAndInputBridge`.
- deterministic SWF timeline decode scope in managed runtime:
  - display-list updates from `PlaceObject` (`4`), `PlaceObject2` (`26`), `PlaceObject3` (`70`),
    `RemoveObject` (`5`), `RemoveObject2` (`28`), `ShowFrame` (`1`);
  - nested sprite timelines from `DefineSprite` (`39`);
  - button symbol timelines from `DefineButton2` (`34`) using deterministic display-state
    selection (state-up preferred for initial startup composition); button-record filter lists are
    parsed/skipped so filtered startup button records do not hard-fail symbol decode;
  - shape indirection from `DefineShape`/`DefineShape2`/`DefineShape3` bitmap fill styles
    (`0x40..0x43`) to underlying bitmap character ids;
  - `DefineShape*` bitmap fills are rasterized from parsed `SHAPEWITHSTYLE` geometry with
    style-matrix-aware bitmap sampling (inverse matrix into source bitmap space), so startup
    atlas-backed widgets are clipped/scaled to authored shape bounds instead of full-bitmap blits;
  - `SHAPEWITHSTYLE` `StateNewStyles` blocks are now consumed in managed decode (appended fill/line
    style arrays + refreshed bit widths) instead of defaulting to first-style bitmap substitution;
  - when shape bounds minima are non-zero, managed compositor applies those minima as local symbol
    placement offsets on the resolved layer (no synthetic recentering to `(0,0)`);
  - unsupported shape record features may use per-symbol fallback to legacy bitmap substitution,
    but runtime does not inject synthetic global mapping tables;
  - symbol image decode from `DefineBitsJPEG2` (`21`) and `DefineBitsJPEG3` (`35`) including
    JPEG3 zlib alpha stream merge;
  - symbol image decode from `DefineBitsLossless2` (`36`, ARGB32);
  - per-elapsed-frame sampling uses SWF frame rate and looped frame index;
  - resolved display-list symbol posters are composited in depth order with alpha blend to
    produce the per-frame SWF surface rendered by the non-Flash host.
  - runtime host-surface draw pass keeps alpha blending enabled for startup layer quads so
    transparent RGBA pixels from decoded SWF posters remain transparent in final frame output.
  - decode scheduling keeps startup frame callbacks non-blocking: first-load SWF extraction runs
    asynchronously per asset path and pending layers resolve progressively without stalling the
    pre-world draw loop.
  - startup movie decode warm-up begins at movie-path handoff and uses shared path-keyed timeline
    cache with the pre-world visual stage, preventing duplicate decode stalls across startup
    orchestration components.
  - SWF header `RECT` is decoded for stage pixel bounds and used as the root frame canvas when
    present; layer placement uses decoded `PlaceObject*` matrix transforms (scale/rotate/translate)
    in stage-space compositing.
  - `PlaceObject2`/`PlaceObject3` color-transform alpha terms (`CXFORMWITHALPHA`)
    are consumed as `mult` + `add` per-layer alpha modulation during compositing, so timeline
    fades/visibility control tags survive non-Flash replacement draws.
  - `PlaceObject2`/`PlaceObject3` `HasClipDepth` entries are interpreted as clipping masks for
    subsequent layers within the clip-depth range; mask entries are not emitted as visible color
    layers, and nested mask scopes combine on destination alpha.
- deterministic path probes for relative icons:
  1. `<clientRoot>/<FlashIcon>`
  2. `<clientRoot>/data/main/<FlashIcon>`
  3. `<clientRoot>/data/main/flash/<FlashIcon>`
- startup asset resolution (icon + startup referenced SWF layers) uses case-insensitive file
  traversal under client root to mirror native Windows path semantics on case-sensitive hosts.
- no numeric/icon-pattern inference is used (for example no synthetic `LoginG{N}Img.bmp` mapping).
- when no decodable SWF poster candidate exists, runtime falls back to verified `DlgLogo/BgFormat`
  bitmap draw path.
- startup pre-world layering order in managed replacement:
  1. primary startup movie path (`start.dat` / `start-facebook.dat`);
  2. startup referenced SWF overlays (`ReferencedFlashMovieRelativePaths`, manifest order);
  3. selected group `FlashIcon` SWF;
  4. selected server `FlashIcon` SWF;
  5. `DlgLogo/BgFormat` fallback only when startup SWF layers do not resolve.

Deobfuscation names applied in this slice (Conquer.exe):

- `CGameInputString_ProcessFrameInputAndSelection` (`0x59E59F`)
- `CGameInputString_IsKeyCodePressed` (`0x59F1C7`)
- `CGameInputString_GetTextByOutputMode` (`0x59F0EE`)
- `CGameInputString_SetTextFromCString` (`0x59F19C`)
- `CGameInputString_WriteTextToBuffer` (`0x59F1B5`)

## Singleton Initialization Order

`CreateAllSingletons` (`0x404D19`) called from `ConquerApp_InitInstance`:

The function creates ~80 singletons in fixed order. CDummyMovieMgr is at index 14.
All singletons use the same pattern: `operator new(size) → Ctor(ptr) → store to global`.

## Startup Sequence Summary (Corrected Understanding)

The actual retail startup sequence:

1. **CRT entry** → `AfxWinMain` → `ConquerApp_InitInstance`
2. **Singleton creation** — `CreateAllSingletons` (CDummyMovieMgr at index 14, among ~80)
3. **Shell dialog construction** — `CMyShellDlg` (size 0x179B40), world gate OFF
4. **Flash host init** — `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic`:
   - Selects `start.dat` or `start-facebook.dat`
   - Pushes `PATH`, `CONQUER_WIDTH`, `CONQUER_HEIGHT` variables
   - Reads music pref from `GameSetup.Ini`, pushes `SELECTBGMUSIC`
5. **server.dat validation** — background thread validates as text, sets flag
6. **Flash renders** — SWF plays intro animation AND login/server UI:
   - Background music (Flash-internal, driven by SWF reading `music.mp3`)
   - Logo/dragon animations
   - Login form, server/group selector
7. **C++ pushes data** — REGION/SERVER variables for server list, ACCOUNT_LIST, etc.
8. **User interaction** — account/password entry, server selection
9. **CMD_CLOSE** → `PostMessage(WM_COMMAND, 0x483)` → world gate ON

### Own-UI sequencing guard (verified command semantics)

For `main-own-ui`, startup status text (`LOADING_TRACE` ids `0x2BE7`/`0x2BE8`) is a presentation channel only.
It must not be used as an implicit world-entry trigger. World-frame enable remains bound to explicit close/enter
sequencing (`0x483`, `0xC6B`, `0x3F2`) and the native `0x483` handler success path.

Because startup submit runs through the verified `WM_COMMAND 0x464` branch at
`0x5BC81B..0x5BC846` (visibility gate + `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` call),
and that submit function first resolves account/login host+port via
`CLoginFlashDlg_GetServerEndpointByServerRowAndRole` (`0x4AFE37`, role `2` -> `ServerIP/ServerPort`)
before calling `CGameMain_AccountSetupAndSendLoginAuthPacket` and posting `0x482`,
own-UI submit defaults must target login/account endpoint first. The game/world endpoint remains
post-auth stage concern, with `0x483` (`0x5CAA2D`) as the separate world-enable handler.

Verified `WM_COMMAND 0x464` startup branch handlers (`CMyShellDlg_WindowProc_DispatchMainWindowMessages`,
`0x5BB79D`):

- `0x5C6EB0`: `CMyShellDlg_HandleStartupCommand0x480_SetStartupConnectFlag`
- `0x5C6EC5`: `CMyShellDlg_HandleStartupCommand0x482_ClearStartupConnectAndOverlayFlags`
- `0x5C6EE4`: `CMyShellDlg_HandleStartupCommand0x481_ApplyFlashHostShowStateAndDispatchVariable`
- `0x5CAA2D`: `CMyShellDlg_HandleStartupCommand0x483_EnableWorldFrameGateAfterStartupLayoutChecks`

### Key Insight: No DummyMovie at Startup

The DummyMovie system (`CDummyMovieMgr`) is **not invoked during startup**. It is used
exclusively for the in-game mount/ride PK arena cutscene (triggered from `DlgMountAppend`).

The startup animation is Flash-internal. The original encoded video, bitmap-fill
compositions and timeline placements are recoverable; see the source-verified
[login UI asset audit](11_login_ui_assets_and_interactions.md). INI section names
alone do not prove a loaded dragon or poetry animation. The earlier suggestion
to recreate these graphics from scratch is superseded by that extraction.

## Native Replacement Status (Verified-only)

Implemented parity surface in current runtime:

1. Startup command bridge contract (`VCTOFLASH` vars in, verified `CMD_*` subset out).
2. Startup movie deterministic manifest extraction (`start.dat` / `start-facebook.dat`):
   - CWS/FWS header decode (`signature`, `version`, declared file length/frame count);
   - timeline structural tags (`ShowFrame`, `PlaceObject*`);
   - startup audio tag events (`DefineSound`, `StartSound`, `SoundStreamHead*`, `SoundStreamBlock`);
   - script token extraction from `DoAction` / `DoInitAction` payloads for command-hook manifests;
   - embedded `data/main/flash/*.swf` reference list retained as a compatibility projection with
     case-insensitive prefix/extension matching and slash normalization (`\` -> `/`), so mixed-case
     SWF action paths map into deterministic managed startup overlay resolution.
3. Startup per-frame host callback boundary wiring
   (`CMyShellDlg_SetFrameTickContext -> GameDataSetQuery()->vtable+0x0C`).
4. Init-phase startup logo dialog contract:
   - `DlgLogo/BgFormat` from `ini/info.ini`, default `"Data/Main/Logo%d.bmp"`, variant
     `(timeGetTime() & 1) + 1` (`0x4B0A4F`/`0x4B0A68`)
   - dedicated startup surface from `RT_DIALOG 0x111` (RVA `0x57B7C0`), whose `cx=250 cy=188` are
     **dialog template units**, not pixels — `style = WS_POPUP | DS_CENTER | DS_SETFONT`,
     `cdit = 0`, font `12 pt 宋体`. At 96 DPI with SimSun those DLUs convert to ~`500x376` device
     pixels, matching the 500x375 retail BMP; the exact pixel size is a runtime font/DPI property and
     is **not** statically provable. See
     `02_conquer_client_startup_chain.md` for the decoded template bytes.
   - bitmap is loaded at natural size (`LoadImageA(..., 0, 0, LR_LOADFROMFILE)`, `0x4B0A88`) and
     painted 1:1 top-left-anchored through a `CreatePatternBrush` returned from `WM_CTLCOLORDLG`
     (`0x4B0AA2`/`0x4B0B26`). **No stretch, scale, or aspect fit.**
   - logo shown during init (`0x5AEBE6`) and torn down (`0x5AF4E7`/`0x5AF4F2`) before steady
     frame-loop callbacks; it runs entirely inside `WM_INITDIALOG`, i.e. while the main window is
     still hidden (`CWnd::ShowWindow(data_95807C, SW_SHOW)` only happens later at `0x5AB348`).
   - **no minimum display duration exists in native 5517** — verified by exhaustive scan of the
     `0x5AE8D8`..`0x5AF7B5` range for `Sleep`/wait/timer/tick imports and for the constant `0x1F4`,
     and by the logo dialog's 2-entry message map (`WM_DESTROY`, `WM_CTLCOLOR`) at `0x855220`.
5. Non-Flash replacement pre-world visual stage:
   - pre-world callbacks still run via verified `CMyShellDlg_SetFrameTickContext -> ... -> 0x5DCEA3` chain
   - startup presenter consumes verified startup bridge variables from both producers
     (`LOADING_TRACE`/`PROGRESS` frame path + login timer bridge payload fields).
   - pre-world non-Flash visual stage now builds an explicit typed draw list from those verified
     fields (plus verified `DlgLogo/BgFormat` fallback background contract), then renders from
     that draw list in full-window host viewport space while world gate remains disabled.
   - draw-list now includes parsed `REGION`/`SERVER` payload models based on verified native
     delimiter grammar and build/update cadence from `CLoginFlashDlg_BuildAndPushServerListToFlash`.
6. Non-Flash startup BGM boundary stage:
   - startup presenter keeps verified native host contract (`SELECTBGMUSIC` seed/toggle only)
   - managed startup stage reads `ini/flashLogin.ini` `[bgMusic]` metadata (`path`, `loopTime`, `volume`)
   - startup BGM controller emits typed play/stop requests under that gate and executes playback
     through OpenAL (`NLayer` decode -> PCM16 buffer -> source play/stop).
   - close parity: `CMD_CLOSE` now issues startup-BGM stop before world-frame gate enable dispatch,
     matching native startup-host teardown intent.

Important parity boundary:

- Native 5517 does not keep `CStartupLogoDialog` in the steady frame loop after `0x5AF4F2`.
- The steady pre-world visual experience in retail is Flash-hosted (`start.dat` timeline/UI).
- Since Flash runtime is intentionally removed for cross-platform rewrite, this fallback stage is a
  replacement surface only, not a claim of native draw-path parity.

Current manifest-consumer scope (this slice):

- startup visual runtime resolves and caches the deterministic startup movie manifest;
- manifest is consumed as typed state only (frame/audio/hook metadata), with no behavior-emulation claims yet;
- command dispatch path remains driven solely by verified host variable/callback contracts.

Next verified startup visual slice:

1. BNinja-pin the concrete post-logo startup/login visual update path used while world gate remains disabled.
2. Implement native replacement stage for that post-logo phase (no Flash runtime dependency).
3. Keep world-frame gate behavior unchanged (`this+0x179AB9` remains authoritative).

## Startup BGM Boundary Contract (Verified)

This section pins what native Conquer.exe does (and does not do) for startup music in the
login/startup path.

### Native responsibilities

`CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` (`0x4AB5C5`):

- reads `ini/GameSetup.Ini` section `[FlashMusic]`, key `Enable`, default `1`
- dispatches startup variable `SELECTBGMUSIC` through `VCTOFLASH` payload transport
- payload literal is `"1"` when enabled (`0x923AF4`) and `"0"` when disabled (`0x921768`)

`CLoginFlashDlg_HandleFlashCommandString` (`0x4AA0AE`):

- handles `CMD_SELECTBGMUSIC`
- persists `WritePrivateProfileStringA("FlashMusic", "Enable", value, "ini/GameSetup.Ini")`
  at `0x4AAA32`

### Not present in native startup C++ path

- no direct `_DXPlayMedia@12` startup call in this command/init path
- no direct startup media path parse from `flashLogin.ini` in this C++ boundary

Native startup login music playback is Flash-hosted behavior (inside startup SWF runtime), with
Conquer.exe only providing the enable/toggle value and persistence.

### Managed non-Flash replacement contract

For cross-platform replacement without Flash runtime:

- keep the verified native boundary exactly (`SELECTBGMUSIC` seed + `CMD_SELECTBGMUSIC` persistence)
- source startup BGM media metadata from `ini/flashLogin.ini` `[bgMusic]`:
  - `path` (e.g. `music.mp3`)
  - `loopTime` (loop semantics)
  - `volume` (percent)
- resolve media path relative to client root under `sound/`
- gate playback strictly by current `SELECTBGMUSIC` state (`0` disabled, non-zero enabled)
- close/teardown gate: stop startup media when `CMD_CLOSE` dispatch runs

Current verified startup SWF mapping (`start.dat`):

- `DoAction #1` payload base: `0x0BA3` (CWS-decompressed clean `data/main/start.dat`).
- `loadIni` function body: `0x29CB`.
- `loadIni::<anon>` body (ini parse callback): `0x2A06`.
  - `0x2B41..0x2B53`: local `loopTime = _root.bgMusic.loopTime`.
  - `0x2B67..0x2B8B`: `if (loopTime == 0) loopTime = 9999`.
  - `0x2BAC..0x2BBF`: `this.loadMusic(sPath)` where
    `sPath = mainPath + "sound/" + bgMusic.path`.
- `loadMusic` function body: `0x2E9B`.
- `loadMusic::<anon onLoad(success)>` body: `0x2EB6`.
  - `0x2EBD..0x2EE2`: on success, call `this.start(0.0, loopTime)`.
  - `0x2EE8..0x2EF5`: on failure, call `showTrace("loadMusicError\\n")`.

Call-argument order evidence (same action stream):

- `setCmd2VC(sCmd, sParameter)` definition body: `0x26B5`.
- `cmd_selectR(nIndex)` body: `0x274D`.
  - `0x2762..0x276E` pushes `toString(nIndex)`, then `"CMD_SELECTGROUP"`, then calls
    `setCmd2VC` with arg count `2`.
  - This proves AVM1 call binding uses top-of-stack argument as first formal parameter
    (`sCmd="CMD_SELECTGROUP"`, `sParameter=toString(nIndex)`), so the music call sequence at
    `0x2EC2..0x2EE1` resolves to `start(0.0, loopTime)`.

Verified managed replacement implication:

- `loopTime` from `ini/flashLogin.ini [bgMusic]` maps to effective replay count:
  - `loopTime == 0` -> `9999`
  - non-zero integer -> unchanged
- This mapping is now verified from startup SWF bytecode; no inferred loop policy remains in this path.

This preserves native host contract while replacing Flash-internal playback with managed runtime behavior.

## 2026-10-14: original login asset provenance correction

The research-only [original login UI asset audit](11_login_ui_assets_and_interactions.md) supplies the source hashes, complete symbol/placement/state metadata, authentic extracted frames and exact gaps. The referenced movies reside under `data/main/flash/`. All 14 loose Group movies and 102 server-icon movies were also decoded and packaged; their presence is not proof that every file is selected by the current native payload.

The INI has topDragon/bottomDragon/poetry positions, but the inspected `loadIni` applies only loginFlash/logo/rsDragon positions. Empty named holders are not graphics. Original top/bottom opening motion is recoverable from the opening video and the last three bitmap-layer frames; the final border is shape 400. Do not recreate these graphics from scratch or invent a separate top-dragon loop. Available `rsDragon.swf` is extracted with activation explicitly unresolved.

The companion forensic ZIP distinguishes original bitmap/vector composition, encoded video, held video timeline frames, device-font reference renders and diagnostic hit-test regions. Original H.263 black pixels remain opaque; JPEXS video placeholders are excluded. Runtime text, loadMovie/attachMovie/masks, ActiveX focus arbitration and the 13-frame region asset versus frame-16 request are documented limitations. Existing modern-runtime behavior elsewhere in this note remains a separate implementation record and is not native retail evidence.
