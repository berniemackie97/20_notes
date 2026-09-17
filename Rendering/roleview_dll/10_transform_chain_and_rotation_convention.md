# Transform Chain & Rotation Convention — `RoleView_SharedRenderComposite`

## Source
- RoleView.dll: `RoleView_SharedRenderComposite` (0x100038A9)
- c3_core_dll.dll: `Common_Rotate` (0x10001450), `Common_Scale` (0x100014B0)
- BADimguiCO: `Simple3DObj::Render` (Role3D.cpp line 1759)

## Common_Rotate Implementation (c3_core_dll.dll:0x10001450)

```c
void Common_Rotate(D3DXMATRIX* pOut, float rx, float ry, float rz) {
    D3DXMATRIX temp;
    D3DXMatrixRotationX(&temp, rx);    // temp = RotX(rx)
    D3DXMatrixMultiply(pOut, pOut, &temp);  // pOut = pOut * RotX(rx)
    D3DXMatrixRotationY(&temp, ry);
    D3DXMatrixMultiply(pOut, pOut, &temp);  // pOut = pOut * RotY(ry)
    D3DXMatrixRotationZ(&temp, rz);
    D3DXMatrixMultiply(pOut, pOut, &temp);  // pOut = pOut * RotZ(rz)
}
```

**Key: right-multiply** — each rotation is appended to the existing matrix.

## Common_Scale Implementation (c3_core_dll.dll:0x100014B0)

Scales columns 0, 1, 2 of the existing matrix in-place:
```c
void Common_Scale(D3DXMATRIX* pOut, float sx, float sy, float sz) {
    // Column 0 *= sx, Column 1 *= sy, Column 2 *= sz
    // Equivalent to: pOut = pOut * Scale(sx, sy, sz)
}
```

**Key: right-multiply** — equivalent to appending a scale matrix.

## Non-Project Path (GameCameraIsProject() == 0)

The standard render path builds two matrices:

### Matrix A (model world matrix) — `var_60`

```
matA = Identity
Common_Scale(matA, s, s, s)                            → Scale(s)
Common_Translate(matA, 0, 0, elevation)                → Scale(s) * Translate(0, 0, elev)
Common_Rotate(matA, 0, 0, (dir%360) * DEG2RAD)        → Scale(s) * Translate(0, 0, elev) * RotZ(dir)
```

### Matrix B (position matrix) — `var_a0`

```
matB = Identity
Common_Rotate(matB, 0, field0x14 * DEG2RAD, 0)        → RotY(0)         [field 0x14 = 0 default]
Common_Rotate(matB, field0x10 * DEG2RAD, 0, 0)        → RotY(0) * RotX(oblique)  [field 0x10 = -30]
Common_Translate(matB, screenX, 0, screenY)            → RotX(oblique) * Translate(screenX, 0, screenY)
```

Note: Common_Translate(matrix, x, y, z) adds to _41/_42/_43 (offsets +0x30/+0x34/+0x38).
Field +0x04 goes to world X (screen horizontal), field +0x08 goes to world Z (screen vertical).

### Field sources (RoleView object at `arg1`):
| Offset | Field            | Default Value | Source                                 | Property key |
|-------:|:-----------------|:--------------|:---------------------------------------|:-------------|
| +0x04  | screenX          | from caller   | SharedSetTransformFromCamera arg2      | —            |
| +0x08  | screenY          | from caller   | SharedSetTransformFromCamera arg3      | —            |
| +0x0C  | elevation        | from caller   | SharedSetTransformFromCamera arg4      | —            |
| +0x10  | obliqueAngle (X) | -30           | GetObliqueAngle (graphic.dll), key 0xB | `0xB`        |
| +0x14  | rotYAngle        | 0             | Type1_Ctor, key `0x21`                 | `0x21`       |
| +0x18  | direction (Z)    | from caller   | SharedSetTransformFromCamera arg5, key `0x22` | `0x22` |
| +0x1C  | scale            | 1.0 init      | SharedSetTransformFromCamera arg6      | —            |
| +0xCC  | packed ARGB tint | `0xFFFFFFFF`  | Type1_Ctor, key `0x2F`                 | `0x2F`       |

## Rotation Convention — NO NEGATION NEEDED

### D3DXMatrixRotationX(θ) matrix:
```
| 1    0       0      0 |
| 0    cos(θ)  sin(θ)  0 |
| 0   -sin(θ)  cos(θ)  0 |
| 0    0       0      1 |
```

### System.Numerics.Matrix4x4.CreateRotationX(θ) matrix:
```
| 1    0       0      0 |
| 0    cos(θ)  sin(θ)  0 |
| 0   -sin(θ)  cos(θ)  0 |
| 0    0       0      1 |
```

**These are IDENTICAL.** Both produce the exact same matrix for the same angle θ.

### Why transpose=false works without negation:

D3D8 uses row-vector convention: `v_out = v_row * M`
GLSL uses column-vector convention: `v_out = M * v_col`

When we upload row-major System.Numerics data with `glUniformMatrix4fv(transpose=false)`,
OpenGL interprets it as column-major, effectively giving the shader `M^T`.

The shader computes `M^T * v_col` which equals `(v_row * M)^T` — same spatial result.

**Therefore: compose matrices in the same order as D3D, pass the same angles. No negation.**

## BADimguiCO Confirmation

BADimguiCO passes angles directly without negation:
```cpp
// Direction: no negation
CallCommonRotate(&matWorld, 0.0f, 0.0f, (float)dirAngle * DEG2RAD);

// Oblique: no negation (obliqueAngle already stored as -30)
CallCommonRotate(&matTrans, (float)obliqueAngle * DEG2RAD, 0.0f, 0.0f);
```

## Bugs Fixed in Our Code

### Bug 1: Angle negation (WRONG → REMOVED)

Previous code negated both angles:
```csharp
float dirRad = -directionDegrees * (MathF.PI / 180f);       // ← WRONG
float obliqueRad = -obliqueAngleDegrees * (MathF.PI / 180f); // ← WRONG
```

Fix: pass angles directly (same sign as native):
```csharp
float dirRad = directionDegrees * (MathF.PI / 180f);
float obliqueRad = obliqueAngleDegrees * (MathF.PI / 180f);
```

### Bug 2: Matrix A multiplication order

Previous: `Scale * RotZ * Translate` (wrong for non-zero elevation)
Native:   `Scale * Translate * RotZ`
Fix: reorder to match native.

### Bug 3: Doc field name swap (corrected)

Doc originally labeled +0x04 as "screenY" and +0x08 as "screenX".
BNinja verification: `Common_Translate(matB, field+0x04, 0, field+0x08)` adds +0x04 to _41 (X)
and +0x08 to _43 (Z). Since world X = screen horizontal and world Z = screen vertical,
+0x04 is screenX and +0x08 is screenY. Code was already correct; doc fixed.

## Camera Near Plane — Verified Correct at 1.0f

`GameCameraCreate` (graphic.dll 0x1000EDB0) sets `g_GameCameraOrthographicNearPlane = 0x3f800000` = **1.0f**.
BADimguiCO uses near=0.0f — this is incorrect. Native binary confirmed: near=1.0, far=10000.0.
