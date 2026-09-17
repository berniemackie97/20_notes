# `GraphicData.dll` — `ActionTransition.ini` and `BufferMotion.ini` loaders

Verified behaviour of the two text INI loaders `GameDataSet_Initialize` calls.

`ini/MeshLod.ini` is loaded in the same initialization phase, but its parser/runtime usage is documented separately:
`17_mesh_lod_ini_and_model_variant_resolution.md`

## Call order in initialization

Within `GameDataSet_Initialize` (`0x10003190`), after core DB loads:

- `GameDataSet_LoadActionTransitionIni(arg1)` (`0x1001CF90`) — `ini/ActionTransition.ini`
- `GameDataSet_LoadImmediateIni(arg1)` (`0x1001DC10`) — `ini/immediate.ini`
- `GameDataSet_LoadMeshLodIni(arg1)` (`0x1001E2A0`) — `ini/MeshLod.ini`
- `GameDataSet_LoadBufferMotionIni(arg1)` (`0x1001D530`) — `ini/BufferMotion.ini`

The return values of these calls are not used by `GameDataSet_Initialize`; initialization continues regardless.

## `ini/ActionTransition.ini` (`GameDataSet_LoadActionTransitionIni`)

Open mode: text (`"r"`).

Top-level token scanner:

- Reads whitespace-delimited tokens via `fscanf("%s\n", token)`.
- Recognizes section headers in the form `[<action_id>]`.

Per section:

1. Parses `Count=<n>`.
2. For each `i` in `[0, n)` parses:
   - `Trans<i>=<target_action_id>`
   - `Time<i>=<transition_time>`
3. Stores only entries where both `target_action_id != 0` and `transition_time != 0`.

The parsed structure is inserted into an internal map on the `GameDataSet` instance keyed by section action id.

String/xref evidence:

- path string: `0x10034860` = `"ini/ActionTransition.ini"`
- only code xref is in `GameDataSet_LoadActionTransitionIni` at `0x1001CFB8`
- open call: `fopen(path, "r")` at `0x1001CFD4`
- mode string address: `0x1003460C` = `"r"`

There is no verified write-mode open (`"w"`/`"a"`) for this path in `GraphicData.dll`.

### Cross-binary check (`Conquer.exe` clean 5517 set)

Binary-wide path scan in the clean 5517 client set shows `ini/ActionTransition.ini` string only in `GraphicData.dll`.

No additional xref/write path was found in `Conquer.exe` for that filename.

Combined with the verified `fopen(path, "r")` loader at `0x1001CFD4`, current evidence indicates read-only policy data in this build.

## Runtime lookup used by `RoleView.dll` (`IGameDataSet` vtable `+0x6C`)

`RoleView_UpdateRolePartMotionsForAction` calls `GameDataSetQuery()->+0x6C(oldActionId, newActionId)`.

This vtable entry maps to:

- `GameDataSet_GetActionTransitionTime` (`0x1001D480`)

Verified behavior:

1. looks up source section `oldActionId` in the top-level transition map (`this + 0xAC` / `this + 0xB0`);
2. if source section missing, returns `0`;
3. looks up target entry `newActionId` in that section's transition-entry map;
4. if target entry missing, returns `0`;
5. on hit, returns the stored `transition_time`.

Disassembly evidence:

- source lookup and miss-return path: `0x1001D499..0x1001D4D5`
- target lookup and miss-return path: `0x1001D4E2..0x1001D518`
- return transition time value: `0x1001D51B..0x1001D523`

No fallback source is present in this function; it is map lookup only.

## `ini/BufferMotion.ini` (`GameDataSet_LoadBufferMotionIni`)

Open mode: text (`"r"`).

Behavior:

- Clears an internal string set on the `GameDataSet` instance.
- Reads whitespace-delimited tokens via `fscanf("%s\n", token)`.
- For each non-empty token, inserts it into the string set.

No per-token numeric parsing is performed.

## Practical parity note

Because initialization ignores loader return codes, these files are effectively optional for startup in this build:

- missing/invalid file => loader returns failure,
- `GameDataSet_Initialize` still proceeds.

For action transitions specifically:

- if `ActionTransition.ini` is missing/empty or has no matching `(oldActionId,newActionId)` pair,
  `GameDataSet_GetActionTransitionTime` returns `0`;
- RoleView still applies the new primary motion, but blend-transition duration is zero.

Bridging evidence for the second point is in:

- `../roleview_dll/07_action_playback_transition_state.md` (`Conquer.exe` per-tick slot `+0x0C` + property `0x0A` feed).
