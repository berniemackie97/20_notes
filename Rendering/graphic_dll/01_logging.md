# `graphic.dll` — Logging (`debug.log` / `./debug/YYYY_M_D.log`)

This document describes the logging behavior implemented inside `graphic.dll`.

## Entry points
- `Gfx_Logf` (0x10037250): `vsprintf` into a stack buffer then forwards to `Gfx_LogToDatedDebugFile`.
- `Gfx_LogToDatedDebugFile` (0x100370D0): writes formatted lines to a dated log file under `./debug/`.

## File output
`Gfx_LogToDatedDebugFile`:
- builds `./debug/YYYY_M_D.log` using `localtime(time())`
- calls `mkdir("./debug")` (path is the global `Path`)
- opens the file in append mode (`"a"`)
- writes: `"<formatted message> -- <ctime string>"`

## Notes
- Logging is conditional only on `Format != NULL` (no level filtering observed in this function).
- Formatting uses `vsprintf` (no bounds checks).

