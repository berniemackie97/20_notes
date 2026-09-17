# `GraphicData.dll` — Overview

`GraphicData.dll` provides the client's runtime access layer for "game data" records that drive rendering (models, parts, textures, and related resources).

Other rendering-adjacent modules (notably `Role3D.dll`) do not parse asset files directly. Instead, they call into `GraphicData.dll` via the `GameDataSetQuery()` singleton interface to:

- resolve model IDs to variant IDs (when multiple variants exist),
- request that mesh/model resources are available (and obtain per-model runtime objects),
- request that texture resources are available.

The concrete asset formats and the full `GraphicData.dll` internal data model are documented in this folder as they are deobfuscated.
