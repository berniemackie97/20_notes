# `Sprite_Rotate` native behavior contract (5517)

## Authority and identity

Verified 2026-09-09 through the live Binary Ninja MCP databases. Native instructions,
data, exports and cross references are authoritative. No legacy-project algorithm or
modern production implementation supplied any conclusion in this report.

| Binary | SHA-256 |
|---|---|
| `C3_CORE_DLL.dll` | `f5bbe1d408320de33c17422b58576d3e883fa6f93830fe159ac27f3396551a7b` |
| `graphic.dll` | `b099913f83c13b863ea2738f3f95f81ec2eb186b80c16e7ba7fdacf4feea9d46` |

Databases: `00_clean/clean/5517-bninja/{C3_CORE_DLL.dll,graphic.dll}.bndb`.
Original files: `00_clean/clean/5517/`. The export directory at `0x100A72B0`
has ordinal base 1. EAT entry `0x100A752C` contains RVA `0x159D0`, proving
ordinal **150**, VA **0x100159D0**, export
`?Sprite_Rotate@@YAXPAUC3Sprite@@H@Z`:

```c
void __cdecl Sprite_Rotate(C3Sprite* sprite, int32_t angleDegrees);
```

Raw MCP captures, byte verification, import inventory and replay results are retained in
[`10_work/docs/evidence/sprite-rotate-5517/`](../../../10_work/docs/evidence/sprite-rotate-5517/README.md).
See the evidence README for execution limits. No modern OpenConquer code was edited.

## Conclusions

- Input is **signed integer degrees**, reduced with signed remainder by 360.
- Positive rotation uses the matrix sign convention that turns rightward toward
  downward in screen XY: **clockwise**.
- The pivot is computed from CURRENT vertex components, once at the beginning of
  each call. For a freshly configured ordinary rectangular sprite it is the
  destination rectangle's center including the stored half-pixel offset.
- Rotation overwrites the four vertices' X/Y fields in place. It never retains an
  original rectangle or angle. Repeated direct calls accumulate and can move the
  recomputed pivot; they are not equivalent to one rotation by the sum.
- Source rectangles determine UVs. Stretching determines destination geometry
  before rotation. Rotation preserves UV, color, Z, RHW and texture.
- Draw functions consume the current geometry without rotating or resetting it.
  All seven discovered direct caller sites rebuild geometry before rotation.
- **There is no single CPU-independent bit-exact numerical result.** The scalar,
  SSE/SSE2 and 3DNow! paths differ. In particular, the native SSE transform uses an
  unrefined reciprocal-derived factor from the wrong intermediate register relative
  to the refinement it has just calculated. This is a verified instruction sequence,
  not a proposed correction.

## Sprite layout

The export allocators use 0x74 bytes; `Sprite_Clear`, `Sprite_SetCoor`,
`Sprite_SetColor` and draw stride confirm the following layout. Applied to Binary Ninja
as `SpriteVertex` and `C3Sprite`.

| Per-vertex offset | Type | Meaning |
|---:|---|---|
| +0x00 | float | X |
| +0x04 | float | Y |
| +0x08 | float | Z |
| +0x0C | float | RHW |
| +0x10 | uint32 | packed ARGB |
| +0x14 | float | U |
| +0x18 | float | V |

Four records, stride 0x1C, followed by texture pointer at sprite+0x70.
Vertex order established by `Sprite_SetCoor`: **0 top-left, 1 bottom-left,
2 top-right, 3 bottom-right**. `Sprite_Clear` (`0x10015840`) zeros vertex fields,
then sets RHW=1, color=0xFFFFFFFF and full-rectangle UVs; texture becomes null.

## Entry-point arithmetic and mutation

Let `F32` mean a binary32 store using the effective native floating-point state,
and `X87(expr)` mean the emitted x87 operations in their original order.
It does **not** mean rounding every intermediate to binary32.

```text
if sprite == null: return

n = signed_remainder(angleDegrees, 360)  // quotient truncates toward zero
pivotX = F32(X87((v2.x - v0.x) / 2.0f + v0.x))
pivotY = F32(X87((v1.y - v0.y) / 2.0f + v0.y))
theta = F32(X87(F32(n) * float_from_bits(0x3C8EFA35)))

R = dispatched MatrixRotationZ(theta)
T = dispatched MatrixTranslation(pivotX, pivotY, +0.0f)
M = dispatched MatrixMultiply(R, T)      // R * T, 16 binary32 components
copy all 64 bytes of M to transformMatrix

for i = 0..3:
    dy = F32(X87(vi.y - pivotY))
    dx = F32(X87(vi.x - pivotX))
    local = (dx,dy)
    dispatched Vec2TransformCoord(&local, &local, &transformMatrix)
    vi.x = local.x
    vi.y = local.y
```

| Evidence | Native instruction range |
|---|---|
| Null check and return | 0x100159DE..0x100159E0, 0x10015AD9..0x10015AE0 |
| Signed `CDQ; IDIV 0x168`, remainder EDX | 0x100159F2..0x10015A0F |
| Pivot X / binary32 store | 0x100159E6..0x10015A05 |
| Pivot Y / binary32 store | 0x10015A09..0x10015A23 |
| Remainder conversion and radian binary32 store | 0x10015A27..0x10015A39 |
| Rotation / translation / multiplication calls | 0x10015A3D / 0x10015A53 / 0x10015A6A |
| Local-coordinate binary32 stores | 0x10015A97 / 0x10015AAD |
| In-place vector helper call | 0x10015ABF |
| X/Y stores and four-vertex loop | 0x10015ACC..0x10015AD5 |

Constant `0x100A1784`: bytes `35 FA 8E 3C`, binary32
**0.01745329238474369049072265625**. Divisor `0x100A1788`: `00 00 00 40`, 2.0f.
Negative input retains a negative remainder; there is no conversion to [0,360).
The reduced magnitude is at most 359, so the angle passed to trigonometry is bounded.
No zero-angle fast path, integer conversion of output, pixel snap, clamping,
finite-coordinate validation or texture dereference occurs in `Sprite_Rotate`.

## Matrix convention and scalar result

`MatrixRotationZ_Scalar` executes `FSINCOS` at `0x100183BF`, stores cosine
and sine to binary32 at `0x100183C1/C3`, then constructs:

```text
R = [ c  s  0  0 ]       T = [ 1   0   0  0 ]
    [-s  c  0  0 ]           [ 0   1   0  0 ]
    [ 0  0  1  0 ]           [ 0   0   1  0 ]
    [ 0  0  0  1 ]           [ px  py  0  1 ]
```

For finite ordinary affine inputs, the scalar transformed position is:

```text
X = F32(X87((dx*c + dy*(-s)) + px))
Y = F32(X87((dx*s + dy*c) + py))
```

This is a reduction of the verified matrix/helper sequence, not permission to skip
its rounding boundaries. The pivot is the center of **stored** fresh geometry,
not the source rectangle, texture origin, logical (0,0), top-left corner or an
extra caller-supplied origin. Initial `px = screenX - 0.5 + width/2` and the
corresponding Y equation are geometric descriptions for normally representable
coordinates; the exact definition always uses the stored vertices above.

The scalar helper computes and stores:
`X=dx*M11+dy*M21+M41`, `Y=dx*M12+dy*M22+M42`,
`W=dx*M14+dy*M24+M44`. If `FloatWithinMachineEpsilon(W,1)` succeeds, division
is skipped; otherwise it computes x87 `1/W`, multiplies the already-stored X/Y,
and stores binary32 again (`0x1001976B..0x1001979E`).
For finite affine rotation/translation, W=1. The epsilon helper
(`0x10016D16`) tests an inclusive +/-binary32 epsilon interval.

The optimized scalar matrix multiply stores each element after the emitted x87
sum **(p0+p2)+(p3+p1)** at `0x10028A68..0x10028A8A`.
SSE multiplication uses sequential binary32 products/additions; 3DNow! uses packed
products and pair sums. These are distinct numerical contracts.

## Repeated calls and the moving pivot

The first pivot is saved before any vertex is mutated. No vertex iteration changes
that saved pivot. The next **call**, however, reads the already-mutated vertices.

For an ideal initially rectangular quad centered at C with width W and height H,
after one pure rotation by theta the next component-derived pivot is
`(Cx + H*sin(theta)/2, Cy - W*sin(theta)/2)`. This equation explains the drift;
it is not a bit-exact substitute for the native float sequence or SSE scaling.

Original-instruction scalar replay, screen (10,20), destination 4x2:

| State | v0 | v1 | v2 | v3 |
|---|---|---|---|---|
| Fresh | (9.5,19.5) | (9.5,21.5) | (13.5,19.5) | (13.5,21.5) |
| After +90 | (12.5,18.5) | (10.5,18.5) | (12.5,22.5) | (10.5,22.5) |
| After another +90 | (12.5,18.5) | (12.5,16.5) | (8.5,18.5) | (8.5,16.5) |

Pivot changes from (11.5,20.5) to (12.5,18.5). The replay's exact binary32 bit
patterns are retained. These sample numbers are emulator observations under
explicit FPU settings, not universal physical-hardware vectors.
Calling `Sprite_SetCoor` again resets geometry and removes this accumulated history.

## Runtime dispatch and exact numerical paths

Initializer `RuntimeDispatch_InitializeMath` (`0x1001C3F8`) handles 57 pointers
at `0x100AA2B8`. It copies defaults from `0x100AA3A0`, installs scalar
overrides, then reads HKLM `Software\\Microsoft\\Direct3D`,
REG_DWORD `DisableD3DXPSGP`. Value 1 keeps scalar selection. Otherwise it
queries features in order **7, 10, 6**, using Windows/CPUID helpers; the selected
installers provide 3DNow!, SSE2 and SSE respectively. The initialized backend
marker is at `0x100AA48C`; the uninitialized/reset sentinel is 0xFFFF.

| Operation / dispatch slot | Scalar | SSE and SSE2 | 3DNow! |
|---|---|---|---|
| RotationZ / 0x100AA338 | 0x100183A4 | 0x100183A4 | 0x100328E3 |
| Translation / 0x100AA320 | 0x100181ED | 0x100181ED | 0x1003260B |
| Multiply / 0x100AA2C4 | 0x100289C6 | 0x1002EC70 | 0x1003230A |
| Vec2TransformCoord / 0x100AA2DC | 0x10019725 | 0x1002EB10 | 0x10036C06 |

3DNow! installation checks CPUID feature bits as well as the initial feature query.
Its optional enhanced overrides do not change these four entries. SSE2 also leaves
the scalar trigonometry and translation entries in place.

### SSE register-selection quirk — must not be normalized away

At `Vec2TransformCoord_SSE`, define each packed operation as the actual SSE
operation, subject to MXCSR:

```text
Q = addps(addps(mulps(dx, row1(M)), row4(M)), mulps(dy, row2(M)))
r = rcpps(Q)
u = mulps(mulps(r,r),Q)
refined = subps(addps(r,r),u)   // XMM0; computed but UNUSED
factor = broadcast(u.w)        // XMM1, not refined.w
output.xy = mulps(Q,factor).xy
```

Conclusive bytes:

```text
1002EB44  0F 53 C2       rcpps  xmm0,xmm2
1002EB47  0F 28 C8       movaps xmm1,xmm0
1002EB4A  0F 59 C8       mulps  xmm1,xmm0
1002EB4D  0F 58 C0       addps  xmm0,xmm0
1002EB50  0F 59 CA       mulps  xmm1,xmm2
1002EB53  0F 5C C1       subps  xmm0,xmm1
1002EB56  0F C6 C9 FF    shufps xmm1,xmm1,0xff
1002EB5A  0F 59 D1       mulps  xmm2,xmm1
1002EB5D  0F 13 10       movlps [eax],xmm2
```

Thus, even when W=1, the factor is the binary32 product of the hardware
`RCPPS(1)` approximation with itself, not a proven exact 1. It scales translated
screen coordinates, including the pivot contribution. Do not assert a fixed scale
value without a specified/measured CPU. Unicorn 2.1.4 returns exact 1 for this
reciprocal in the replay and therefore **masks** this hardware-sensitive effect.

### 3DNow! path

`MatrixRotationZ_3DNow` calls `SinCos_3DNow` at `0x1003B1A0`, with radians
in MM0.low and packed cosine/sine returned in MM0. It uses absolute angle,
truncated octant index, split range reduction, packed polynomial operations,
quadrant permutation and sign XOR. It is not `FSINCOS`.
The full instructions and every referenced coefficient/mask are captured;
notable coefficient ranges are `0x100AD8E0..0x100AD908`,
reduction multiplier `0x100AD9D0`, and range bound `0x100AD9D4`.
The bounded sprite angle never reaches that helper's large-angle fallback.

Rotation rows have the same [c,s] / [-s,c] signs. Translation is exact 0/1 and
copied arguments. Transform numerator order is `(dx*row1 + row4) + dy*row2`;
W is handled by `PFRCP`, `PFRCPIT1`, `PFRCPIT2`, then packed multiply.
These instructions and their hardware behavior must be reproduced for bit parity.
Unicorn rejected the first unsupported 3DNow! instruction; no successful 3DNow!
execution is claimed.

### Floating-point scope

Binary32 inputs, temporary stores, matrix entries and outputs are proven.
x87 operations use the current precision/rounding state; SSE uses MXCSR.
Neither `Sprite_Rotate` nor its selected arithmetic helpers establishes a universal
FPU environment. No fused multiply-add is emitted. Exact quarter-turn sine/cosine
values are not special-cased. Zero/multiples of 360 still execute the transform.

`Init3DEx` has native CreateDevice attempts with flags 0x44/0x24
(`0x100086DB/0x100086F9/0x10008738/0x10008751`), but this is not a measurement
of the effective control word after external runtime/driver calls. A managed
`MathF.Sin/Cos`, matrix routine, early-zero return, fixed rounding mode, or
algebraic reassociation cannot be labeled bit-exact from this evidence.

## Source rectangles, stretch, color, mirror, and draw

`Sprite_SetCoor` (`0x10015AF0`) independently writes all X/Y and UV fields:

- Null RECT: UVs (0,0), (0,1), (1,0), (1,1).
- Non-null RECT: U=left/right divided by texture width, V=top/bottom divided by
  texture height, assigned in the same vertex order. Source integers are converted
  to binary32 before x87 division; texture dimensions use unsigned conversion.
  No rectangle clipping/clamping or source-size-derived destination default occurs.
- Destination width/height zero independently select texture width/height at
  texture+0x10/+0x14. Nonzero values stretch to the supplied destination dimensions.
- L=F32(F32(int32 screenX)-0.5f), T=F32(F32(int32 screenY)-0.5f).
  v0=(L,T); v1.x=L; v2.y=T.
  v1.y=F32(F32(int32(heightBits))+T);
  v2.x=F32(F32(int32(widthBits))+L).
- v3 is formed differently: integer X+width and Y+height additions wrap to 32 bits,
  are interpreted by signed `FILD dword`, converted to binary32, then subtract 0.5f.
  See `0x10015C69..0x10015CB2`. Do not replace all right/bottom computations with
  one formula when claiming parity for extreme integer inputs.
- Z/RHW/color/texture are not reset by SetCoor.

Rotation uses the resulting geometry; cropped source dimensions do not relocate
the pivot. Nonuniform stretching occurs before rotation.
`Sprite_SetColor` at `0x10015CC0` packs (A,R,G,B) bytes and at `0x10015D00`
accepts packed ARGB; both write only offsets +0x10,+0x2C,+0x48,+0x64.
`Sprite_Mirror` (`0x10015990`) swaps UV pairs v0<->v2 and v1<->v3 only.

| Function | Geometry and draw interaction |
|---|---|
| Sprite_Prepare, 0x10015D20 | Fixed-function state, sprite FVF 0x144; no geometry edit. |
| Sprite_Draw, 0x10015EE0 | Bind sprite texture; submit sprite pointer, primitive type 5, count 2, stride 28. No rotation/reset. |
| Sprite_DrawEx, 0x10015E70 | Same geometry submission, explicit source/destination blend values. |
| Sprite_DrawListBatch, 0x10016090 | Uses sprite texture but the separate supplied vertex pointer, primitive type 4, explicit primitive count, stride 28. |

Draw mode 0 uses blend states (5,6); mode 1 selects source 2 for the tested alpha
formats or nonopaque v0 alpha, otherwise 3, with destination 2; mode 2 uses (5,6)
and color-write mask 7, restoring 0xFFFFFFFF on both success/failure.
Rotation leaves every field used in that selection unchanged.
SetTexture failure skips drawing; SetTexture/DrawPrimitiveUP HRESULT success is
tested as nonnegative. State-setting errors do not roll geometry back.
Repeated draw calls alone do not accumulate any rotation.
See [02_sprites.md](02_sprites.md) for the full state tables.

## Native caller coverage

Normal and delay-import PE tables of **34** retail EXE/DLL files were parsed with
no parse errors. Only `graphic.dll` imports this export, through `0x100391F0`.
Binary Ninja reports no intra-core references and exactly seven graphic import
references in four functions:

| Caller | Rotate call sites | Argument order after this |
|---|---|---|
| TextureBacked_DrawTemporarySpriteSubRectRotated, 0x10005300 | 0x10005392 | x,y,width,height,sourceRect,packedColor,drawMode,angleDegrees |
| CMyBitmapSpriteFrame_DrawSubRectAt, 0x10012190 | 0x10012213, 0x1001228F | x,y,sourceRect,width,height,colorParameter,drawMode,angleDegrees |
| CMyBitmapSpriteFrame_DrawExSubRectAt, 0x100122C0 | 0x10012347, 0x100123C8 | x,y,sourceRect,width,height,colorParameter,angleDegrees,srcBlend,dstBlend |
| CMyBitmapSpriteFrame_DrawLinearSubRectAt, 0x100123F0 | 0x10012477, 0x100124F8 | x,y,width,height,sourceRect,colorParameter,angleDegrees,srcBlend,dstBlend |

Every site: build coordinates with SetCoor, test ORIGINAL angle for nonzero,
optionally Rotate, then Draw/DrawEx. Therefore wrapper angle 0 skips the helper,
while 360/-360 executes it; these are not safely interchangeable under all
numerical paths. Frame wrappers use persistent sprites but reset geometry per draw.

Frame wrappers set white RGB and low-byte alpha when the FULL colorParameter is
nonzero; zero preserves existing color. Thus, for example, 256 calls SetColor
with alpha byte 0. Temporary-sprite wrapper always writes packed color.

The temporary wrapper uses a 0x74-byte stack sprite and sets texture, XY, UV and
color, but does not call Sprite_Clear or initialize Z/RHW in this body. Its
uninitialized fields are not a safe modern initialization contract.
The rename is intentionally behavior-based; no unproven class identity is asserted.

Frame methods are addressed through vtable data references:
0x10039A3C -> 0x10012190, 0x10039A40 -> 0x100122C0,
0x10039A7C -> 0x100123F0; temporary wrapper has reference 0x10039628.
PrepareSprite (`graphic!0x100136B0`) guards global prepare mode 1.
PrepareLinearSprite (`graphic!0x10013720`) uses mode 10, calls core Prepare,
then writes linear filter states; it does not change rotation math.

This coverage concerns recovered static import/vtable references in these files.
It cannot prove the absence of arbitrarily constructed GetProcAddress lookups or
callers outside the scanned retail files; their use cannot alter the export's
instruction-defined behavior.

## Modern OpenConquer.Rendering contract

Safe implementation requirements from native proof, with no production change made:

1. Accept signed int32 degrees and native signed modulo/conversion. Keep the exact
   degree constant and storage boundaries.
2. Maintain four mutable vertices in the established order. Compute pivot components
   from current v0/v1/v2, then rotate their current XY in place. Preserve other fields.
3. Keep SetCoor/source-UV selection and destination stretch before rotation.
   Keep original-angle-zero suppression in the wrapper layer.
4. Preserve wrapper-specific color and draw/blend argument semantics. A rotated
   sprite does not implicitly rotate an independent batch buffer.
5. For strict numerical compatibility, specify the native math backend and effective
   floating-point environment. Use the applicable scalar/SSE/3DNow instruction
   contract, including the SSE register-selection quirk. A portable semantic
   implementation may intentionally choose a policy, but that choice is not a
   discovered universal native result.
6. Preserve screen-space clockwise direction. A backend's coordinate-system or
   half-pixel adaptation must preserve the resulting geometry/pixel coverage;
   this audit does not certify a particular OpenGL/Vulkan shader mapping.

## Remaining unknowns and verification limits

The export's units, sign convention, component-derived pivot, mutation, accumulation,
geometry/UV/color separation, draw submission and discovered caller ordering are resolved.

The following are **not** resolved into one universal bit/pixel-exact result:

- The target runtime's selected dispatch backend, x87 control word, MXCSR, and
  exact hardware reciprocal/trigonometric results. No original Windows execution
  environment was supplied or measured. The binary explicitly permits multiple paths.
- Physical 3DNow! execution: its code/constants are captured, but this emulator
  cannot execute the instructions. Scalar/SSE emulator outputs do not validate it.
- Physical D3D8 driver/rasterizer and modern framebuffer equivalence. This audit
  proves what is submitted, not an unmeasured hardware framebuffer.
- Arbitrary dynamic/external caller completeness and the temporary wrapper's
  actual uninitialized stack Z/RHW values, neither recoverable as fixed constants.

Do not report "no unknowns" or "100% bit-identical across machines." These limits do
not justify guessing an angle unit, origin or sign: those are proven above.

## Binary Ninja names applied

Names follow the existing `RuntimeDispatch_*`, `j_RuntimeDispatch_*`,
`Vec*_*Scalar` and `Matrix4x4_*` conventions; exports keep their native symbols.

| Address | Verified name |
|---|---|
| 0x10016F60 | RuntimeDispatch_Vec2TransformCoord_InitThunk |
| 0x10016F6D | RuntimeDispatch_Vec2TransformCoord |
| 0x100181B9 | RuntimeDispatch_MatrixTranslation |
| 0x100181E7 | j_RuntimeDispatch_MatrixTranslation |
| 0x100181ED | MatrixTranslation_Scalar |
| 0x100183A4 | MatrixRotationZ_Scalar |
| 0x10019725 | Vec2TransformCoord_Scalar |
| 0x100289C6 | Matrix4x4_Multiply_ScalarOptimized |
| 0x1002EB10 | Vec2TransformCoord_SSE |
| 0x1002EC70 | Matrix4x4_Multiply_SSE |
| 0x1003230A | Matrix4x4_Multiply_3DNow |
| 0x1003260B | MatrixTranslation_3DNow |
| 0x100328E3 | MatrixRotationZ_3DNow |
| 0x10036C06 | Vec2TransformCoord_3DNow |
| 0x1003B1A0 | SinCos_3DNow |
| 0x1001C3F8 | RuntimeDispatch_InitializeMath |
| 0x10028B37 | RuntimeDispatch_InstallScalarOverrides |
| 0x100284B5 | RuntimeDispatch_Install3DNow |
| 0x100282D0 | RuntimeDispatch_InstallSSE2 |
| 0x100281C0 | RuntimeDispatch_InstallSSE |
| 0x1001C344 | RuntimeDispatch_QueryProcessorFeature |
| 0x1001C29F | RuntimeDispatch_QuerySseFeatureBits |
| 0x100283E0 | RuntimeDispatch_QueryMmx3DNowFeatureBits |
| 0x1001C267 | RuntimeDispatch_Has3DNow |
| 0x1001C14D | RuntimeDispatch_ReadDirect3DRegistryValue |
| graphic!0x10005300 | TextureBacked_DrawTemporarySpriteSubRectRotated |

Also named math dispatch data/constants; defined sprite vertex/layout and matrix
fields; applied helper prototypes and named pivot/matrix/local-position variables.
Initial raw captures intentionally retain their historical labels for traceability;
the final named capture and rename manifest record the current database state.
