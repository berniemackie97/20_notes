# New Chat System Prompt — Conquer 5517 Client RE + Rewrite

## Project
Cross-platform rewrite of Conquer Online 5517 Win32 client. .NET 10, C# 13, Silk.NET (OpenGL 4.1 Core Profile).

## Mandatory Workflow (NEVER skip steps)
1. **BNinja verify** — decompile/disassemble in Binary Ninja MCP, rename all `sub_XXXXX`, `var_XX`, `arg_X` to meaningful names. Apply renames in BNinja DB and docs.
2. **Docs update** — write findings into `20_notes/*` markdown docs. Include offset tables, struct layouts, disassembly evidence. follow existing formatting and styling
3. **Code implementation** — implement in C# following the verified docs. Never guess — every field offset, every algorithm must trace back to BNinja evidence.

## Rules
- **100% verified, zero guesswork** — if you can't verify it in BNinja, don't implement it
- **Every rename goes in BNinja AND docs** — no unnamed `sub_` or `field_0x` in final docs
- **Enterprise quality code** — SRP, DI
- **Right-sized work slices** — don't try to do everything in one pass, context windows are finite, work smarter not harder.
- **Build must pass with 0 warnings** (`TreatWarningsAsErrors` is on)
- **Tests must pass** — 617+ tests currently passing, never regress

## Tool Setup
- **Binary Ninja MCP**: 19+ DLLs loaded. Use `select_binary` to switch between them. Key binaries for this first step: `C3_CORE_DLL.dll.bndb`, `graphic.dll.bndb`, `Role3D.dll.bndb`, `TqPackageWdf.dll.bndb`

## Directory Layout you will work within
- `10_work/` — the actual .NET solution (src + tests)
- `20_notes/` — RE documentation (one MD per subsystem)
- `00_clean/clean/5517/` — original game client files + BNinja DBs
- `TestAssets/5517/` — symlinks to real game fixtures

## Key Architecture Facts
- `graphic.dll` wraps `c3_core_dll.dll` (the C3 engine runtime)
- C3 mesh files: 16-byte header + sequential PHY chunks (8-byte headers each)
- 4 PHY types: StaticNormalsUv(' '), SkinnedUv('2'), SkinnedOnly('3'), StaticNormals('4')
- Internal vertex: 52 bytes. GPU vertex: 36 bytes (D3DFVF_XYZ|NORMAL|DIFFUSE|TEX1)
- Native render pipeline: `C3Effect_Render` → `Phy_Prepare` → `Phy_Calculate` → `Phy_DrawNormal_CPU`
- Static meshes use D3DCULL_NONE, alpha blend SRC_ALPHA/ONE_MINUS_SRC_ALPHA, alpha test via shader discard
- System.Numerics matrix upload: `transpose=false` to `glUniformMatrix4fv`
- Z-up to Y-up: `CreateRotationX(+PI/2)` to stand models upright

## Current Task: Skeletal Animation Pipeline
Read `HANDOFF_SKELETAL_ANIMATION.md` — it has the full BNinja-verified findings for `Phy_Calculate_CPU` including:
- 2 bones per vertex, CPU-side skinning
- Internal skinned vertex layout (0x34 stride) with bone indices at +0x18/+0x1C and weights at +0x20/+0x24
- Element-wise 4x4 matrix blend (no quaternion slerp)
- Output is same 0x24 GPU vertex as static meshes

**Remaining work:**
1. Update `05_phy.md` with skeletal animation section from handoff doc
2. Verify `PhySubmeshReader.cs` vertex layout matches the verified internal format
3. Verify claudes work from the handoff to ensure they were 100% correct
4. Implement skinned mesh loading + bone transforms + animation playback
5. BNinja: graphic.dll `C3MotionTracker` — how MOTI chunks connect to PHY submeshes (separate slice)

## Existing Motion Docs (already written)
- `Rendering/c3_core_dll/12_motion_load_formats.md` — MOTI payload (KKEY/ZKEY/XKEY)
- `Rendering/c3_core_dll/13_motion_sampling_and_blend.md` — keyframe interpolation + blend
- `Rendering/c3_core_dll/14_simple_motion_load_formats.md` — SMOT (simple motion)
- possibly others
