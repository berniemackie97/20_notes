0064f649  e8 37 10 dc ff   call    CGameMap_GetSingletonPtr
0064f64e  8d 4d c0         lea     ecx, [ebp-0x40]
0064f651  51               push    ecx
0064f652  8d 4d c4         lea     ecx, [ebp-0x3c]
0064f655  51               push    ecx
0064f656  8b c8            mov     ecx, eax
0064f658  ff b6 54 03 00 00 push    dword [esi+0x354]
0064f65e  ff b6 50 03 00 00 push    dword [esi+0x350]
0064f664  e8 b0 ec fc ff   call    CGameMap_GetProjectionCenterOffsetFromScreenPoint
0064f669  8b ce            mov     ecx, esi
0064f66b  89 5d e8         mov     dword [ebp-0x18], ebx
0064f66e  89 5d e4         mov     dword [ebp-0x1c], ebx
0064f671  e8 14 1d 00 00   call    Role_GetCurrentActionId
0064f676  3d 82 00 00 00   cmp     eax, 0x82  ; Action-id gate for the motion-arc / terrain-delta vertical adjustment branch in Role_TickAndRender. Gated action ids: 0x82, 0x127, 0x20f, 0x38e. When the current action id is one of these AND Role_HasStatusFlag(0x1b) returns 0, the role calls Role_GetMotionArcScreenHeightAnchor (var_18) and Role_GetTerrainHeightDeltaFromProjectedScreenPosition (var_1c). For the local hero idle action set (i.e., the currently animated motion is none of these 4 ids), both deltas stay at 0, which keeps the slot-4 elevation arg at 0 in the absence of any other vertical-offset writers. Verified by tracing all writers of role[0xC3] (CRole__SetVerticalRenderOffset, callers sub_7C5B0F/sub_7C645E only), role[0xE9] and role[0xEA] (CRole__SetAdditionalOffsetY[Enabled], callers sub_7487AF/sub_748DAB in TexasNpc.cpp only).
0064f67b  74 31            je      0x64f6ae
0064f67d  3d 27 01 00 00   cmp     eax, 0x127
0064f682  74 2a            je      0x64f6ae
0064f684  3d 0f 02 00 00   cmp     eax, 0x20f
0064f689  74 23            je      0x64f6ae
0064f68b  3d 8e 03 00 00   cmp     eax, 0x38e
0064f690  75 3d            jne     0x64f6cf
0064f692  38 9e 94 03 00 00 cmp     byte [esi+0x394], bl
0064f698  75 35            jne     0x64f6cf
0064f69a  83 be e8 01 00 00 25 cmp     dword [esi+0x1e8], 0x25
0064f6a1  75 2c            jne     0x64f6cf
0064f6a3  8b 86 9c 03 00 00 mov     eax, dword [esi+0x39c]
0064f6a9  89 45 e8         mov     dword [ebp-0x18], eax
0064f6ac  eb 21            jmp     0x64f6cf
0064f6ae  6a 1b            push    0x1b
0064f6b0  8b ce            mov     ecx, esi
0064f6b2  e8 1d 5a 09 00   call    Role_HasStatusFlag
0064f6b7  84 c0            test    al, al
0064f6b9  75 14            jne     0x64f6cf
0064f6bb  8b ce            mov     ecx, esi
0064f6bd  e8 c1 0e 00 00   call    Role_GetMotionArcScreenHeightAnchor  ; For current actions 0x82/0x127/0x20F with status 0x1B clear, compute terrain-aware motion arc anchor and current terrain delta. RoleView transform receives the terrain delta as its separate elevation term; the 2D Y expression subtracts both values and therefore remains grounded at the current terrain anchor.
0064f6c2  8b ce            mov     ecx, esi
0064f6c4  89 45 e8         mov     dword [ebp-0x18], eax
0064f6c7  e8 37 12 00 00   call    Role_GetTerrainHeightDeltaFromProjectedScreenPosition
0064f6cc  89 45 e4         mov     dword [ebp-0x1c], eax
0064f6cf  83 cf ff         or      edi, 0xffffffff  ; Baseline live-role facing begins here: EDI is set to -1, then role+0x17C (CurrentDirectionIndex) is subtracted and the result is multiplied by 45 at 0x64F6E6. Therefore the ordinary RoleView rotation is exactly (-1 - directionIndex) * 45 degrees. Later projected-path and target-facing branches may override this value.
0064f6d2  8b 86 0c 03 00 00 mov     eax, dword [esi+0x30c]
0064f6d8  2b be 7c 01 00 00 sub     edi, dword [esi+0x17c]  ; Subtracts CRole+0x17C CurrentDirectionIndex from -1. Together with the IMUL 45 at 0x64F6E6, this proves the baseline player-role RoleView rotation formula (-1 - directionIndex) * 45 degrees.
0064f6de  01 45 e8         add     dword [ebp-0x18], eax
0064f6e1  29 45 e4         sub     dword [ebp-0x1c], eax
0064f6e4  8b ce            mov     ecx, esi
0064f6e6  6b ff 2d         imul    edi, edi, 0x2d  ; Final baseline-facing multiply: facingDegrees = (-1 - role->CurrentDirectionIndex) * 45. Stored to the transform local at 0x64F6E9 unless a later facing-override branch replaces it.
0064f6e9  89 7d dc         mov     dword [ebp-0x24], edi
0064f6ec  e8 6e 57 09 00   call    Role_IsCurrentActionInProjectedPathFacingOverrideSet
0064f6f1  85 c0            test    eax, eax
0064f6f3  74 57            je      0x64f74c
0064f6f5  83 7e 1c ff      cmp     dword [esi+0x1c], 0xffffffff
0064f6f9  75 51            jne     0x64f74c
0064f6fb  8b 86 9c 01 00 00 mov     eax, dword [esi+0x19c]
