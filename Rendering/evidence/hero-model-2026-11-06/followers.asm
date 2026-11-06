0065e128  6a 01            push    0x1  ; Advance HP gauge follower (player-data index 15) toward current life (index 1) using signed max/80-or-1 rule; snap down to current.
0065e12a  8b ce            mov     ecx, esi
0065e12c  e8 61 5d 01 00   call    CHero_GetPlayerDataByIndex
0065e131  6a 0f            push    0xf
0065e133  8b ce            mov     ecx, esi
0065e135  8b d8            mov     ebx, eax
0065e137  e8 56 5d 01 00   call    CHero_GetPlayerDataByIndex
0065e13c  8b ce            mov     ecx, esi
0065e13e  8b f8            mov     edi, eax
0065e140  e8 28 ef ff ff   call    CHero_GetEffectiveMaxLife
0065e145  3b fb            cmp     edi, ebx
0065e147  89 45 08         mov     dword [ebp+0x8], eax
0065e14a  7d 12            jge     0x65e15e
0065e14c  83 f8 50         cmp     eax, 0x50
0065e14f  7c 0a            jl      0x65e15b
0065e151  6a 50            push    0x50
0065e153  99               cdq
0065e154  59               pop     ecx
0065e155  f7 f9            idiv    ecx
0065e157  03 f8            add     edi, eax
0065e159  eb 01            jmp     0x65e15c
0065e15b  47               inc     edi
0065e15c  3b fb            cmp     edi, ebx
0065e15e  7e 02            jle     0x65e162
0065e160  8b fb            mov     edi, ebx
0065e162  57               push    edi
0065e163  6a 0f            push    0xf
0065e165  8b ce            mov     ecx, esi
0065e167  e8 40 5d 01 00   call    CRole_SetPlayerDataByIndex
0065e16c  8b ce            mov     ecx, esi
0065e16e  e8 dc 76 01 00   call    Role_HasStatusFlag5
0065e173  84 c0            test    al, al
0065e175  75 24            jne     0x65e19b
0065e177  8b 45 08         mov     eax, dword [ebp+0x8]
0065e17a  6a 03            push    0x3
0065e17c  99               cdq
0065e17d  59               pop     ecx
0065e17e  f7 f9            idiv    ecx
0065e180  3b d8            cmp     ebx, eax
0065e182  7d 17            jge     0x65e19b
0065e184  8b 86 4c 2e 00 00 mov     eax, dword [esi+0x2e4c]
0065e18a  6a 01            push    0x1
0065e18c  50               push    eax
0065e18d  e8 ce 62 da ff   call    CHero_GetSingletonPtr
0065e192  8b c8            mov     ecx, eax
0065e194  e8 91 86 08 00   call    0x6e682a
0065e199  eb 12            jmp     0x65e1ad
0065e19b  ff b6 4c 2e 00 00 push    dword [esi+0x2e4c]
0065e1a1  e8 ba 62 da ff   call    CHero_GetSingletonPtr
0065e1a6  8b c8            mov     ecx, eax
0065e1a8  e8 df 86 08 00   call    0x6e688c
0065e1ad  8b 1e            mov     ebx, dword [esi]
0065e1af  bf ff ff ff 7f   mov     edi, 0x7fffffff
0065e1b4  6a 00            push    0x0
0065e1b6  57               push    edi
0065e1b7  e8 94 b0 10 00   call    Conquer_GetRandomModuloWithOptionalTimeReseed
0065e1bc  59               pop     ecx
0065e1bd  59               pop     ecx
0065e1be  50               push    eax
0065e1bf  8b ce            mov     ecx, esi
0065e1c1  ff 93 ac 00 00 00 call    dword [ebx+0xac]
0065e1c7  8b ce            mov     ecx, esi
0065e1c9  e8 41 50 01 00   call    CHero_GetCurrentMana  ; Advance MP gauge follower at CHero+0x768 toward current mana at CHero+0x5E0 using the same signed max/80-or-1 rule.
0065e1ce  8b d8            mov     ebx, eax
0065e1d0  8b 06            mov     eax, dword [esi]
0065e1d2  8b ce            mov     ecx, esi
0065e1d4  89 5d fc         mov     dword [ebp-0x4], ebx
0065e1d7  ff 90 b0 00 00 00 call    dword [eax+0xb0]
0065e1dd  8b ce            mov     ecx, esi
0065e1df  89 45 08         mov     dword [ebp+0x8], eax
0065e1e2  e8 73 f0 ff ff   call    CHero_GetEffectiveMaxMana
0065e1e7  39 5d 08         cmp     dword [ebp+0x8], ebx
0065e1ea  7d 16            jge     0x65e202
0065e1ec  83 f8 50         cmp     eax, 0x50
0065e1ef  7c 0b            jl      0x65e1fc
0065e1f1  6a 50            push    0x50
0065e1f3  99               cdq
0065e1f4  59               pop     ecx
0065e1f5  f7 f9            idiv    ecx
0065e1f7  01 45 08         add     dword [ebp+0x8], eax
0065e1fa  eb 03            jmp     0x65e1ff
0065e1fc  ff 45 08         inc     dword [ebp+0x8]
0065e1ff  39 5d 08         cmp     dword [ebp+0x8], ebx
0065e202  7e 03            jle     0x65e207
0065e204  89 5d 08         mov     dword [ebp+0x8], ebx
0065e207  33 db            xor     ebx, ebx
0065e209  53               push    ebx
0065e20a  57               push    edi
0065e20b  e8 40 b0 10 00   call    Conquer_GetRandomModuloWithOptionalTimeReseed
0065e210  53               push    ebx
0065e211  57               push    edi
0065e212  89 45 e8         mov     dword [ebp-0x18], eax
0065e215  e8 36 b0 10 00   call    Conquer_GetRandomModuloWithOptionalTimeReseed
0065e21a  53               push    ebx
0065e21b  57               push    edi
0065e21c  89 45 ec         mov     dword [ebp-0x14], eax
0065e21f  e8 2c b0 10 00   call    Conquer_GetRandomModuloWithOptionalTimeReseed
0065e224  53               push    ebx
0065e225  57               push    edi
0065e226  89 45 f0         mov     dword [ebp-0x10], eax
0065e229  e8 22 b0 10 00   call    Conquer_GetRandomModuloWithOptionalTimeReseed
0065e22e  83 c4 20         add     esp, 0x20
0065e231  89 45 f4         mov     dword [ebp-0xc], eax
0065e234  8d 45 e8         lea     eax, [ebp-0x18]
0065e237  8d 8e 68 07 00 00 lea     ecx, [esi+0x768]  ; Re-key the protected MP follower container, then write the already-computed follower through vtable slot +0xB4.
0065e23d  6a 04            push    0x4
0065e23f  50               push    eax
0065e240  e8 88 53 0b 00   call    0x7135cd
0065e245  8b 06            mov     eax, dword [esi]
0065e247  ff 75 08         push    dword [ebp+0x8]
0065e24a  8b ce            mov     ecx, esi
0065e24c  ff 90 b4 00 00 00 call    dword [eax+0xb4]

