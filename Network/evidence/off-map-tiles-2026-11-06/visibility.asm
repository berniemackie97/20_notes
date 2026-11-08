0061e00d  55               push    ebp
0061e00e  8b ec            mov     ebp, esp
0061e010  83 ec 14         sub     esp, 0x14
0061e013  53               push    ebx
0061e014  56               push    esi
0061e015  57               push    edi
0061e016  8b f1            mov     esi, ecx
0061e018  e8 a6 0d 00 00   call    CGameMap_GetProjectionClampScaleDivisor
0061e01d  8b c8            mov     ecx, eax
0061e01f  a1 c0 c6 93 00   mov     eax, dword [0x93c6c0]
0061e024  0f af 45 10      imul    eax, dword [ebp+0x10]
0061e028  c1 e0 06         shl     eax, 0x6
0061e02b  99               cdq
0061e02c  f7 f9            idiv    ecx
0061e02e  8b ce            mov     ecx, esi
0061e030  89 45 fc         mov     dword [ebp-0x4], eax
0061e033  e8 8b 0d 00 00   call    CGameMap_GetProjectionClampScaleDivisor
0061e038  8b c8            mov     ecx, eax
0061e03a  a1 c0 c6 93 00   mov     eax, dword [0x93c6c0]
0061e03f  0f af 45 10      imul    eax, dword [ebp+0x10]
0061e043  c1 e0 05         shl     eax, 0x5
0061e046  99               cdq
0061e047  f7 f9            idiv    ecx
0061e049  8b ce            mov     ecx, esi
0061e04b  89 45 10         mov     dword [ebp+0x10], eax
0061e04e  8d 45 f0         lea     eax, [ebp-0x10]
0061e051  50               push    eax
0061e052  8d 45 ec         lea     eax, [ebp-0x14]
0061e055  50               push    eax
0061e056  ff 75 0c         push    dword [ebp+0xc]
0061e059  ff 75 08         push    dword [ebp+0x8]
0061e05c  e8 ef f7 ff ff   call    Map_ProjectTileToScreenCoordinates
0061e061  8d 45 f8         lea     eax, [ebp-0x8]
0061e064  8b ce            mov     ecx, esi
0061e066  50               push    eax
0061e067  8d 45 f4         lea     eax, [ebp-0xc]
0061e06a  50               push    eax
0061e06b  6a 00            push    0x0
0061e06d  6a 00            push    0x0
0061e06f  e8 52 f8 ff ff   call    CGameMap_GetPointAbsoluteFromProjectionCenter
0061e074  8b 7d f4         mov     edi, dword [ebp-0xc]
0061e077  8b 5d f8         mov     ebx, dword [ebp-0x8]
0061e07a  2b 7d fc         sub     edi, dword [ebp-0x4]
0061e07d  2b 5d 10         sub     ebx, dword [ebp+0x10]
0061e080  ff 15 84 4c 84 00 call    dword [?GetScreenWidth@CMyBitmap@@SAHXZ]
0061e086  8b f0            mov     esi, eax
0061e088  03 75 f4         add     esi, dword [ebp-0xc]
0061e08b  03 75 fc         add     esi, dword [ebp-0x4]
0061e08e  ff 15 74 4c 84 00 call    dword [?GetScreenHeight@CMyBitmap@@SAHXZ]
0061e094  03 45 f8         add     eax, dword [ebp-0x8]
0061e097  03 45 10         add     eax, dword [ebp+0x10]
0061e09a  39 7d ec         cmp     dword [ebp-0x14], edi
0061e09d  7c 14            jl      0x61e0b3
0061e09f  39 5d f0         cmp     dword [ebp-0x10], ebx
0061e0a2  7c 0f            jl      0x61e0b3
0061e0a4  39 75 ec         cmp     dword [ebp-0x14], esi
0061e0a7  7f 0a            jg      0x61e0b3
0061e0a9  39 45 f0         cmp     dword [ebp-0x10], eax
0061e0ac  7f 05            jg      0x61e0b3
0061e0ae  6a 01            push    0x1
0061e0b0  58               pop     eax
0061e0b1  eb 02            jmp     0x61e0b5
0061e0b3  33 c0            xor     eax, eax
0061e0b5  5f               pop     edi
0061e0b6  5e               pop     esi
0061e0b7  5b               pop     ebx
0061e0b8  c9               leave
0061e0b9  c2 0c 00         retn    0xc
