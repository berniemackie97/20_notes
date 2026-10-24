# Auth string evidence — 2026-10-18

Read [the findings](../../Native-auth-string-validation-2026-10-18.md) first.
This directory is evidence for an investigation, not client/server implementation.

- `native/`: disassembly captured from the user's existing Binary Ninja databases.
  Unsuffixed files are Conquer.exe; `graphic-` and `c3-` identify the two DLLs.
  Captures precede this slice's new annotations/renames, so unnamed callees can
  appear by address. Existing comments are historical context; new findings take
  precedence where they explicitly qualify an old broad statement.
- `provenance.json`: module/asset and input-archive hashes.
- `verify_capture_bytes.py`, `raw-byte-verification.json`: instruction-by-instruction comparison of capture
  bytes with the clean PE images. Zero differences is verified; analysis symbols
  and historical comments are not claimed to be original native source symbols.
  Run `python verify_capture_bytes.py /path/to/clean/5517` to repeat the check.
- `bn-annotations.json`: nine applied/read-back comments and six applied/read-back
  function names. No database save was requested or performed.
- `replay_string_reader.py`, `string-reader-replay.json`: isolated execution of
  captured retail reader bytes,18 named cases plus1024 boundary checks. Run
  `python replay_string_reader.py` with `unicorn==2.1.4` installed. Only memcpy
  and memset are hooked. The bytes beyond packet storage are a synthetic sentinel;
  this is not full-client execution or a retail traffic capture.
- `codepage_probe.c`, `codepage-probe-output.txt`: API-only Windows conversion
  probe compiled for i686 and run in CrossOver Preview's Wine bottle `test`.
  ACP reported1252. Explicit1252/936/65001 probes do not change the machine's
  locale. The result corroborates platform behavior; it does not establish exact
  behavior for every historical Windows version, the native game, or its fonts.
  Runtime package: CrossOver Preview20251216, product26.0.0.40000,
  build `cxpreview-20251216-rc1`.
- `managed-pr134/`: read-only source snapshots used for comparison at
  `cf2470a2a47e44c0f696454446df2922bfd0d803` in berniemackie97/OpenConquerClient.
  N and O documents plus1004/1006/2078 readers identify the exact stricter checks.
- `pr134.json`: PR identity, head and changed-file metadata at retrieval.
- `data-anchors.json`: directly read PE data supporting import/literal references.

All source material in the supplied `sources/` directory remained read-only.
The updated archive was built by preserving its entries and adding/revising only
the focused notes/evidence. The external package verification JSON lists archive
hashes and every changed/new path. Tool installations, compiler libraries,
executables and unrelated prior research are not bundled.

Platform corroboration:
[MultiByteToWideChar](https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar),
[Windows1252 table](https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit1252.txt).
