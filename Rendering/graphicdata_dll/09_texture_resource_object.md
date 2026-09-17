# `GraphicData.dll` — Texture resource object returned by `GameDataSet_RequestTexture`

`Role3D.dll` uses `GraphicData.dll`'s `GameDataSetQuery()` interface to request textures via:

- `secondary = ds->GameDataSet_RequestTexture(textureId, 0, 0)` (vtable offset `+0x18`)

`GameDataSet_RequestTexture` returns either:

- `0` if the texture is not ready (and a load is scheduled), or
- a pointer to a texture resource object when available.

The *minimal* virtual interface of that returned texture object, as proven by `Role3D.dll`.

## `TextureResource_IsReady` (vtable offset `+0x10`)

`Role3D.dll` calls the returned texture object at:

- vtable offset `+0x10` (index `4`) as a readiness check.

Observed usage (effects):

- `if (!secondary || !secondary->TextureResource_IsReady()) return;`

Return value:

- non-zero: ready
- `0`: not ready

No other virtual methods on this object are exercised directly by `Role3D.dll` in the current reverse slice.
