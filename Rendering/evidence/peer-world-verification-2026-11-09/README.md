# Managed peer scene verification, November 9, 2026

Verified OCC main `62988cefed0797435955ad6aacfd597a4d820d39` on macOS arm64,
Apple M4, OpenGL 4.1. The private curated 5517 map-1010 set was mounted
through the production packaged content reader. A temporary verification
program used the existing OpenGL conformance host and the production
remote registry, C3 reader, presentation owner, playback clock, and
world scene depth/draw path. Synthetic role inputs were used inside
the harness. No sockets or original client participated.

- A prepared peer changed the 640×480 scene framebuffer. Removing it
  restored the exact empty framebuffer digest and dropped the resident
  appearance count to zero.
- A canonical selector-0 step selected action 110. A canonical selector-1
  step selected action 120. Four animation frames changed the GPU output
  at the same fixed tile in both cases. Map preparation stayed fixed at
  the same clock to isolate the animation.
- Graphics release cleared the prepared appearance. Re-preparing on the
  live context restored the exact last run-frame digest. This verifies the
  release/re-prepare path on one context.
- Twenty-four selected roles sharing an appearance used one prepared
  renderer. Culling the set restored the empty framebuffer digest.
  This does not measure dense-scene throughput, different-appearance
  budgeting, or actual context loss.

Full framebuffer SHA-256 values are in `gpu-result.txt`. Same-map
two-client visual acceptance, native appearance/motion comparison, and
transfer cleanup remain separate verification gates.

## Mounted-selector provenance correction

The archived `docs/NATIVE_WALK_AND_JUMP_COMMAND_PREPARATION_5517.md`
claims complete-dword equality with 9. The original executable
SHA-256 `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`
has `80 79 0C 09` at `0x740606`, a byte comparison. At `0x74060B`
the equal branch selects modulo 24 and command 0x18. The original
eight-way direction table entry 7 is (+1,+1). The 24-way table entry
23 is (+1,+2). The retained low-byte proof in the
[10005 receive note](../../../Network/15_msgwalk_10005_direction_index_order.md)
supersedes the archived claim.

Constructed discriminator: packed direction 0x17 and selector 0x00000109.
Native receive selects index 23 and command 0x18 for an eligible actor.
OCC main selects index 7 and starts ordinary ground playback.
OCS main `cf42ae01d01e5bae665207df23902ed1be7389df` also tests the full
dword; its current ingress does not reject the upper-byte alias before
the ordinary movement path. This is a static/constructed discriminator.
The normal 0/1 observations and canonical selector-9 policy are separate.
Whether to reject noncanonical selectors at OCS ingress is an explicit
server policy decision. The change must preserve the existing refusal of
mounted moves until riding authority is implemented.
