# GFX-3D-001 — first static mesh native fixture

2026-10-11. Evidence only. Bundle: [`gfx-3d-001-first-static-mesh-5517/`](../../10_work/docs/evidence/gfx-3d-001-first-static-mesh-5517/README.md)
(raw ASM/IL, extracted records, parse/projection scripts, original-x86 replay, byte buffers, Binja readbacks).
Reused, not reopened: [05_phy](c3_core_dll/05_phy.md), [12_meshcreate](graphic_dll/12_meshcreate_and_c3dobjx.md),
[03_camera](graphic_dll/03_camera.md), [08_depth](c3_core_dll/08_depth_stencil_and_presentation.md),
[13_rsdb](graphicdata_dll/13_rsdb_typed_schemas.md), [04_mesh_load](graphicdata_dll/04_mesh_resource_loading.md),
[11_wdf](c3_core_dll/11_datafile_and_wdf.md), [12_motion](c3_core_dll/12_motion_load_formats.md).
Archived managed loaders/renderers/tests = corroboration only.

## Fixture

| Item | Value |
|---|---|
| Owner | `ini/npc.ini [NpcType40]` (`Name=地摊`, `SimpleObjID=19`, `StandByMotion=9991150100`, `BlazeMotion=9991150190`, `RestMotion=9991150101`, `ASB=5`, `ADB=6`, `FixDir=0`); RoleView type-4 look **400** |
| Object | SimpleObj 19, part 0, object/texture **9990115** |
| Mesh | `c3/npc/9990115100.c3`, PHY 0 `Plane01`, 12 vertices, 10 triangles |
| Texture | `c3/texture/9990115.dds`, 128×128 DXT3, 1 stored level (header mip 0), 128 B header + 16384 B |
| Passes | main, then shadow (default path) |

## Old cube rejected

`c3/mesh/001132000.c3`: 67,129 B, SHA-256 `7cd4ea8b688fc4b09b8e688f7c69f6c0bd1126a32771380a35a3c11e6b71cb7c`; 4 PHY + 4 MOTI.

| PHY | Name | Verts | Tris | Native |
|---:|---|---:|---:|---|
| 0 | `v_armet` | 24 | 12 | virtual attachment, skipped |
| 1 | `v_l_weapon` | 6 | 8 | virtual attachment, skipped |
| 2 | `v_r_weapon` | 6 | 8 | virtual attachment, skipped |
| 3 | `v_body` | 687 | 952 | body, motion-bearing |

24/36/12/20³ = PHY 0 only, bounds `(-10,-10,-20)..(10,10,0)`.
- Owner row: body model **1130100** (`ini/armor.dbc` off 272 = `743e110001000000e04511004c8920000000000000050600`: object 1132000, primary tex 2132300, secondary 0, shader 0, blends 5/6, material 0; packed = loose). `3DObj[1132000]` → path. Numeric model/mesh match ≠ binding.
- Caller: RoleView `PlayerRoleView_ReloadBodyVariantAtLayerAndRefreshHelmetFamily` `0x10001CE4` → `PlayerRoleView_LoadPartSourceIntoI3DRole` `0x10003381` → I3DRole vtbl+0x10 (Role3D `I3DRole_LoadPartByName` `0x10002790`) → `PartInfo_LoadFromGameData` `0x100057A0`; args `(body,v_mount,mount,1130100,0)`.
- Hide: GraphicData `ResourceExecute_LoadMesh` `0x10005960` loop `0x10005E7E`: count mesh+0x30, name mesh+0x2C(i), dataset+0x58 (RolePart custom names) hit → mesh+0x70(i,1). graphic `C3DObjX_Render` `0x10004330`: byte `this+0x54+i` ≠0 → skip (`0x10004385`).
- `v_armet` = attachment id. Not DDS path, not displayed cube.

## Binding chain (SimpleObj 19)

| Step | Native | Result |
|---|---|---|
| 1 | RoleView `RoleView_Type4_SetLookId_LoadRoleData` `0x10004A68`: `RoleDataQuery()->vtbl+0x30(look/10)` | look 400 → row 40; SimpleObj `+0x04(row+0x50=19)` |
| 2 | Role3D `Simple3DObj_SetModelId_LoadPartInfo` `0x10007230`: dataset +0x44 (SIMX) then +0x40 (SIMO) | SIMX empty; SIMO 19 off 264 = `1300000001000000e36f9800e36f9800` → pair (9990115,9990115) |
| 3 | SIMO init | secondary 0, shader 0, material ptr null, blends 5/6 |
| 4 | `PartInfo_ResolvePartMesh` `0x10006820`: dataset +0x74 (LOD), +0x14 (mesh) | no `MeshLod.ini` → 9990115; `3DObj[9990115]` → C3 path; `Plane01` not a RolePart virtual name |
| 5 | `PartInfo_BindPerPartTexturesAndMaterial` `0x10006620`, overrides null: dataset +0x18 | primary 9990115; secondary 0 → no record → null; mesh +0x58/+0x5C null name selectors → all PHYs |
| 6 | GraphicData `ResourceExecute_LoadTexture` `0x100075F0` → graphic `TextureCreate` `0x10005470` → `C3DTextureX_Create` `0x100050F0` | `Texture_Load(out,path,8,1,0,0,-1)`: 8 mips, managed pool, no reuse scan, colorkey 0, default filters |
| 7 | core `Texture_Load` `0x10016360` registers first free `g_pTexDB` slot (`0x100165CF`) | runtime index = load-order slot (empty registry → 0), ≠ content ID; draw reads `g_pTexDB[i]->+0x0C` |
| 8 | graphic `C3DObjX_SetPrimaryTexture` `0x10004500` → core `Phy_ChangeTexture` `0x1000E0F0`; mix `0x100045A0` → `Phy_ChangeMixTexture` `0x1000E100` (null → -1) | primary slot / mix -1 |
| 9 | `PartInfo_RenderAllParts` `0x10005EB0` → mesh+0x60(0,0); graphic `0x10007250` | shader mode 0 → (4,0) |

No `Plane01` filename match, no model back-scan, no secondary/material-name lookup. Null material → no `SetMaterial`; constructor material kept: Diffuse (1,1,1,1), Ambient (.5,.5,.5,.5), Specular (1,1,1,1), Emissive 0, Power 0. MATR `default` not selected.

### Source precedence

GraphicData `GameDbPack_LoadAndUpdateC3Wdb` `0x100280A0`: loose update replaces packed entry when present (`0x10028471`/`0x100285DC`), else packed kept. Modelled read-only.

| Winner | Key | Rec/index off | String off → value |
|---|---:|---:|---|
| loose `ini/3DSimpleObj.dbc` | 19 | 264 | (9990115,9990115) |
| loose `ini/3DObj.dbc` | 9990115 | 6696 | 31945 → `c3/npc/9990115100.c3` |
| loose `ini/3DTexture.dbc` | 9990115 | 1784 | 118353 → `c3/texture/9990115.dds` |
| loose `ini/3DMotion.dbc` | lo `0x5384DA14` hi `2` | 1629428 | 6910684 → same C3 |
| packed `ini/3DSimpleObjEx.dbc` | — | — | SIMX count 0, len 8 |
| packed `ini/RolePart.dbc` | body | — | armor/3dmotion config |

First three agree with packed DB. Standby key 9991150100 absent from packed motion table (has historical 999115100 → same file); do not substitute.

Mesh `Common_OpenRes(...,1)` package-only (core `0x10001D90` → TqFOpen). Texture_Load: loose first, package fallback. Both winners in `c3.wdf`:

| Resource | Len | UID | WDF table off | Payload off | SHA-256 |
|---|---:|---|---:|---:|---|
| `c3/npc/9990115100.c3` | 14113 | `0x4E6EED6F` | 358956604 | 295736634 | `3e08a68a255b89a5881e182a8783368285be31d7d03369bad9099c4613ea2987` |
| `c3/texture/9990115.dds` | 16512 | `0x3B7DDE84` | 358943388 | 355514780 | `914c19f478463738a308300c657fc31c6c89e5d292fe92dfb2c8cd44e19c3f7f` |

## Geometry

- `PHY ` payload off 24, len 1141, name `Plane01`, flags 2, vertex-count pair (8,4), face-count pair (8,2) (pairs ≠ static/skinned classifier).
- Vertices off 47, stride 76; indices off 967, 30 × u16. No alpha/draw/tex-change keys, no `2SID`, no billboard; STEP frames 1, offsets 0.
- File object matrix: uniform scale `13.267255783081055`, Z translate −5; Phy_Load bakes into positions, then established normal smoothing. Do not reapply at draw.
- Output stride 36 (diffuse +24, UV +28).
- MOTI payload off 1173, len 12940: 2 bones, 101 frames, uncompressed matrices, bone-major. All verts: influence 2 = bone 0 weight 1, influence 1 weight 0. Bone 0 byte-identical all 101 frames; bone 1 unused.

```text
bone0 (row-major)
 0.9975640774 -0.0697564706  0  0
 0.0697564706  0.9975640774  0  0
 0             0            1  0
 0.0343960971  1.9419987202  0  1
```

- `ResourceExecute_LoadMesh` requires default motion from this C3; type-4 standby resolves same C3. `Phy_Calculate` frames 0..100 → byte-identical 432 B VB. Bake bone 0; never skip it.

| Vertex 0 | Position | Normal | UV | Diffuse |
|---|---|---|---|---|
| after Phy_Load | (-79.603530884, -39.801765442, -4.999773502) | (-0.447213590, -0.894427180, 0) | (0.0004995167, 0.9995000362) | `0xFFFFFFFF` |
| after Phy_Calculate | (-82.151657104, -32.209949493, -4.999773502) | (-0.508516312, -0.861052394, 0) | same | same |

Post-calc bounds `(-82.151657104,-43.315673828,-5.456344128)..(82.220458984,47.199672699,-4.999773502)`: thin rectangle with edge geometry.

## Instance + transforms

Pinned: SimpleObj 19 ctor defaults, frame 0, no effects/tint/override, Render args 1–2 = (-1,-1) → SIMO blends. Type4 passes NPC ASB/ADB in args 3–4; `Simple_Render` pops 4 (`ret 0x10`), uses only 1–2. 5/6 here come from SIMO, not NPC ASB/ADB.

Ortho camera W×H, placement (x=W/2, y=H/2, height 0, scale 1); look 400 → direction −45°, oblique −30°. API inputs only, not live-world placement.
Role3D `Simple3DObj_SetPositionHeightDirectionScale` `0x10006C00`: int x/y/height/direction + float scale; stores 2×height. `Simple_Render` `0x10006C90`, `PartInfo_ComputeWorldAndSetSubmeshMatrices` `0x10006520`; graphic `0x100046B0` writes A/B/world → PHY +74/+B4/+F4.

```text
A = RotZ(-45deg)
B = RotX(-30deg) * Translate(W/2, 0, H/2)
world = partLocal(identity) * A * B
clip = bakedBonePos * world * view * proj        (row vectors)
view: (x,y,z,1) -> (x-W/2, H/2-z, y+1000, 1)
proj: ortho LH, W x H, near 1, far 10000
GL clipZ = 2*D3DclipZ - clipW
```

UVs native normalized, no V flip. Transpose for GLSL preserving row-vector order.

## Draw-state vector

| Input | Main | Shadow |
|---|---|---|
| PHY order | 0 | same PHY, right after main |
| Geometry | FVF `0x152`, stride 36, u16 IB | same buffers |
| DrawIndexed | (TRIANGLELIST 4, min 0, verts 12, start 0, prims 10) | same |
| Primary / mix | runtime slot of 9990115 / -1 | stage0 tex null |
| Tex shader | (4,0) | — |
| Stage0 color/alpha op | MODULATE/MODULATE | DISABLE/DISABLE |
| Stage0 args | TEXTURE2 / CURRENT1 (D3D defaults; CURRENT = diffuse at stage0) | — |
| Stage1 | disabled | disabled |
| Diffuse / alpha | white / 1 | material RGB 0, Diffuse.a .3 |
| Lighting | off (clean `graphic.ini` light0=0) | on for shadow material |
| Blend | on, SRCALPHA 5 / INVSRCALPHA 6 | same |
| Alpha test | on, GREATEREQUAL 7, ref 8 | unchanged |
| Z | on, LESSEQUAL 4, write on | LESS 2, write on |
| Cull | CW 2 (per-PHY select) | CW 2 |
| Address U/V | WRAP 1 | — |
| MIN/MAG | LINEAR 2 if MaxAnisotropy<2, else ANISOTROPIC 3, max 2 | kept |
| MIP | LINEAR 2 | kept |

Caps base core `0x100B01F8`; `+0x6C` MaxAnisotropy tested `0x1000BA46`. Stage-arg defaults: [MS texture-stage states](https://learn.microsoft.com/en-us/previous-versions/windows/embedded/ms886612%28v%3Dmsdn.10%29), [D3DTA](https://learn.microsoft.com/en-us/windows/win32/direct3d9/d3dta).

### Cull (corrects prior notes)

core `0x1000CD0F..0x1000CD3D`: byte PHY+5 ≠0 → `push 1`; =0 → `(desc+9 != 0)+2`. `Phy_Clear` `0x1000A216` zeroes +5; `Phy_Load` `0x1000B1F7` sets 1 on `2SID`.

| has2SidTag | selector | D3DCULL |
|---:|---:|---|
| 0 | 0 | CW 2 |
| 0 | 1 | CCW 3 |
| 1 | 0 | NONE 1 |
| 1 | 1 | NONE 1 |

All 4 executed on original x86. Fixture CW = per-PHY select (equals Phy_Prepare baseline by coincidence).
Y-down screen signed areas: tris 0–3, 8–9 negative; 4–7 positive. Keep index order. Y-up GL framebuffer + stated mapping: D3D-visible faces → GL CCW front / cull back. Do not negate both angles as shortcut.

### Shadow + cleanup

- Simple ctor: mode 2, light dir (0,0,1000), scalar 0.3. `C3DObjX_Render` `0x100043A9..0x10004447`: light (0,0,1000,1), plane (0,0,1,0).
- graphic `MatrixShadow` `0x1001CC09` (executed): rows `1000 0 0 0 / 0 1000 0 0 / 0 0 0 -1 / 0 0 0 1000`. Desc +0x40=.3, +0x44=1.
- `shadowWorld = A * shadowMatrix * B * view * flatten`; flatten = identity, M33=0, M43=view.M43×1.5. VIEW=identity, ortho proj kept, same indexed tris. Keep homogeneous W.
- After shadow: restore VIEW, ZFUNC LESSEQUAL, stage0 ops 4; disable lighting. Not restored: main world, stage0 texture, material. `PartInfo_ResetAllMeshSubmeshColorAndMatrices` `0x100065D0` resets PHY colors/matrices, not motion/frame. No transparency sort established.

## Checks

| Test | Expected | Authority |
|---|---|---|
| Cube identity | 4 PHY; first 3 hidden virtual | content + native trace |
| SIMO/object/texture winners | ids/paths/bytes above | extraction + schema |
| Packed-only standby | 9991150100 absent; loose present | extraction |
| PHY load | ret 1, stream @1165, VB 432 B, IB 60 B | original x86 (file/buffer mocked) |
| Frames 0..100 | identical 432 B VB | original x86 |
| Empty TexDB | slot 0, content id 9990115 | original Texture_Load (decoder mocked) |
| Cull 4 cases | table above | original x86 |
| 800×600 & 1024×768, cap 1 & 2 | main+shadow, 2 × 10-tri draws, filter branch exact | original prepare/draw x86 |
| Missing primary tex / mesh dep | Simple_Render ret 0, no draw | `PartInfo_AllDependenciesReady` `0x10005DF0` |
| Missing object path / default motion | mesh never ready | LoadMesh fail branches |
| Runtime tex id ≥0, null registry | ret 0, no draw | original x86 |
| drawEnabled 0 / faces 0 / alpha 0 | ret 1, no draw | original x86 |
| Vertex 0 @800×600 | screen (319.134134, 278.013009), D3D z .102718576 | formula (not GPU) |
| Vertex 0 @1024×768 | screen (431.134134, 362.013009), same z | formula |

Tolerance: exact bytes for replayed scalar path; `1e-4` for cross-platform formula checks (not a framebuffer tolerance). No SSE/3DNow bit-identity claim.

## Status

| Class | Items |
|---|---|
| Already verified (reused) | PHY parse, normals, packed layout, camera math, generic D3D8 states, WDF modes |
| Newly verified | cube = virtual attachments; SimpleObj 19 owner/binding chain; source precedence; constant bone; draw vector; shadow pass; **cull table inversion** |
| Independently reproduced | PHY load, Phy_Calculate ×101, Texture_Load slot, prepare/draw ×4, MatrixShadow (original x86 replay) |
| Unresolved (GPU gate) | no native framebuffer: DXT3 decode, mip generation, anisotropic sampling, raster rules, D16, final blend pixels |
| Unnecessary | live world placement, other NPC actions, bone 1, other families, equipment, perspective, mix-texture shader modes, general shadow maps |

No native semantic blocker for this fixture.
