# `GraphicData.dll` — `GameDataSetQuery()` singleton

## Function

`GameDataSetQuery()` (`0x10001000`) returns a process-wide singleton pointer to the primary `GraphicData.dll` interface object.

## Construction behavior

On first call, `GameDataSetQuery()`:

1. allocates `0x3FC` bytes (`operator new(0x3FC)`),
2. calls `GameDataSet_Ctor()` (`0x100010A0`) on that allocation,
3. stores the resulting pointer in a global, and returns it.

On subsequent calls, it returns the previously-created singleton pointer.

If the allocation fails, `GameDataSetQuery()` returns `0`.

