# `GraphicData.dll` — `immediate.ini` loader semantics

This document captures verified behavior for `GameDataSet_LoadImmediateIni` (`0x1001DC10`).

## File and open mode

- Path: `ini/immediate.ini`
- Open mode: text (`"r"`)

## Parser behavior

The loader scans whitespace-delimited tokens using `fscanf("%s\\n", token)` and applies:

1. Skip token if length is `1`.
2. Skip token if first byte is `';'` (comment token).
3. If token starts with `'['`:
   - parse section name from bracket form `[sectionName]`,
   - create/find section node in an internal section map,
   - set this section as current.
4. Otherwise parse token as unsigned 64-bit integer (`%I64u`):
   - only when a current section exists,
   - insert the parsed id into that section's id-set.

As a result, `immediate.ini` is represented as:

- `sectionName -> set<uint64 resourceId>`

with section names as ASCII text labels (for example `mesh`, `texture` in the stock file).

## Integration points

- Called by `GameDataSet_Initialize` (`0x10003190`) after `ActionTransition.ini` loader and before `MeshLod.ini` / `BufferMotion.ini`.
- Return value is not checked by `GameDataSet_Initialize`; startup proceeds even if this loader fails.

## Runtime lookup helper

`GameDataSet_IsImmediateResourceId` (`0x1001E0D0`) consumes the loaded map at runtime:

- input:
  - section name (`const char*`)
  - resource id (`uint64` split into low/high dwords at callsites)
- behavior:
  - finds section node in the `immediate.ini` section map,
  - performs ordered-set lookup for the resource id,
  - returns non-zero only when section exists and id is present.

## Request-mode override behavior

The following request methods call `GameDataSet_IsImmediateResourceId` before scheduling:

- `GameDataSet_RequestMesh` (`0x10005670`) with section `"mesh"`
- `GameDataSet_RequestTexture` (`0x100067A0`) with section `"texture"`
- `GameDataSet_RequestEffectDrawResource` (`0x10006A90`) with section `"effect"`
- `GameDataSet_RequestSceneResource` (`0x10006D90`) with section `"scene"`
- `GameDataSet_RequestNamedModelResource` (`0x10006380`) with caller-supplied section name and `uint64` id

Verified mode rewrite sequence in those functions:

1. If `GameDataSet.force_immediate_load` flag (`byte [this+0x350]`) is set, mode is first forced to `1`.
2. If `GameDataSet_IsImmediateResourceId(section, id)` returns non-zero, mode is forced to `1`.
3. If the original caller mode was `3`, final mode is forced to `0` (special-case override after step 2).

Observed downstream behavior:

- `mode == 1` takes the synchronous/immediate backend call path.
- other mode values enqueue/defer through the worker queue path.
