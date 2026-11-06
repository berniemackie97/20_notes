006ec479  e8 51 5f f7 ff   call    CHero__RefreshEquipmentDerivedStats
006ec47e  e8 dd 7f d1 ff   call    CHero_GetSingletonPtr
006ec483  8b c8            mov     ecx, eax
006ec485  e8 e3 0b f7 ff   call    CHero_GetEffectiveMaxLife  ; This is a CLAMP, not a wire value: nothing here comes from the tick packet's payload. After the equip-slot 0x12 change above, it recomputes CHero_GetEffectiveMaxLife and, only when the current index 1 exceeds it, writes the new maximum into vtable +0xA4, index 1 and index 15, then posts 0x3EB, 0x3FB, 0x445, 0x446 and 0x4FE. So a managed client that never applies MsgTick loses the post-equipment clamp, not a life update.
006ec48a  6a 01            push    0x1
006ec48c  8b f0            mov     esi, eax
006ec48e  e8 cd 7f d1 ff   call    CHero_GetSingletonPtr
006ec493  8b c8            mov     ecx, eax
006ec495  e8 f8 79 f8 ff   call    CHero_GetPlayerDataByIndex
006ec49a  3b c6            cmp     eax, esi
006ec49c  7e 2e            jle     0x6ec4cc
006ec49e  e8 bd 7f d1 ff   call    CHero_GetSingletonPtr
006ec4a3  8b 10            mov     edx, dword [eax]
006ec4a5  56               push    esi
006ec4a6  8b c8            mov     ecx, eax
006ec4a8  ff 92 a4 00 00 00 call    dword [edx+0xa4]
006ec4ae  56               push    esi
006ec4af  6a 01            push    0x1
006ec4b1  e8 aa 7f d1 ff   call    CHero_GetSingletonPtr
006ec4b6  8b c8            mov     ecx, eax
006ec4b8  e8 ef 79 f8 ff   call    CRole_SetPlayerDataByIndex
006ec4bd  56               push    esi
006ec4be  6a 0f            push    0xf
006ec4c0  e8 9b 7f d1 ff   call    CHero_GetSingletonPtr
006ec4c5  8b c8            mov     ecx, eax
006ec4c7  e8 e0 79 f8 ff   call    CRole_SetPlayerDataByIndex

