# `graphic.dll` — effect file loading (`C3Effect_LoadFromResource`)

Verified effect C3 chunk loading behaviour in:

- `C3Effect_LoadFromResource` (`0x100011A0`)

BNinja evidence source: `graphic.dll.bndb`.

## Scope

`C3Effect_LoadFromResource(this, effectPath)` opens a C3 effect resource stream,
scans chunk headers, and dispatches recognized chunks to `c3_core_dll.dll` loaders.

The function also enforces resource-limit gates and wires loaded `SMOT` data into
shape objects for runtime transform selection.

## Chunk stream contract

The loader:

1. Opens `effectPath` via `Common_OpenRes`.
2. Seeks past a 16-byte file header (`Common_SeekRes(stream, 0x10, SEEK_CUR)`).
3. Loops while `Common_GetSeek(stream) < fileStartOffset + fileSize`.
4. Reads chunk headers with `Common_GetChunk(stream, &chunkHeader)`.
5. For unrecognized chunks, seeks by declared payload size.

Chunk header interpretation:

- `magic[0..2]`: 3-byte tag prefix
- `type`: 4th byte (treated as tag/type discriminator)

## Verified chunk dispatches

- `MOTI` (`'M','O','T','I'`) -> `C3Motion_LoadFromStream`
- `SMOT` (`'S','M','O','T'`) -> `C3SimpleMotion_LoadFromStream`
- `SHAP` (`'S','H','A','P'`) -> `C3Shape_LoadFromStream`
- `PTCL` (`'P','T','C','L'`) -> `C3ParticleType1_LoadFromStream`
- `PTCX` (`'P','T','C','X'`) -> `C3ParticleType2_LoadFromStream`
- `PTC3` (`'P','T','C','3'`) -> `C3ParticleType3_LoadFromStream`
- `PHY*` variants (prefix `'P','H','Y'`, type-based branches) -> `Phy_Load`

For each recognized slot, existing objects are unloaded before reloading.

### Typed parser mapping (implementation contract)

The new cross-platform parser (`Conquer.Assets.Mesh.C3EffectContainerReader`) maps
native dispatch tags to typed chunk kinds:

- `SHAP` -> `C3EffectChunkKind.Shape` (`ShapeChunkDescriptor`)
- `MOTI` -> `C3EffectChunkKind.Motion` (`MotionChunkDescriptor`)
- `SMOT` -> `C3EffectChunkKind.SimpleMotion` (`SimpleMotionChunkDescriptor`)
- `PTCL` -> `C3EffectChunkKind.Particle` (`ParticleChunkDescriptor`)
- `PTCX` -> `C3EffectChunkKind.Particle2` (`ParticleChunkDescriptor`)
- `PTC3` -> `C3EffectChunkKind.Particle3` (`ParticleChunkDescriptor`)
- `PHY ` -> `C3EffectChunkKind.PhysicsStaticSparse` (`PhyType.StaticSparse`)
- `PHY2` -> `C3EffectChunkKind.PhysicsSkinnedSparse` (`PhyType.SkinnedSparse`)
- `PHY3` -> `C3EffectChunkKind.PhysicsSkinnedPacked` (`PhyType.SkinnedPacked`)
- `PHY4` -> `C3EffectChunkKind.PhysicsStaticPacked` (`PhyType.StaticPacked`)
- anything else -> `C3EffectChunkKind.Unknown` (still preserved in ordered chunk list)

Chunk payload offsets are interpreted exactly as:

- `payload_offset = chunk_header_offset + 8`
- `payload_end = payload_offset + declared_size`

and bounds are validated against file length before advancing.

### Managed runtime slot loader mapping (verified parity slice, 2026-03-04)

`Conquer.Assets` now includes a dedicated effect runtime slot loader that mirrors
`C3Effect_LoadFromResource` chunk-loop behavior and post-load index binding:

- loader: `10_work/src/Conquer.Assets/Mesh/C3EffectRuntimeResourceSetReader.cs`
- runtime slot model: `10_work/src/Conquer.Assets/Mesh/C3EffectRuntimeResourceSet.cs`
- raw frame-field runtime (`C3Effect_SetFrameIndex` parity):
  `10_work/src/Conquer.Assets/Mesh/C3EffectFrameRoutingRuntime.cs`
- setter-path frame runtime (`SetParticle/SetPhy/Get*/SetAll` parity):
  `10_work/src/Conquer.Assets/Mesh/C3EffectResourceFrameRuntime.cs`

Implemented parity points:

1. scan chunks in stream order and decode recognized tags only;
2. use per-type slot caps of `32` (`0x20`) and stop scanning when a cap is reached;
3. stop scanning on first recognized chunk decode failure (matching native `break` paths);
4. apply post-load index bindings:
   - `boundSimpleMotionSlots[i] = simpleMotionSlots[i]` for `i < shapeCount`,
   - `boundMotionSlots[i] = motionSlots[i]` for `i < phyCount`;
5. mirror `C3Effect_SetFrameIndex` raw frame-field fan-out in
   `C3EffectFrameRoutingRuntime`;
6. mirror `C3Effect_SetParticleFrameByIndex`,
   `C3Effect_SetPhyFrameByIndex`,
   `C3Effect_GetParticleFrameCountByIndex`,
   `C3Effect_GetPhyFrameCountByIndex`,
   `C3Effect_GetMaxTimelineFrame`, and
   `C3Effect_SetAllResourceFrames`
   in `C3EffectResourceFrameRuntime`.

Tests:

- `10_work/tests/Conquer.Tests/Assets/Mesh/C3EffectRuntimeResourceSetReaderTests.cs`
  covers stop-on-failure, cap-stop, real-client slot binding, and raw frame fan-out behavior.
- `10_work/tests/Conquer.Tests/Assets/Mesh/C3EffectResourceFrameRuntimeTests.cs`
  covers setter-path normalization and timeline-frame helper contracts.

## `SMOT` wiring and runtime effect

`SMOT` payloads are loaded into an internal simple-motion slot array at `this + 0x88`
(`C3SMotion*` entries).

After chunk loading completes, the loader applies per-shape binding:

- for each loaded shape index `i`:
  - `shape[i]->simpleMotion = this->simpleMotionSlots[i]`

Runtime use is in `C3Shape_Draw` (`c3_core_dll.dll`):

- selects matrix as `simpleMotion->frameMatrices[simpleMotion->currentFrameIndex]`.

## Verified `C3Effect` slot layout used by loader

Within `C3Effect_LoadFromResource`, verified slot/count offsets are:

- `+0x004`: `shapeCount`
- `+0x008`: `shapeSlots[32]` (`C3Shape*`)
- `+0x088`: `simpleMotionSlots[32]` (`C3SMotion*`)
- `+0x108`: `particleCount`
- `+0x10C`: `particleSlots[32]` (`C3Ptcl*`)
- `+0x18C`: `particle2Count`
- `+0x190`: `particle2Slots[32]` (`C3Ptcl2*`)
- `+0x210`: `particle3Count`
- `+0x214`: `particle3Slots[32]` (`C3Ptcl3*`)
- `+0x294`: `phyCount`
- `+0x298`: `phySlots[32]` (`C3Phy*`)
- `+0x318`: `motionSlots[32]` (`C3Motion*`)

Post-load wiring sets `phySlots[i]->motion = motionSlots[i]` and
`shapeSlots[i]->simpleMotion = simpleMotionSlots[i]`.

## Runtime frame-index routing (verified, BNinja refresh 2026-03-04)

`C3Effect_ApplyFrameIndexFromMotionTracker` (`0x100028A0`):
- if tracker pointer is non-null, calls tracker vtable `+0x10`
- if returned frame pointer is null, logs debug failure
- otherwise calls `this->vtable[+0x14](*framePtr)` (resolved to `C3Effect_SetFrameIndex`)

`C3Effect_SetFrameIndex` (`0x100028E0`):
- fan-outs raw `frameIndex` writes to loaded resource objects:
  - shape slot object `+0x08`
  - particle/particle2/particle3 slot object `+0x04`
  - phy slot object `+0x20`
- this method writes frame state fields only; it does not directly call `Phy_SetFrame`.

`C3Effect_SetPhyFrameByIndex` (`0x10002EC0`):
- single-index bridge to core PHY API:
  - `Phy_SetFrame(phySlots[index], frameIndex)` (`call ... ?Phy_SetFrame` at `0x10002ED1`)

`C3Effect_SetParticleFrameByIndex` (`0x10002E80`):
- single-index bridge to core particle API (`PTCL` family):
  - `Ptcl_SetFrame(particleSlots[index], frameIndex)` (`call ... ?Ptcl_SetFrame` at `0x10002E9A`)

`C3Effect_GetParticleFrameCountByIndex` (`0x10002EA0`):
- returns `particleSlots[index]->timelineFrameCount` (`+0x18`).

`C3Effect_GetPhyFrameCountByIndex` (`0x10002EE0`, renamed in BNinja on 2026-03-04):
- returns `phySlots[index]->primaryMotion->frameCount` (`motion + 0x04`).

`C3Effect_SetAllResourceFrames` (`0x10002FE0`):
- calls `Ptcl_SetFrame` for particle slots
- calls `Phy_SetFrame` for all loaded PHY slots (`call ... ?Phy_SetFrame` at `0x1000309B`)
- calls `Shape_SetFrame` for all loaded shape slots

`C3Effect_GetMaxTimelineFrame` (`0x10002F00`):
- computes max over:
  - `PTCL/PTCX/PTC3` timeline frame counts (`slot + 0x18`),
  - `PHY` bound primary-motion frame counts (`motion + 0x04`, null motion -> 0),
  - `SHAP` bound simple-motion frame counts (`simpleMotion + 0x00`, null simple-motion -> 0).

Parity clarification (2026-03-04 correction):
- `C3Effect_SetAllResourceFrames` is **not** equivalent to raw `C3Effect_SetFrameIndex` writes:
  - particle path normalizes via `Ptcl_SetFrame` modulo `timelineFrameCount`,
  - phy path normalizes via `Phy_SetFrame` modulo motion `frameCount`,
  - shape path writes bound `simpleMotion->currentFrameIndex` via `Shape_SetFrame`.
- Managed code now models this setter path in `C3EffectResourceFrameRuntime`.

## Verified limits and guards

- file-size gate via `g_ResLimitInterfacePtr` before chunk scan.
- bone/keyframe limits validated for loaded `MOTI` motions.
- particle count/frame limits validated for loaded particle chunks.
- `PTC3` loader enforces per-record `sampleCount <= vertexBufferQuadCapacity`.
- `C3Shape_LoadFromStream` is invoked as `C3Shape_LoadFromStream(..., forceTwoPointSets = 0, stream)`.
- `C3Shape_LoadFromStream` failure logs `Bad Shape Data in Effect [%s]` and aborts.

## Deob names applied in BNinja (`graphic.dll.bndb`)

Relevant helper/vtable methods were renamed from `sub_*` to descriptive names:

- `C3Effect_DeletingDestructor`, `C3Effect_Destructor`, `C3Effect_ReleaseInstance`
- `C3Effect_DrawShapeWithMotionBlend`, `C3Effect_SetPhyColorArgb`
- `C3Effect_ApplyFrameIndexFromMotionTracker`, `C3Effect_SetFrameIndex`
- `C3Effect_TranslateWorldMatrix`, `C3Effect_RotateWorldMatrix`, `C3Effect_ScaleWorldMatrix`
- `C3Effect_SetWorldMatrix`, `C3Effect_GetWorldMatrix`
- `C3Effect_SetParticleFrameByIndex`, `C3Effect_GetParticleFrameCountByIndex`
- `C3Effect_SetPhyFrameByIndex`, `C3Effect_GetPhyFrameCountByIndex`
- `C3Effect_GetMaxTimelineFrame`, `C3Effect_SetAllResourceFrames`
- `C3Effect_ExportShapeInfoToBuffer`, `C3Effect_ImportShapeInfoFromBuffer`

## Real-file evidence (clean 5517 client)

Verified `SMOT`-containing effect files include:

- `00_clean/clean/5517/c3/effect/arrow/500029/1.C3`
- `00_clean/clean/5517/c3/effect/weapon/601129/4.C3`
- `00_clean/clean/5517/c3/effect/skill/meteor/1/1.C3`
