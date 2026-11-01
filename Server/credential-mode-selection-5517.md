# Retail 5517 credential mode selection — native gap closure

Verified 2026-10-30 using Binary Ninja MCP and the existing `Conquer.exe.bndb` (view 8).
Input executable SHA-256: `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Baseline: all 534 files in `20_notes.zip` matched the live notes before this slice; archive SHA-256
`c950f088daac9c824c6e0c57ec2721a411c6e7f25f5ed326bee1c67a0e59ef95`.
This note adds mode-selection evidence only. The established RC5/keypad algorithms and live login proof are unchanged.

## Result

**Ordinary retail password entry cannot select raw encoding through the branch near `0x4ADDFF`.**
The old [credential-envelope note](login-credential-envelope.md) conflated two different stack arguments.
The password call passes a literal encoding flag of **1**, regardless of protection state or selected charge type.
Raw input remains reachable for account and other non-password fields in the shared input helper.

## Exact ABI and complete direct-caller provenance

`CGameInputString_ProcessFrameInputAndSelection` starts at `0x59E59F`; ECX holds the input object.
Its five stack arguments after the exception prologue are:

| Stack slot | Meaning | Evidence |
|---|---|---|
| `[ebp+8]` | selection-start pointer | `0x59E5DD`, `0x59E5E5` |
| `[ebp+0xC]` | selection-end pointer | `0x59E62D..0x59E63A` |
| byte `[ebp+0x10]` | **encodeCredential** | `0x59EC1D`, `0x59EC41` |
| byte `[ebp+0x14]` | **softKeyOnly input policy** | `0x59E5B2` |
| `[ebp+0x18]` | account-name pointer for encoding | `0x59EC27`, `0x59EC47` |

The fourth slot is reused for the input object's keyboard-state pointer at `0x59E5D5`.
It must not be mistaken for a persistent encoding flag. The third slot has no store or address escape
in the complete recovered helper body. Its value comes directly from the caller's push.

| Unique call site | Context | Third argument: encoding | Fourth argument: policy |
|---|---|---:|---|
| `0x4ADA53` | host not visible/pending | 0 | `dlg+0x158` |
| `0x4ADAD9` | focused host, callback code 1013, 1001, or 1003 | 0 | `dlg+0x158` |
| `0x4ADC0B` | callback 1000, `VAR_FOCUS=1`, account | 0 | `dlg+0x158` |
| `0x4ADE26` | callback 1000, `VAR_FOCUS=2`, password | **1** | predicate below |
| `0x4AE059` | callback 1000, `VAR_FOCUS=3`, third field | 0 | 0 |
| `0x4AE21F` | callback 1000, other `VAR_FOCUS` | 0 | `dlg+0x158` |

The bridge also requires a non-null input object; focused-field processing requires `GetFocus`/`CWnd::FromHandle`
to return a window. The retail SWF's established focus constraints remain in
[Architecture note 11](../Architecture/11_login_ui_assets_and_interactions.md).

Binary Ninja reports ten references because the overlapping `sub_4ADB52` function repeats four sites.
Deduplication produces these **six**, not ten. A whole executable-section byte census for E8/E9 rel32 targets
independently finds the same six CALL sites and no JMP; mapped-section literal-pointer scan finds no
`0x59E59F` pointer. These scans corroborate the recovered callers; they do not prove the absence of arbitrary
computed calls or injected/patched execution.

At the password call:

```asm
004adde6  cmp  byte [esi+0x158], 0
004added  jne  0x4ade05
004addef  cmp  dword [esi+0x150], 1
004addf6  je   0x4ade05
004addf8  cmp  byte [esi+0x155], 0
004addff  jne  0x4ade05
004ade01  xor  edx, edx
004ade03  jmp  0x4ade08
004ade05  push 1
004ade07  pop  edx
...
004ade14  push eax             ; fifth argument: account string
004ade15  push edx             ; fourth: softKeyOnly
004ade1c  push 1               ; third: encodeCredential
004ade1e  push ecx             ; second: selection end
004ade25  push ebx             ; first: selection start
004ade26  call CGameInputString_ProcessFrameInputAndSelection
```

Thus `softKeyOnly = (+0x158 != 0 || DWORD +0x150 == 1 || +0x155 != 0)`.
There is no charge-type read in this computation. The raw branch at `0x59EC68` requires
the **third** argument to be zero. Queued soft keys use the same third argument at `0x59EC1D`.
Protection can restrict input availability; it cannot change password encoding here.

## Initialization and policy writers

The encoding flag has no object/global initializer or mutable charge-type storage: its complete direct
provenance is the six literal caller values above. For the separate policy, the recovered writers are:

| Field | Initial/reset stores | Nonzero stores |
|---|---|---|
| DWORD `+0x150` | ctor `0x4A9E42`; protection reset `0x4AC3D5`; close `0x4AC648`: 0 | bind connection failure `0x4AF3DD`: 1; successful bind with failed local metadata verification `0x4AF7F1`: 1; picture-key challenge `0x4AF95E`: 2 unless already 1 |
| byte `+0x155` | ctor `0x4A9DEF`; reset `0x4AC3E1`; close `0x4AC668`: 0 | bind connection failure `0x4AF38C`: 1 |
| byte `+0x158` | ctor `0x4A9DFD`; reset `0x4AC3E7`; close `0x4AC66E`: 0 | successful bind with failed local metadata verification `0x4AF7F7`: 1 |

`CMD_SELECTSERVER` calls the reset at `0x4AA1C8` except when the existing Facebook-variant bypass applies.
The failure/lost-metadata semantics were already established in Architecture note 11; the new distinction
is that none writes `encodeCredential`. The picture-key value 2 also does **not** satisfy `+0x150 == 1`.
All named login-dialog methods were inspected; direct field-displacement candidates in the login region
were cross-checked. This is recovered native provenance, not an arbitrary-memory-alias absence proof.

## Login, account changes, charge/OEM variants

- Ordinary retail English password input reaches `0x4ADE26` with encoding 1. The raw branch in this helper
  belongs to non-password contexts; it is not a dormant password mode selected by a plain/free server.
- Typing a changed account clears credentials at `0x4ADC6F`. Selecting a different saved account clears
  them at `0x4AA4BF`; selecting the same account skips that change branch. Subsequent password entry uses
  the same constant 1 and the current account pointer at `0x4ADE08/0x4ADE14`. These established clear paths
  do not write an encoding-mode state.
- `GetServerChargeType` (`0x4AFD83`) supplies metadata verification/protection and authentication-routing
  decisions. Its seven recovered callers do not include the input helper or its password caller.
- `ini/oem.ini [AccountSetup] Type` is read later in `0x66D4C1`; both ordinary and Type=1 paths consume the
  credential buffer passed from `dlg+0x414` at `0x4AF097..0x4AF0A1`. That packet/envelope choice is not a
  keypad/raw selection. No second investigation of RC5 or packet layouts was required.
- Conditional French-language UI uses `CMD_PASSWORD`: its producer calls the established encoder
  unconditionally for each supplied character (`0x4AA80B`, `0x4AA837`) before storing `+0x414`.
  The supplied retail language getter is already proven to return English in Architecture note 11.

## Separate initializer bypass; do not overstate the conclusion

`0x4AC4D7`, now named `CLoginFlashDlg_SetInitialPasswordWithOptionalAccountEncoding`, accepts a password
and account. A null password returns. A nonempty account plus non-null `dlg+0x15C` encodes before storage.
Otherwise `0x4AC580..0x4AC58B` stores the supplied bytes directly.

Its sole recovered caller, `0x5AB43E`, checks both account and password nonempty at `0x5AB3EA..0x5AB40A`.
The remaining bypass condition is a null input object: the constructor leaves it null for the French
language condition, or if allocation fails (`0x4A9BDD..0x4A9C47`). The retail English constructor normally
allocates it. This is a startup preload/failure-path distinction, **not** an ordinary charge-selected raw login.
Whether such an exceptional preload reaches a successful native login was not observed here.
The separate session-credential initializer `0x4AF99B` requires nonempty account/credential and always encodes.

## Evidence, annotations, and remaining gaps

- [Binary Ninja raw assembly and xrefs](evidence/preworld-credential-mode-2026-10-30/client-bninja-evidence.json)
- [Instruction-byte validation](evidence/preworld-credential-mode-2026-10-30/byte-validation.json): 10208 captured instruction records across 51 function captures match the supplied executable.
- [Independent direct-call census](evidence/preworld-credential-mode-2026-10-30/client-call-census.json)
- [Annotation changes and readback](evidence/preworld-credential-mode-2026-10-30/annotations.json)

Encoding/policy argument separation and ordinary retail mode selection are closed by static native evidence.
No new Windows runtime observation was made. Exceptional preload, customized OEM/French assets, allocation
failure, and successful service-side handling of those variants remain unmeasured. The existing non-ASCII
and unusual-password gaps remain unchanged. No implementation changes; no BNDB save was initiated.
