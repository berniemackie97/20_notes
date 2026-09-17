# Reference binaries and sources — what each one can prove

Measured 2026-09-06. Truth is always the 5517 binary; everything here is a lead source.

## Build-tree roots seen in assert strings

| Binary | Root path | Renderer |
|---|---|---|
| 5517 `Conquer.exe` | `F:\CQ2ClientRelease-42.0.1\` | — |
| 5517 `graphic.dll`, `Role3D.dll`, `GraphicData.dll` | `F:\Projects\C3Engine_Official\` | D3D8 |
| C3Tools studio `Role3D.dll` | `D:\C3_WorkArea\C3_Release_Official_OpenGL_Windows_Source_12_12_21\` | OpenGL |

`C3_CORE_DLL.dll` carries no assert strings.

## C3Tools studio toolkit (`40_tools/C3Tools`)

A **later, divergent OpenGL branch** of the C3 engine, not the 5517 revision. Evidence:
OpenGL globals (`g_hDeviceGLRC`, `SetThreadOpenGLContext`), mobile-era additions
(`Camera_SetOrientationMode`, `Camera_IsLandscapeMode`, `Camera_EnsureEnterFlatMode`),
dropped Arabic text path, and typo fixes (5517 `PrepareModle`/`ChangeDisplayResulotion` →
studio `PrepareModel`/`ChangeDisplayResolution`). Struct renames too: 5517 `CMySize` →
studio `C3_SIZE`, `IDataIcon` class → struct.

Export counts, studio vs 5517 client:

| DLL | studio | client | verdict |
|---|---|---|---|
| graphic.dll | 411 | 168 | 124 studio-only base names, nearly all OpenGL-branch or already exported by `C3_CORE_DLL` |
| GraphicData.dll | 28 | 2 | **the one real win** — whole `CDataThreadObj` class, harvested 2026-09-06 |
| Role3D.dll | 11 | 9 | 3 studio-only, all absent from 5517 (see below) |
| TqPackage / TqPackageWdf | 15 / 14 | 14 / 14 | nothing new |
| DataThread.dll | 1 | 1 | studio `DataThreadCreateNew(ulong,ulong)`, 5517 takes no args |

Across every binary: 2820 client exported symbols, 572 studio, 255 studio-only base names —
98 of those are tool-only (`C3ToolkitsContext.dll`).

Absence check that worked: studio `I3DRole_IsVirtualPhyIntersect` asserts
`pRolePart1 && pRolePart2`; that string is not in the 5517 `Role3D.dll` at all, so the
function is an OpenGL-branch addition. Do not go looking for it.

**Rule:** a studio-only name is a lead, never evidence that 5517 has the function.

## Assert strings as a cross-build anchor

Both branches embed `(source file, line, assert expression)` at each `assert` site. The
expression text survives across builds and names the original variables, so a shared
expression pins the same function in both. 5517 assert-string counts:
`Conquer.exe` 407, `graphic.dll` 10, `Role3D.dll` 6, `GraphicData.dll` 5, `C3_CORE_DLL.dll` 0.

The 5517 `Role3D.dll` assert sites all sit in unexported internals on the studio side too,
so that pair yields no transferable name.

## Conquer.exe translation units

398 unique source paths under `F:\CQ2ClientRelease-42.0.1\`, in `MyShell` (211), `3DRole` (96),
`3DGameMap` (43), `Network` (37), `BaseCode` (7). Full list with source-availability flags:
`conquer_exe_translation_units.md`.

108 of them exist by filename in `40_tools/fight-master/my_client` and `40_tools/eosource`
(same 108 — both are the same older tree). An assert site therefore identifies the TU a
function belongs to, and for those 108 there is a source file to read alongside it.

## Tooling

`rizin` is installed (`/opt/homebrew/bin/rizin`), so reference binaries that are not loaded in
the Binja MCP server can still be disassembled offline — `rizin -q -N -A -c 'pdf' <file>`,
`izj` for strings, `axt @ addr` for xrefs. Used it to read the studio DLLs.
`scratchpad/pe_exports.py` dumps a PE export table with RVAs and image base.
