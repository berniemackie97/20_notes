# CHeroItem__TrackItemAtPosition; CP2.4b static clean5517 Binary Ninja excerpt
006db021  b8 e0 1d 83 00   mov     eax, 0x831de0  ; (position, item): accepts position 1..18 (0x6DB042) or 21..29 (0x6DB050), else returns doing nothing. Stores item in the tracked map (+0xF20) without removing any older key. Positions 10..18 -> CHeroItem__SetEquipSlot(position); 1..9 and 21..29 -> re-set active slots 1..18 that already hold this item. CP2.4b.
006db026  e8 25 c6 09 00   call    __EH_prolog
006db02b  51               push    ecx
006db02c  53               push    ebx
006db02d  56               push    esi
006db02e  57               push    edi
006db02f  8b f9            mov     edi, ecx
006db031  8b 45 08         mov     eax, dword [ebp+0x8]
006db034  83 65 fc 00      and     dword [ebp-0x4], 0x0
006db038  6a 01            push    0x1
006db03a  5b               pop     ebx
006db03b  3b c3            cmp     eax, ebx
006db03d  7c 05            jl      0x6db044
006db03f  83 f8 13         cmp     eax, 0x13
006db042  7c 12            jl      0x6db056
006db044  83 f8 15         cmp     eax, 0x15
006db047  0f 8c a8 00 00 00 jl      0x6db0f5
006db04d  83 f8 1d         cmp     eax, 0x1d
006db050  0f 8f 9f 00 00 00 jg      0x6db0f5
006db056  8d 45 08         lea     eax, [ebp+0x8]
006db059  8d 8f 20 0f 00 00 lea     ecx, [edi+0xf20]
006db05f  50               push    eax
006db060  e8 66 1f 00 00   call    0x6dcfcb
006db065  8b 4d 0c         mov     ecx, dword [ebp+0xc]
006db068  89 08            mov     dword [eax], ecx
006db06a  8d 4d 10         lea     ecx, [ebp+0x10]
006db06d  51               push    ecx
006db06e  8d 48 04         lea     ecx, [eax+0x4]
006db071  e8 af 5e d3 ff   call    0x410f25
006db076  83 7d 08 0a      cmp     dword [ebp+0x8], 0xa
006db07a  7c 32            jl      0x6db0ae
006db07c  83 7d 08 13      cmp     dword [ebp+0x8], 0x13
006db080  7d 2c            jge     0x6db0ae
006db082  51               push    ecx
006db083  51               push    ecx
006db084  8b 4d 0c         mov     ecx, dword [ebp+0xc]
006db087  8b c4            mov     eax, esp
006db089  89 65 f0         mov     dword [ebp-0x10], esp
006db08c  89 08            mov     dword [eax], ecx
006db08e  8b 4d 10         mov     ecx, dword [ebp+0x10]
006db091  89 48 04         mov     dword [eax+0x4], ecx
006db094  8b 45 10         mov     eax, dword [ebp+0x10]
006db097  85 c0            test    eax, eax
006db099  74 07            je      0x6db0a2
006db09b  83 c0 04         add     eax, 0x4
006db09e  f0 0f c1 18      lock xadd dword [eax], ebx
006db0a2  ff 75 08         push    dword [ebp+0x8]
006db0a5  8b cf            mov     ecx, edi
006db0a7  e8 5a f8 ff ff   call    CHeroItem__SetEquipSlot
006db0ac  eb 47            jmp     0x6db0f5
006db0ae  8b 4d 0c         mov     ecx, dword [ebp+0xc]
006db0b1  85 c9            test    ecx, ecx
006db0b3  74 40            je      0x6db0f5
006db0b5  8d b7 8c 0e 00 00 lea     esi, [edi+0xe8c]
006db0bb  eb 03            jmp     0x6db0c0
006db0bd  8b 4d 0c         mov     ecx, dword [ebp+0xc]
006db0c0  39 0e            cmp     dword [esi], ecx
006db0c2  75 28            jne     0x6db0ec
006db0c4  51               push    ecx
006db0c5  51               push    ecx
006db0c6  8b c4            mov     eax, esp
006db0c8  89 65 f0         mov     dword [ebp-0x10], esp
006db0cb  89 08            mov     dword [eax], ecx
006db0cd  8b 4d 10         mov     ecx, dword [ebp+0x10]
006db0d0  89 48 04         mov     dword [eax+0x4], ecx
006db0d3  8b 45 10         mov     eax, dword [ebp+0x10]
006db0d6  85 c0            test    eax, eax
006db0d8  74 0a            je      0x6db0e4
006db0da  6a 01            push    0x1
006db0dc  83 c0 04         add     eax, 0x4
006db0df  59               pop     ecx
006db0e0  f0 0f c1 08      lock xadd dword [eax], ecx
006db0e4  53               push    ebx
006db0e5  8b cf            mov     ecx, edi
006db0e7  e8 1a f8 ff ff   call    CHeroItem__SetEquipSlot
006db0ec  43               inc     ebx
006db0ed  83 c6 08         add     esi, 0x8
006db0f0  83 fb 13         cmp     ebx, 0x13
006db0f3  7c c8            jl      0x6db0bd
006db0f5  8b 4d 10         mov     ecx, dword [ebp+0x10]
006db0f8  83 4d fc ff      or      dword [ebp-0x4], 0xffffffff
006db0fc  85 c9            test    ecx, ecx
006db0fe  74 05            je      0x6db105
006db100  e8 df 9b d2 ff   call    SharedPtrControlBlock_DecrementStrongReference
006db105  8b 4d f4         mov     ecx, dword [ebp-0xc]
006db108  5f               pop     edi
006db109  5e               pop     esi
006db10a  64 89 0d 00 00 00 00 mov     dword [fs:0x0], ecx
006db111  5b               pop     ebx
006db112  c9               leave
006db113  c2 0c 00         retn    0xc
