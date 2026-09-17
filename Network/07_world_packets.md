# World Packets — Map, Weather
## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Network\

---

## MsgWeatherUpdate (Type 1016)
**Direction**: S→C
**Purpose**: Weather update packet (drives `CWeather__*` state updates)  
**Dispatch**: Create `CMsgWeatherUpdate__Create` (0x760667), parse `CMsgWeatherUpdate__Parse` (0x7607DE), process `CMsgWeatherUpdate__Process` (0x760801)

**Verified parse behavior**:
- `CMsgWeatherUpdate__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1016`.

**Verified field usage in `CMsgWeatherUpdate__Process`** (offsets relative to packet start):
- `+4`, `+8`, `+12`, `+16` are passed to `CMsgWeatherUpdate__ValidateAndNormalize` and later to `CWeather__SetWeather` / `CWeather__UpdateWeatherParams` depending on sub-state.

**Verified component path in `CMsgWeatherUpdate__Process`**:
- resolves the first map component with type code `5` via
  `CGameMap_FindFirstComponentWithTypeCode5` (`0x61D6A8`);
- then dispatches one of three helper calls on that component state:
  - `CGameMapComponentType5_SetWeatherKindAndParams` (`0x62D753`)
  - `CGameMapComponentType5_UpdateWeatherParams` (`0x62D992`)
  - `CGameMapComponentType5_ClearWeatherState` (`0x62DB0B`)
- callsites:
  - `0x760850..0x760864` -> set full weather kind + params
  - `0x76086B..0x76087D` -> update params for current weather kind
  - `0x760872` -> clear active weather state

**Parity note**:
- In the current managed startup/bootstrap slice, `1016` is part of the conservative post-`74` world-entry window consumed before `0x483` hands control to the scene frame loop.
- Managed runtime mapping now persists the verified weather tuple `[kind, intensity, directionDegrees, parameter]`
  into shared world state via `ClientWorldInboundPacketApplyRuntime`, and the scene now feeds that state through a
  real type-`5` map component runtime (`CGameMapComponentType5WeatherRuntime`) during map-stage tick.
- This still does **not** claim native particle/visual weather rendering parity; it only removes the dead-stub gap so
  weather state reaches the same map-component layer the native handler targets.


## MsgWeather (Type 1028)
**Direction**: S→C
**Purpose**: Weather update (verified by `CWeather__SetWeather` / `CWeather__UpdateWeatherParams` calls).
**Dispatch**: Create `CMsgWeather__Create` (0x7534A1), parse `CMsgWeather__Parse` (0x753507), process `CNetMsg__NoopProcess` (0x5AD9B1)

**Verified parse behavior**:
- `CMsgWeather__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1028`.

**Verified processing behavior**:
- Process handler is `CNetMsg__NoopProcess` (no-op).


## MsgMapInfo (Type 1052)
**Direction**: S→C
**Purpose**: Map info + validation handshake (verified by `CMsgMapInfo__Build` and `CNetClient__Connect` usage).
**Dispatch**: Create `CMsgMapInfo__Create` (0x754364), parse `CMsgMapInfo__Parse` (0x7544C5), process `CMsgMapInfo__Process` (0x75464C)

**Verified parse behavior**:
- `CMsgMapInfo__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1052`.

**Verified field usage in `CMsgMapInfo__Process`** (offsets relative to packet start):
- `+4` (u32) gates the whole handler. If `== 0`, it routes to an error path and returns; if nonzero, it is stored into singleton offset `+2716` and used in follow‑on calls.
- `+8` (u32) is used in multiple calls and in the error path: passed to `CMsgConnect__HandleError` and `MFC__SetDword_0x4`, combined in a checksum-like value, and passed to `CMsgMapInfo__Build`.
- `+12` is treated as a pointer to a string/buffer and passed to `CNetClient__Connect(buf, 0x16B8, 30)` as part of a validation path.

### Verified client-built `1052` helper variants

The same message class also exposes two separate client builders used in the login transition path:

- `CMsgMapInfo1052__BuildSimpleString` (`0x7543CA`) — account-server follow-up after `1055` success.
- `CMsgMapInfo1052__Build` (`0x75443E`) — post-DH game-server login proof.

`CMsgMapInfo1052__BuildSimpleString` layout (C→AccountServer, size `28`):

| Offset | Size | Field |
|--------|------|-------|
| +0 | 2 | size (`28`) |
| +2 | 2 | type (`1052`) |
| +4 | 4 | session token |
| +8 | 4 | `res.dat` version |
| +12 | 16 | resource string (`"res.dat"`) |

`CMsgMapInfo1052__Build` layout (C→GameServer, size `28`, sent after DH completes):

| Offset | Size | Field |
|--------|------|-------|
| +0 | 2 | size (`28`) |
| +2 | 2 | type (`1052`) |
| +4 | 4 | session token |
| +8 | 4 | login auth key |
| +12 | 2 | mode (`0x7C` in the verified login path) |
| +14 | 2 | locale tag |
| +16 | 6 | hardware key |
| +24 | 4 | `res.dat` version |

Call-order anchor:

- `CMsgAccountAuthResponse__Process` (`0x75492C`) sends the simple-string `1052` before disconnecting the account socket.
- `CConnectionFlow__SendGameSessionBootstrap` (`0x6DF1D0`) sends the post-DH game `1052` on the verified non-Facebook startup path and `1203` on the startup-movie/Facebook variant.
