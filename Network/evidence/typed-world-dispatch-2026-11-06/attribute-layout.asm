00757307  c7 06 b0 d0 86 00 mov     dword [esi], 0x86d0b0
0075730d  e8 6f 7f f8 ff   call    CNetMsg__ResetPacketBuffer
00757312  8b 4d f4         mov     ecx, dword [ebp-0xc]
00757315  8d 46 04         lea     eax, [esi+0x4]
00757318  89 86 04 04 00 00 mov     dword [esi+0x404], eax
00757389  8b 83 04 04 00 00 mov     eax, dword [ebx+0x404]
0075738f  6a 01            push    0x1
00757391  b9 18 b0 96 00   mov     ecx, 0x96b018
00757396  ff 70 04         push    dword [eax+0x4]
00757399  8d 45 ec         lea     eax, [ebp-0x14]
0075739c  50               push    eax
0075739d  e8 db 10 f9 ff   call    EntityRef_ResolveByIdOrLocalHero
007573a2  33 c9            xor     ecx, ecx
007573a4  39 4d ec         cmp     dword [ebp-0x14], ecx
007573a7  89 4d fc         mov     dword [ebp-0x4], ecx
0075743a  8b 83 04 04 00 00 mov     eax, dword [ebx+0x404]
00757440  47               inc     edi
00757441  83 c6 14         add     esi, 0x14
00757444  3b 78 08         cmp     edi, dword [eax+0x8]
00757447  0f 8c 78 ff ff ff jl      0x7573c5
0075744d  e9 8d 17 00 00   jmp     0x758bdf
00757452  8b 93 04 04 00 00 mov     edx, dword [ebx+0x404]
00757458  33 c0            xor     eax, eax
0075745a  89 45 e4         mov     dword [ebp-0x1c], eax
0075745d  39 4a 08         cmp     dword [edx+0x8], ecx
00757460  0f 8e 35 17 00 00 jle     0x758b9b
00757466  8b 75 e4         mov     esi, dword [ebp-0x1c]
00757469  8d 34 b6         lea     esi, [esi+esi*4]
0075746c  c1 e6 02         shl     esi, 0x2
0075746f  8b 44 16 0c      mov     eax, dword [esi+edx+0xc]
00757473  8d 3c 16         lea     edi, [esi+edx]
00757476  83 f8 1b         cmp     eax, 0x1b
00757479  0f 87 ab 07 00 00 ja      0x757c2a
0075747f  0f 84 85 07 00 00 je      0x757c0a
00757485  83 f8 1a         cmp     eax, 0x1a
00757488  0f 87 f8 16 00 00 ja      0x758b86
0075748e  ff 24 85 19 8d 75 00 jmp     dword [eax*4+0x758d19]
007574c5  33 ff            xor     edi, edi
007574c7  8d 4d b8         lea     ecx, [ebp-0x48]
007574ca  57               push    edi
007574cb  e8 06 fe ff ff   call    0x7572d6
007574d0  8b 83 04 04 00 00 mov     eax, dword [ebx+0x404]
007574d6  57               push    edi
007574d7  8d 4d b8         lea     ecx, [ebp-0x48]
007574da  8d 74 06 10      lea     esi, [esi+eax+0x10]
007574de  e8 f3 fd ff ff   call    0x7572d6
007574e3  6a 10            push    0x10
007574e5  8d 45 b8         lea     eax, [ebp-0x48]
007574e8  56               push    esi
007574e9  50               push    eax
007574ea  e8 cb 01 02 00   call    memcpy
007574ef  83 c4 0c         add     esp, 0xc
007576fd  8b 4d ec         mov     ecx, dword [ebp-0x14]
00757700  8d 45 b8         lea     eax, [ebp-0x48]
00757703  50               push    eax
00757704  e8 fe ea f1 ff   call    CRole_TrackPrimaryStatusBitChangesForRestrictedIdRange
00757709  8b 4d ec         mov     ecx, dword [ebp-0x14]
0075770c  8d 55 b8         lea     edx, [ebp-0x48]
0075770f  52               push    edx
00757710  8b 01            mov     eax, dword [ecx]
00757712  ff 90 d0 00 00 00 call    dword [eax+0xd0]
007579ed  8b 45 ec         mov     eax, dword [ebp-0x14]
007579f0  83 c7 10         add     edi, 0x10
007579f3  8b 88 64 08 00 00 mov     ecx, dword [eax+0x864]
007579f9  8b 90 60 08 00 00 mov     edx, dword [eax+0x860]
007579ff  3b 4f 04         cmp     ecx, dword [edi+0x4]
00757a02  89 55 b0         mov     dword [ebp-0x50], edx
00757a05  89 4d b4         mov     dword [ebp-0x4c], ecx
00757a08  7f 2b            jg      0x757a35
00757a0a  7c 04            jl      0x757a10
00757a0c  3b 17            cmp     edx, dword [edi]
00757a0e  73 25            jae     0x757a35
00757a10  e8 70 8c cb ff   call    CGameMap_GetSingletonPtr
00758b86  ff 45 e4         inc     dword [ebp-0x1c]
00758b89  8b 93 04 04 00 00 mov     edx, dword [ebx+0x404]
00758b8f  8b 45 e4         mov     eax, dword [ebp-0x1c]
00758b92  3b 42 08         cmp     eax, dword [edx+0x8]
00758b95  0f 8c cb e8 ff ff jl      0x757466
