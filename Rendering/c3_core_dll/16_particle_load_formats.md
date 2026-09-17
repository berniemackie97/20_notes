# `c3_core_dll.dll` — particle load formats (`PTCL` / `PTCX` / `PTC3`)

Verified particle payload decode behaviour in:

- `C3ParticleType1_LoadFromStream` (`0x10010C30`) for `PTCL`
- `C3ParticleType2_LoadFromStream` (`0x10010E10`) for `PTCX`
- `C3ParticleType3_LoadFromStream` (`0x10011010`) for `PTC3`

Verified in BNinja (`C3_CORE_DLL.dll.bndb`) with deobfuscated names/types.

## Function set and roles

- `C3ParticleType1_Reset` / `C3ParticleType2_Reset` / `C3ParticleType3_Reset`
- `C3ParticleType1_LoadFromStream` / `C3ParticleType2_LoadFromStream` / `C3ParticleType3_LoadFromStream`
- `C3ParticleType1_Unload` / `C3ParticleType2_Unload`
- `C3ParticleType12_SetFrameIndex`
- `C3ParticleType12_AdvanceFrame`
- `C3ParticleType12_SetTextureId`

`graphic.dll` dispatches chunk tags to these loaders from `C3Effect_LoadFromResource`.

## Verified runtime layouts used by loaders

### `C3ParticleType1` (`PTCL`)

- `+0x00` `particleVertexBuffer`
- `+0x04` `textureId`
- `+0x08` `vertexBufferQuadCapacity`
- `+0x0C` `uvFrameDivisor`
- `+0x10` `timelineFrames` (`C3ParticleTimelineFrameType1*`)
- `+0x14` `currentFrameIndex`
- `+0x18` `timelineFrameCount`

`C3ParticleTimelineFrameType1` (`0x50` bytes):

- `+0x00` `sampleCount`
- `+0x04` `samplePositions` (`D3DXVECTOR3*`)
- `+0x08` `sampleValuesA` (`uint32*`)
- `+0x0C` `sampleValuesB` (`uint32*`)
- `+0x10` `localTransform` (`D3DXMATRIX`, 64 bytes)

### `C3ParticleType2` (`PTCX`)

Extends type1 with:

- `+0x1C` `transformCache`

`C3ParticleTimelineFrameType2` (`0x54` bytes):

- `+0x00` `sampleCount`
- `+0x04` `sampleIndices16` (`uint16*`)
- `+0x08` `samplePositions` (`D3DXVECTOR3*`)
- `+0x0C` `sampleValuesA` (`uint32*`)
- `+0x10` `sampleValuesB` (`uint32*`)
- `+0x14` `localTransform` (`D3DXMATRIX`, 64 bytes)

### `C3ParticleType3` (`PTC3`)

Extends type2 with additional header fields:

- `+0x20` `transformMode` (`uint32`)
- `+0x24` `useAlternateTransformBasis` (`byte`)
- `+0x28` `rotationAngleBase` (float bits)
- `+0x2C` `rotationAngleRandomRange` (float bits)
- `+0x30` `frameEnvelopeStart` (float bits)
- `+0x34` `frameEnvelopeMiddle` (float bits)
- `+0x38` `frameEnvelopeEnd` (float bits)
- `+0x3C` `frameEnvelopeRampInEndFrame` (`uint32`)
- `+0x40` `frameEnvelopeRampOutStartFrame` (`uint32`)
- `+0x44` `sampleEnvelopeStart` (float bits)
- `+0x48` `sampleEnvelopeMiddle` (float bits)
- `+0x4C` `sampleEnvelopeEnd` (float bits)
- `+0x50` `sampleEnvelopeRampInEnd` (float bits)
- `+0x54` `sampleEnvelopeRampOutStart` (float bits)
- `+0x58..+0x60` gravity vector (`C3ParticleType3_SetGravityVector`)
- `+0x64..+0x6C` external speed vector (`C3ParticleType3_SetExternalSpeedVector`)

## Stream format (`PTCL` / `PTCX` / `PTC3` payload body)

All three loaders share this prefix:

1. `uint32 metadataLengthA`
2. `metadataLengthA` bytes (seek/skip only)
3. `uint32 metadataLengthB`
4. `metadataLengthB` bytes (seek/skip only)
5. `uint32 uvFrameDivisor`

Then:

- `PTCL`: reads `uint32 vertexBufferQuadCapacity`
- `PTCX`: reads `uint32 vertexBufferQuadCapacity`
- `PTC3`: reads:
  - `byte transformModeByte` (stored at `+0x20` as zero-extended `uint32`)
  - `byte useAlternateTransformBasis`
  - 12 dwords into `+0x28..+0x54`
  - `uint32 vertexBufferQuadCapacity`

All three then:

6. create particle vertex buffer with byte size `vertexBufferQuadCapacity * 0x60`
7. `uint32 timelineFrameCount`
8. decode `timelineFrameCount` timeline records

### Timeline record decode

`PTCL` record (`C3ParticleTimelineFrameType1`):

1. `uint32 sampleCount`
2. if `sampleCount > 0`:
   - `D3DXVECTOR3[sampleCount]`
   - `uint32[sampleCount]` (`sampleValuesA`)
   - `uint32[sampleCount]` (`sampleValuesB`)
   - `D3DXMATRIX` (`localTransform`)
3. if `sampleCount == 0`, all record pointers remain null and no matrix bytes are read.

`PTCX` / `PTC3` record (`C3ParticleTimelineFrameType2`):

1. `uint32 sampleCount`
2. if `sampleCount > 0`:
   - `uint16[sampleCount]` (`sampleIndices16`)
   - `D3DXVECTOR3[sampleCount]`
   - `uint32[sampleCount]` (`sampleValuesA`)
   - `uint32[sampleCount]` (`sampleValuesB`)
   - `D3DXMATRIX` (`localTransform`)
3. if `sampleCount == 0`, all record pointers remain null and no matrix bytes are read.

## Verified guards and differences

- `PTC3` enforces `sampleCount <= vertexBufferQuadCapacity` for each timeline record.
  - on violation, emits `Bad Ptcl Resource!\n`, unloads, and fails.
- `PTCL` and `PTCX` do not enforce that per-record guard in their load path.
- All three increment global `g_nPtclCount` on success.

## Real-file evidence (clean 5517 client)

Observed tags in real effect files:

- `PTCL`: `00_clean/clean/5517/c3/effect/LuckyGuy/3.C3`
- `PTCX`: `00_clean/clean/5517/c3/effect/weapon/800520/5.C3`
- `PTC3`: `00_clean/clean/5517/c3/effect/magic/magic_400029_beat/1.c3`
