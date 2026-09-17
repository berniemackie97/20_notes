# DMap Positioned Overlay System

## Overview

The DMap file format contains a post-type3 section of **positioned overlay records** that place visual overlays (animated sprites, puzzle bitmaps) at fixed tile positions within the map. These overlays render as children of map component type 4, which sits between the ground layer (type 1) and weather (type 5) in the render pipeline.

The birth village background (sky/clouds/mountains seen behind floating islands) is a **CGameMap2DPuzzleOverlay** entry referencing `newbiebg.pul`, rendered as a centered puzzle bitmap overlay within a positioned overlay record.

## Native Class Hierarchy

```
CGameMapPositionedOverlayRecord (map component, TypeCode=4)
├── CGameMapAnimatedSpriteOverlay (child entry, TypeCode=3)
│     Uses ANI resource + part name for animated sprites at tile positions
└── CGameMap2DPuzzleOverlay (child entry, TypeCode=8)
      Embeds CMapPuzzleBitmap for puzzle bitmap overlays centered on map
```

## DMap File Layout (Type-4 Section)

Located after: magic → cell grid → exit markers → type-3 subcomponents.

```
int32   outerEntryCount
  For each outer entry:
    int32   insertIndex          // component list insertion position
    int32   recordTypeCode       // always 4 for positioned overlay
    int32   headerInt0           // parallax scale X (percentage, 100=1:1)
    int32   headerInt1           // parallax scale Y (percentage, 100=1:1)
    int32   childEntryCount
      For each child:
        int32   childTypeCode    // 3=animated sprite, 8=puzzle bitmap
        [payload depends on childTypeCode]
```

### Child Type 3 Payload — CGameMapAnimatedSpriteOverlay (0x19C bytes)
```
char[0x104]  resourcePathPrimary      // ANI file path
char[0x80]   resourcePathSecondary    // part/section name within ANI
int32        tileX                    // tile grid X position
int32        tileY                    // tile grid Y position
int32        renderOffsetX            // pixel offset from tile center
int32        renderOffsetY            // pixel offset from tile center
int32        frameIntervalMs          // animation frame interval
int32        rawInt32Field40          // unknown flag/parameter
```

### Child Type 8 Payload — CGameMap2DPuzzleOverlay (0x104 bytes)
```
char[0x104]  puzzleBitmapPath         // relative path to .pul file
```

## PUZZLE File Format (.pul)

```
char[8]      signature                // "PUZZLE\0\0" or "PUZZLE2\0"
char[0x100]  texturePath              // ANI file path for tile textures
int32        tileCountX               // grid width in tiles
int32        tileCountY               // grid height in tiles
uint16[]     puzzleIndexGrid          // tileCountX * tileCountY tile indices (0xFFFF = empty)
--- PUZZLE2 only ---
int32        scrollVelocityX          // horizontal scroll speed
int32        scrollVelocityY          // vertical scroll speed
```

## Native Functions (BNinja Verified)

### CGameMapPositionedOverlayRecord (Container)
| Address    | Function | Description |
|------------|----------|-------------|
| 0x639912   | `CGameMapPositionedOverlayRecord_Ctor` | Constructor, sets vtable to `CGameMapFileRecordType04_VTable` |
| 0x639BD6   | `CGameMapPositionedOverlayRecord_LoadFromMapReader` | Reads headerInt0/headerInt1/childCount, dispatches child entries by type code |
| 0x639B98   | `CGameMapPositionedOverlayRecord_AppendEntry` | Appends child entry to internal linked list |

### CGameMap2DPuzzleOverlay (Puzzle Bitmap Entry)
| Address    | Function | Description |
|------------|----------|-------------|
| 0x64B77A   | `CGameMap2DPuzzleOverlay_Ctor` | Constructor, allocates 0x164-byte object |
| 0x64B8F5   | `CGameMap2DPuzzleOverlay_LoadFromMapReader` | Reads 0x104-byte path, calls `CMapPuzzleBitmap_LoadFromPath` at this+0x20 |
| 0x64B848   | `CGameMap2DPuzzleOverlay_Render` | Centering logic + delegates to `CMapPuzzleBitmap_RenderAtOffset` |
| 0x64B971   | `CGameMap2DPuzzleOverlay_GetEntryTypeCode` | Returns 8 |
| 0x64B975   | `CGameMap2DPuzzleOverlay_TickNoOp` | Empty tick handler |

### CGameMapAnimatedSpriteOverlay (Animated Sprite Entry)
| Address    | Function | Description |
|------------|----------|-------------|
| 0x64B38D   | `CGameMapAnimatedSpriteOverlay_Ctor` | Constructor, allocates 0x44-byte object |
| 0x64B674   | `CGameMapAnimatedSpriteOverlay_LoadFromMapReader` | Reads ANI path + part name + tile position + 6 ints |

### CMapPuzzleBitmap (Shared Tile Renderer)
| Address    | Function | Description |
|------------|----------|-------------|
| 0x639F34   | `CMapPuzzleBitmap_Constructor` | Constructor |
| 0x63A603   | `CMapPuzzleBitmap_LoadFromPath` | Parses PUZZLE/PUZZLE2 format, allocates index grid |
| 0x63A04B   | `CMapPuzzleBitmap_RenderAtOffset` | Tile iteration + ANI query + frame draw (shared by ground + overlay) |
| 0x63A7DC   | `CMapPuzzleBitmap_GetScaledBitmapDimensions` | Returns tileCountX * 0x100, tileCountY * 0x100 |
| 0x63A784   | `CMapPuzzleBitmap_GetPuzzleIndexAtOrFFFF` | Grid bounds check, returns index or 0xFFFF |
| 0x63A800   | `CMapPuzzleBitmap_PreloadVisibleTileResources` | Preloads ANI resources for visible range |
| 0x639E71   | `CMapPuzzleBitmap_LoadFrameIntervalFromInfoIni` | Reads [PuzzleBmp].FrameIntervalMilliSec from ini/Info.ini (default 1000) |

## Render Flow

### CGameMap2DPuzzleOverlay_Render (0x64B848)

Called from `CGameMapPositionedOverlayRecord`'s render loop. Receives render context with `RootScreenX`/`RootScreenY` (parallax-adjusted).

```
1. Early-out if context is null
2. Read RootScreenX, RootScreenY from context
3. Get map tile grid dimensions via CGameMap singleton
4. Compute halfMapWidth  = SignedHalf(tileGridWidth << 6)     // tiles * 64
5. Compute halfMapHeight = SignedHalf(tileGridHeight << 5)    // tiles * 32
6. Call CMapPuzzleBitmap_GetScaledBitmapDimensions → bitmapWidth, bitmapHeight
7. Compute halfBitmapWidth  = SignedHalf(bitmapWidth)
8. Compute halfBitmapHeight = SignedHalf(bitmapHeight)
9. Set frameIndex field (+0x34) = 0
10. Store header scale X/Y from context into +0x158/+0x15C
11. Compute offset:
      offsetX = -(RootScreenX - (halfMapWidth - halfBitmapWidth))
      offsetY = -(RootScreenY - (halfMapHeight - halfBitmapHeight))
12. Call CMapPuzzleBitmap_RenderAtOffset(this+0x20, offsetX, offsetY, 0, 0)
```

The centering formula places the puzzle bitmap at the center of the map's tile grid, adjusted by the parallax-scrolled root screen position.

### Parallax (HeaderInt0 / HeaderInt1)

The `CGameMapPositionedOverlayRecord` component computes `RootScreenX`/`RootScreenY` using:

```
projectionCenterX = ProjectionCenterScreenX + ScreenWidth/2
projectionCenterY = ProjectionCenterScreenY + ScreenHeight/2
tileGridHalfWidth  = SignedHalf(MapTileGridWidth << 6)
tileGridHalfHeight = SignedHalf(MapTileSpan << 5)

RootScreenX = ((HeaderInt0 * (projectionCenterX - tileGridHalfWidth)) / 100)
              + tileGridHalfWidth - ScreenWidth/2
RootScreenY = ((HeaderInt1 * (projectionCenterY - tileGridHalfHeight)) / 100)
              + tileGridHalfHeight - ScreenHeight/2
```

When `HeaderInt0=HeaderInt1=100`, overlay scrolls 1:1 with camera. Lower values create parallax (background scrolls slower).

### Render Order

```
Type 1 (ground tiles + blast traces + entities)
  └── CMapPuzzleBitmap_RenderAtOffset (ground puzzle from DMap header PuzzlePath)
  └── Role render pass (local hero first)
Type 4 (positioned overlay records — inserted at specified index)
  └── For each child entry:
        Type 3: CGameMapAnimatedSpriteOverlay render
        Type 8: CGameMap2DPuzzleOverlay → CMapPuzzleBitmap_RenderAtOffset
Type 5 (weather — currently no-op for kind 20 clouds in 5517)
```

## Object Layout

### CGameMap2DPuzzleOverlay (0x164 bytes)
```
+0x00   vtable*                    // entry vtable (Render, Tick, GetTypeCode)
+0x04   ???
+0x08   ???
+0x0C   ???
+0x10   ???
+0x14   std::string puzzlePath     // stored path
+0x20   CMapPuzzleBitmap           // embedded puzzle bitmap (inline, not pointer)
+0x34   int32 frameIndex           // set to 0 each render
+0x158  int32 headerScaleX         // from render context
+0x15C  int32 headerScaleY         // from render context
```

### CMapPuzzleBitmap (embedded at +0x20)
```
+0x00   char[0x100] texturePath
+0x08   int32 frameCounter
+0x10   uint16* puzzleIndexGrid    // heap-allocated
+0x18   int32 tileCountX
+0x1C   int32 tileCountY
+0x124  int32 tileScale            // always 0x100 (256)
+0x128  int32 scrollVelocityX
+0x12C  int32 scrollVelocityY
+0x138  int32 headerScaleX         // set via parent
+0x13C  int32 headerScaleY
```

## Key Observations

1. **CMapPuzzleBitmap_RenderAtOffset is shared**: The same function draws both the ground puzzle (from DMap header PuzzlePath) and overlay puzzles (from type-8 entries). It performs tile iteration, ANI resource lookup, projection scaling, and frame drawing.

2. **Tile scale constant 0x100**: All puzzle bitmaps use `tileScale = 0x100` (256 pixels per tile before projection). Scaled dimensions = `tileCount * 0x100`.

3. **Visible-range enumeration is hardcoded to 800×600**: `CMapPuzzleBitmap_RenderAtOffset` uses literal `0x320` / `0x258` in its tile-span calculation before projection scaling. A larger 1024×768 backbuffer or resizable host window does not expand the enumerated puzzle tile range; only the later scale/placement stage uses live screen dimensions.

4. **No cloud assets in 5517**: Weather kind 20 cloud code exists but `ani/weather.ani` contains zero Cloud entries. The background is entirely from the puzzle overlay system.

5. **Birth village example**: DMap `map/newbie.dmap` contains one type-4 record with a type-8 child referencing `map/puzzle/newbiebg.pul`, which references `ani/newbiebg.ani` for tile textures. The puzzle dimensions create the sky/mountain/cloud backdrop.

## Managed Parity Mapping

| Native | Managed |
|--------|---------|
| `CGameMapPositionedOverlayRecord` | `CGameMapPositionedOverlayRecordComponentRuntime` |
| `CGameMapAnimatedSpriteOverlay` | `CGameMapAnimatedSpriteOverlayEntryRuntime` |
| `CGameMap2DPuzzleOverlay` | `CGameMap2DPuzzleOverlayEntryRuntime` |
| `CMapPuzzleBitmap` | `CMapPuzzleBitmapRuntime` |
| `CMapPuzzleBitmap_RenderAtOffset` | `CMapPuzzleBitmapRenderRuntime.RenderVisibleTiles` |
| `CMapPuzzleBitmap_LoadFromPath` | `GameMapPuzzleBitmapFile.Parse` |
| `GameMapType4RecordSection.Parse` | DMap type-4 block parser |
