# Motion sampling verification for Studio asset design

Date: 2026-11-02. Existing Binary Ninja view 21, `C3_CORE_DLL.dll.bndb`.
Original input: `00_clean/clean/5517/C3_CORE_DLL.dll`, 757760 bytes.
SHA-256: `f5bbe1d408320de33c17422b58576d3e883fa6f93830fe159ac27f3396551a7b`.

- `sample.asm.txt`: full `C3Motion_GetBoneMatrixAtFrame` disassembly returned by the live MCP.
- `blend.asm.txt`: full `C3MotionTracker_GetBlendedBoneMatrixAtFrame` disassembly returned by the live MCP.
- `verification.json`: PE-mapped byte comparison of every captured instruction against the original DLL,
  plus exact function-range hashes. Existing annotation text in the captures is context, not independent proof.

The new signed-comparison and missing-local-empty-key-guard observations are recorded in
`../../c3_core_dll/13_motion_sampling_and_blend.md`. The matrix-lerp contract was reconfirmed.
No dynamic execution, renderer comparison, file-format completeness, or bone hierarchy was proved.
No input binary or BNDB was written. Address comments were added only to the open analysis view.
