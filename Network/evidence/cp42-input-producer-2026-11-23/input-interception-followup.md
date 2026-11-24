# Pointer interception and activity hook

## Scope and identity

Static follow-up to hero-command-followup.md, using the same executable digest
recorded in instructions.json. This resolves the immediate viewport callback
and corrects an analysis name. It does not complete OCC #341 or establish a
held-button movement implementation contract.

## Proven viewport behavior

The press and release handlers call 0x6F0E17 with button values 1 and 0.
This function looks up viewport+0x34 in the table at +0x84. A found entry
returns true even if its payload at entry+0x14 is null. With a nonnull payload,
type 5 writes 10 to global 0x96B144 before calling 0x6EE36B. That helper reads
the signed configured code at payload+4: nonnegative codes post through
Conquer_PostMainWindowMessage464(code, button); negative codes do not post.
Both cases remain consumed by the caller. No role command is issued by this
helper. Downstream handling of the posted command remains outside this trace.

Only a lookup miss calls 0x6F0DD1. Its panel-relative bounds at 0x6F09B5 are:

| Expression | Accepted range |
| --- | --- |
| dx = x - (viewport+0x3C value + viewport+0x18 value) | 0 <= dx < viewport+0x14 value |
| dy = y - (viewport+0x44 value + viewport+0x1C value) | viewport+0x58 value <= dy < viewport+0x58 value + viewport+0x10 value |

Inside the bounds, store button at +0x24 and return true. Release also stamps
time at +0x68 and toggles byte +0x5C. Outside, release clears +0x24; press leaves
it unchanged; return false. These are viewport panel writes. They do not prove
that the hero stops, continues, or retargets after release. The earlier release
sample helper at 0x76A7AB still only writes its three globals.

## Proven thread mouse hook

The shell installs callback 0x5B9047 through SetWindowsHookExA with hook ID 7
and the current thread ID. The adjacent hook ID 2 uses callback 0x5B87C7.
The retained installation excerpt covers the actual argument pushes and calls;
the hook callback transcript covers its full function.

| Mouse message | Activity call |
| --- | --- |
| 0x200, mouse move | Only when incoming screen coordinates differ from 0x958684/0x958688; update the cached pair first |
| 0x201/0x203, left down/double-click | Yes |
| 0x204/0x206, right down/double-click | Yes |
| Other messages, including 0x202/0x205 releases | No call through this branch |

All paths forward through CallNextHookEx with handle 0x95809C.

The activity helper at 0x65CDA2 returns if hero+0xF2C is zero; otherwise it
refreshes hero+0xF30. If the hero is idle, it clears idle, sends action 0xA1
with flag zero, and applies the command-type-6 active transition using the
interaction-action status. Its former analysis name
CHero_CancelAutoRunAndClearIdle overstated this body: it has no unconditional
autorun-state clear or movement-path reset. The live name is now
CHero_RecordActivityAndExitIdle. An idle transition can still affect action
state; this finding is not a claim that all activity leaves movement unchanged.

## Analysis and validation

Six narrow function names and their comments were read back through the live
Binary Ninja bridge. input-interception-transcripts.json retains assembly,
high-level IL, and comment readbacks. instructions.json includes the six
assembly transcripts and the hook installation excerpt. verify.py checks their
instruction bytes directly against the original PE image together with the
earlier packet evidence. No database save was requested or performed.

The REA PE import inspection succeeded on the same source image. Import-list
absence is not used to prove absence of dynamic input polling. No runtime
instrumentation or new movement capture is claimed from that inspection.

Windows 11 was visible in Parallels on 2026-11-23. Automated guest clicks and
keyboard attempts produced no visible guest response, while Parallels menus
were accessible. No client launch, login, movement observation, packet capture,
or comparison occurred. The cause of guest input routing is unresolved; a
visible desktop alone is not a successful runtime parity check.

## Resume boundary and client/server lockstep

- Proven: immediate viewport consumption, panel bounds and release bookkeeping,
  thread hook activity messages, narrower idle helper contract.
- Unresolved: repeated/held pointer producer, posted command consumers, all
  viewport field readers, focus loss, correction/transfer interruption, and
  actual client emission cadence against OCS pacing.
- Next static probe: follow the posted command consumer and the viewport field
  readers. Do not identify the UI text sample reader as a movement hold loop.
- Next runtime probe: restore guest input access, verify the running executable
  identity and local test destination, then capture the single-click/hold/drag/
  release and HUD/focus/correction/transfer matrix already recorded in README.md.

No OCC or OCS production code changed. Their existing codecs can represent the
proven packet fields; this does not prove pacing compatibility. Keep OCC #341
open and the dependent movement work gated until the remaining contract is
supported. Startup/render/audio checks must retain their own evidence gates.
