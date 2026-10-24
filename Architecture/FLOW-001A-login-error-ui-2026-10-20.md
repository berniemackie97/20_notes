# FLOW-001A login error UI audit

Working implementation: OpenConquerClient, branch `feat/flow-001a-live-login-bootstrap`, initial HEAD `e7ed407fe3cd25241ff621ff33b8d9fa6da0e7f1`.

Native authority: existing `Conquer.exe.bndb`, clean executable SHA256 `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`; `start.dat` SHA256 `db4b4550bc4b3fa91b2fd7cc173bb9a6f8109dbc65221e7f0df290610655da20`. Binary Ninja annotations precede this note; no BNDB save.

## Additional instruction-level evidence

- Redirected GameServer connect continuation `0x754D4C`: timeout argument `0x1E` at `0x754DFB`; connect call `0x754E21`; zero result at `0x754E26/28` follows `OnConnectionLost` at `0x754E31`, pushes **StrRes 100100** at `0x754E36`, resolves through GameDataSetQuery virtual `+0x3C` at `0x754E55`, and queues text at `0x754E69`. Exact resource: `Failed to connect to the game server. Please try again later.` This is distinct from AccountServer **10397**, pushed at `0x66D45D` after the two ten-second endpoint attempts fail. The modern signed loopback flow has no BGP fallback.
- Rechecked `0x754011` formatter and `0x5DC783` reset consumer. Code 24 compares at `0x5DC920`, emits `KICKOUT_BANACCOUNT` at `0x5DC92A`; others call ShowLoginErrorText at `0x5DC93F`. The clean SWF has no KICKOUT handler. Preserving the refusal code is necessary even when no errorMC opens.

## SWF contracts applied to this correction

Existing Architecture/11 is authoritative. Additional extracted display-list detail: errorMC sprite274 root depth179, translation(-1,0). Frames1/10 empty; frame2 transparent mask; frames3/4/5 mask alpha multipliers51/103/154; frame6 mask205 plus background265, button272 and field273; frames7/8/9 mask154/103/51 only. **The artwork does not scale or slide during show/hide.** Only the mask fades. The visible mask occupies y90..660 and translates with the root instance; do not stretch it to a full-screen dark rectangle.

Frame6 OK stage bounds(461,415)-(557,441). Field273 stage bounds(369.45,288)-(646.60,401), text origin(371.45,290), Arial14, leading2, left aligned, multiline/wordWrap, plain text, read-only/noSelect. Native device-font rasterization remains host dependent; FFDec bitmap export does not establish Windows Flash/GDI glyph parity.

AVM1 frame6 `okBtn.onRelease` calls parent.play; frame7 plays dialog hide; frame10 resets to1 and releases enterMC blockers. Enter/ERROROK dispatches empty getEnterDown. Escape dispatches the separate quitWindow (sprite287), whose OK calls cmd_assureExit only at frame10. getError restarts frame2 and resets inGameMC to1. Empty account/password messages are SWF constants `Please Enter Your User Name.` and `Please Enter Your Password.` before CMD_ENTERGAME; they must not consume its ten-second guard.

## Proof boundaries under investigation

Follow-up raw checks: `754AD8` pushes 0x100 for strncpy to `[ebp-0x930]` at `754AE3`; `754B1C` clears `[ebp-0x831]`, offset **255**. The final visible 1055 message is at most 255 bytes, truncated before ACP conversion. The native `%d` path in formatter `76C439` tests `0x64` at `76C4BB`, reads the 32-bit argument at `76CB57`, sign-extends with `cdq` at `76CB60`, and tests/negates negative values at `76CB74..78`. High-bit refusal values therefore display signed decimal; the resource key's `%03u` remains unsigned.

Socket-loss dispatcher `CNetMsg__ProcessMsg` at `6DEBA5`: kind `[esi+0x1C]` dispatch at `6DEDEB..6DEDF6`; kind1 reaches `6DEED3` and pushes **100116**, kind2 reaches `6DEEC4` and pushes **10249**. Both resolve via virtual `+0x3C` and enqueue at `6DEF11`. Account read failure must not use the GameServer loss message. Raw captures are under `evidence/flow-001a/`.

Loading quit uses sprite396 at root depth294, translation(0,0), versus idle quit sprite287 depth205 at(-1,0). Their extracted held-frame images match; loading quit artwork and buttons are one stage pixel right of idle quit. The loading variant renders above the account panel; idle quit and errorMC render below it, following the root display list.

Managed seed/DH/read deadlines are separate from native socket connect timeout. No claimed native timeout text may be inferred from the presence of a similarly named resource. Preserve cancellation and bounded protocol handling while resolving their presentation. Windows Flash device-font pixels and non-Windows code-page policy require explicit distinction from proven artwork/timeline behavior.

## Button compositing audit (2026-10-23)

DefineButton2 272 has Up/Over/Down records referencing sprites267/269/271. Seventeen pixels in its exported Up button have fractional alpha, and the Over state changes those pixels. Painting the Over image over a held-frame image which already includes Up therefore blends the boundary twice. The correction exports the entire held sprite separately for each active button state. For extraction only, copy `buttonStateOver` or `buttonStateDown` into `buttonStateUp` on each record of button272 (OK) or282 (Cancel), rebuild a temporary SWF, and export sprite274/287 frame6 with FFDec26.3.0. No original asset or BNDB is modified. The unaffected error sprite in the Cancel variant reproduces the original held crop SHA256 `95db6f8321aa6e65ed8df46ffb65e46bf684eeb8c2062b4cd0c80e3de3e8142d`.

The rendering comparison uses complete 1024x768 exports translated by the root matrix, independent of the runtime crop. It composites straight RGBA over white before checking the production RGB565/RGB555 target, allowing only half a target quantization step plus half an output byte. This is an extracted-artwork check, not Windows Flash rasterization evidence for dynamic text.

## Implementation boundary

The redirected GameServer connect default is corrected from ten to the proven thirty seconds. Existing five-second bounded seed/DH/read ceilings remain managed policy, with phase-specific socket-loss resources on expiry. They are not evidence of native timeout duration equivalence. Stricter managed protocol/local validation failures also use the current phase's loss resource after closing the attempt; no native branch equivalence is claimed for those additional checks. Native Windows Flash7/GDI dynamic text pixels/wrapping remain unverified: the Windows VM start was canceled. No later test pass may be cited as closing that boundary.

Extraction safeguard: after changing the Up flag in a temporary BUTTONRECORD list, remove any record with all four state flags false. Such a record serializes as the SWF zero-byte terminator and otherwise discards the entire following button definition. The content test requires distinct Up/Over/Down output, so blank button exports fail. The corrected exports preserve the selected original character, matrix and color transform.

Account failure timing boundary: `66D472/66D477` passes5000 to Sleep after queueing10397. The managed async flow does not reproduce this blocking sleep or the legacy BGP fallback; its ten-second attempt guard is retained. Exact observed prompt latency for this legacy blocking branch is not claimed.

## Windows Flash7 measurement (2026-10-24, supersedes unavailable-VM status)

The user resumed the Windows11 ARM VM. The offline `10_work/flow001a-flash-probe` host loads the original OCX (SHA25694058fe5343d8d76d313998e1db44a0bedd47184b132fa6c3ace021cb665d703), reports FlashVersion458752, and loads the hash-matching start.dat. Its process is DPI-aware and `IViewObject::Draw` captures a1024x768 DIB directly, avoiding DWM screenshot rescaling. The host's legacy ATL thunk requires process-local DEP compatibility; no system-wide setting is changed. The AtlAxWin creation text must be empty (nonempty text is interpreted as a control/URL). No Conquer executable or login credentials are used.

Runtime field273: `_x=370.45`, `_y=288`, `_width=277.15`, `_height=113` relative to errorMC(-1,0). Empty `textHeight=0`; one-line messages18; two-line36; three-line54. Thus the baseline-to-baseline increment is18, not nominal14+leading2=16. The test string with CRLF, CR and LF produces five lines and height90: Flash normalizes LF to CR but does not collapse CRLF. Original ASCII samples and BMP captures are retained in the probe folder; these observations supersede static-only assumptions about line metrics.
