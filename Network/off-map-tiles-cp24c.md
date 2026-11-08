# CP2.4c — off-map hero tiles

2026-11-06, OCC base `a1a1dea6` (merged #265). Existing receive, correction,
camera, role-render and depth notes were inventoried first. Clean 5517 in
Conquer.exe.bndb view9, SHA256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Static proof only; no native execution or framebuffer comparison.

| Question | Raw authority | Result |
| --- | --- | --- |
| Walk beyond u16 | `0x740622/628`, `0x7406DB/6DD`; gate setter DWORD `0x71333A` | Signed int32 state, wrapping ADD, no ushort narrowing or overflow rejection. Gate and rendered-role tile fields remain distinct. |
| Off-map cell | `Map_GetTileEntryByCoordinates` `0x61D9C8` | Signed negative/upper-bound failures return NULL. Not a role admission rule. |
| Role registration | `0x67274A..0x672772`; visibility helper `0x61E00D` | Margin2 inclusive screen bounds, no map-cell boundary. Visible off-grid roles can register; distant roles do not. |
| Scenery ordering | `0x61E74B`, `0x635AE6`, getter `0x651875`, footprint `0x644E0E` | Same role/scenery list and terrain adoption for off-grid coordinates; no grid lookup. Signed int32 sums/subtractions wrap, including overlap `a-spanA-b+1<=0`. |
| Tile projection | `0x61D85C..0x61D879` | Wrapping SUB/LEA/SHL before signed divide-by2; not unbounded `tile*32/16`. |
| NULL terrain height | `0x650940..0x650949`, epilogue `0x65097C` | NULL leaves EAX0 and returns terrain delta0 directly. Cached screen point is inverse-projected for this lookup. |
| Actual render consumer | zero locals `0x64F66B/66E`; `0x64F832/835/83E/843/854` | Ordinary idle/walk skips terrain sampling. Actual RoleView elevation argument traced. Arc actions and independent +30C/+3A4 offsets remain separate. |

The existing flat supported-role transform needs no off-map cell fallback. Do
not claim every native vertical term is zero. Motion interpolation, arc actions,
independent offsets and full character presentation remain outside this slice.

Before code: six native function comments extended/read back; no renames needed,
no BNDB save. The transform tail is split into a separate BN function; its
instructions also match the immutable PE. Raw excerpts and readback comments are
in `evidence/off-map-tiles-2026-11-06/`.

Implementation boundary: retain signed wrapping tiles in the world state,
remove the two managed map-grid rejections, preserve ground-extents camera clamp,
and use native screen visibility before the existing role/scenery ordering.
Keep renderer state and rules separate; do not clamp the hero tile to a map edge.
Bootstrap strictness stays CP2.4d. Reply146 and item ownership stay #263/#264.

## Implementation and local validation

Branch `bernie/native-off-map-tiles`: signed model tiles and wrapping walk,
no map-grid rejection, native wrapping projection/depth, margin2 screen-only
role registration and safe absent-role draw range. Scenery preparation remains
unchanged. The supported role matrix stays flat; no height fallback was added.

SDK10.0.403 locked restore, Release0 warnings/errors and 2,933 focused tests pass:
Client1,598 (+14), Content750, Rendering499, Platform86. Three golden tests consume
11 projection, 10 visibility and 6 depth vectors derived independently from raw
instruction semantics. Real Newbie fixture scene tests check unclamped anchors,
clamped camera and recovery. No runtime/framebuffer comparison claimed.
Full formatting and final native/source/ownership self-audit passed. OCC #266
at `0bba2344` is pushed with a clean/synchronized local client branch. CI run1012
passed Linux Quality, Windows and macOS; dependency review passed. Private
retail-content gates were conditionally skipped. PR is ready for Bernie review;
#240 remains open for the CP2.4d bootstrap slice. No BNDB save.
