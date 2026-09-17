# `TargetBmp*` and `MyBitmap*` Objects (Observed via EXE Call-Sites)
Object interfaces the EXE uses for offscreen render targets and drawables created through `graphic.dll`, reconstructed from its call sites.

Key imports:
- `TargetBmpCreate(int)` / `TargetBmpCreateEx(int)`
- `MyBitmapCreateEx(int)`

We infer methods from vtable offset usage at call-sites.

## TargetBmp objects (from `TargetBmpCreate*`)

### Creation
`Exe_TargetBmp_CreateAndInit` (`0x72CAA8`):
```c
target = TargetBmpCreateEx(256);
if (target) {
  handle = target->vtable[6](target); // +0x18 (24)
  if (handle) {
    drawable = MyBitmapCreateEx(handle);
  }
}
```

So TargetBmp has a method at:
- `vtable + 0x18` (24): returns an `int` handle that is accepted by `MyBitmapCreateEx`.

Verified additional use from the ground/entity-layer non-`.pul` terrain-cache path:
- `targetBmp->vtable + 0x04` is used as the begin-scene / bind-render-target gate before the cache filler draws into it
- `targetBmp->vtable + 0x08` is used as the matching end-scene / restore-render-target call after the filler completes

### Resize / Init?
`Exe_TargetBmp_CreateSeveralFixedSizes` (`0x72CADC`) creates multiple target bitmaps (128/256/512) and calls:
```c
target->vtable[9](target); // +0x24 (36)
```
on each.

So TargetBmp has a method at:
- `vtable + 0x24` (36): likely "Finalize/Prepare/Resize/InitRT" for the offscreen surface.

**Gap:** determine whether +36 depends on global device state and whether it must be called after reset.

## MyBitmap objects (from `MyBitmapCreateEx`)

### Lifecycle
`CRole__Render3D` destroys an existing object at `role + 267` via `vtable[0]`, consistent with destructor/release semantics.

### Draw methods (vtable + 0x04 and +0x08)
`CRole__Render3D` uses `role->bitmap` (from `MyBitmapCreateEx(...)`) and calls:

**(A) simple draw**
```c
bitmap->vtable[1](bitmap, x, y, 0, 0); // +0x04
```

**(B) draw with sizing / source rect**
```c
bitmap->vtable[2](bitmap, x, y, 0, w, h, 0, 0, 0); // +0x08
```

The branch depends on whether the computed scale `v58` equals the base size `v56`, suggesting:
- `+0x04` draws at natural size (no scaling)
- `+0x08` draws with explicit target size or cropping parameters

**Gap:** interpret the extra zeros: likely `srcX/srcY/flags` or blend parameters.

## Notes on observed usage
The EXE treats `graphic.dll` as a renderer that provides:
- offscreen render targets (TargetBmp)
- drawable bitmaps/sprites (MyBitmap)
- methods to draw those bitmaps with/without scaling
The "device lost/reset" behavior implies these objects are tightly coupled to device lifetime and may be invalidated/recreated across resets.
