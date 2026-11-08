# CHeroItem__TryAddInventoryItem; CP2.4b static clean5517 Binary Ninja excerpt
006d9334  b8 38 1b 83 00   mov     eax, 0x831b38
006d9339  e8 12 e3 09 00   call    __EH_prolog
006d933e  83 ec 0c         sub     esp, 0xc
006d9341  56               push    esi
006d9342  8b f1            mov     esi, ecx
006d9344  83 65 fc 00      and     dword [ebp-0x4], 0x0
006d9348  83 7d 08 00      cmp     dword [ebp+0x8], 0x0
006d934c  74 4d            je      0x6d939b
006d934e  8d 8e 34 0e 00 00 lea     ecx, [esi+0xe34]
006d9354  89 4d f0         mov     dword [ebp-0x10], ecx
006d9357  e8 0e 58 fc ff   call    StdDequePtr_GetCount_Type2ChildList
006d935c  83 f8 28         cmp     eax, 0x28
006d935f  72 0c            jb      0x6d936d
006d9361  8b 4d 08         mov     ecx, dword [ebp+0x8]
006d9364  e8 90 ee e8 ff   call    CItem_IsArrow
006d9369  85 c0            test    eax, eax
006d936b  74 2e            je      0x6d939b  ; CP2.4b: inventory add rejects when count >= 40 (0x28) unless CItem_IsArrow (category 0 and subtype 50000). Returns 0; caller skips.
006d936d  8b 4d 08         mov     ecx, dword [ebp+0x8]
006d9370  53               push    ebx
006d9371  6a 01            push    0x1
006d9373  e8 93 6b 04 00   call    Folded_GetDword_0x0C
006d9378  50               push    eax
006d9379  8d 45 e8         lea     eax, [ebp-0x18]
006d937c  50               push    eax
006d937d  8b ce            mov     ecx, esi
006d937f  e8 c7 fe ff ff   call    CHeroItem__FindItemByUid
006d9384  83 38 00         cmp     dword [eax], 0x0
006d9387  8b 4d ec         mov     ecx, dword [ebp-0x14]
006d938a  0f 95 c3         setne   bl
006d938d  85 c9            test    ecx, ecx
006d938f  74 05            je      0x6d9396
006d9391  e8 4e b9 d2 ff   call    SharedPtrControlBlock_DecrementStrongReference
006d9396  84 db            test    bl, bl
006d9398  5b               pop     ebx
006d9399  74 14            je      0x6d93af  ; CP2.4b: inventory add rejects a UID already in the inventory list (FindItemByUid flag 1 = inventory only, tracked items not searched). Returns 0; caller skips.
006d939b  8b 4d 0c         mov     ecx, dword [ebp+0xc]
006d939e  83 4d fc ff      or      dword [ebp-0x4], 0xffffffff
006d93a2  85 c9            test    ecx, ecx
006d93a4  74 05            je      0x6d93ab
006d93a6  e8 39 b9 d2 ff   call    SharedPtrControlBlock_DecrementStrongReference
006d93ab  33 c0            xor     eax, eax
006d93ad  eb 1f            jmp     0x6d93ce
006d93af  8b 4d f0         mov     ecx, dword [ebp-0x10]
006d93b2  8d 45 08         lea     eax, [ebp+0x8]
006d93b5  50               push    eax
006d93b6  e8 0e 3b 00 00   call    0x6dcec9
006d93bb  8b 4d 0c         mov     ecx, dword [ebp+0xc]
006d93be  83 4d fc ff      or      dword [ebp-0x4], 0xffffffff
006d93c2  85 c9            test    ecx, ecx
006d93c4  74 05            je      0x6d93cb
006d93c6  e8 19 b9 d2 ff   call    SharedPtrControlBlock_DecrementStrongReference
006d93cb  6a 01            push    0x1
006d93cd  58               pop     eax
006d93ce  8b 4d f4         mov     ecx, dword [ebp-0xc]
006d93d1  5e               pop     esi
006d93d2  64 89 0d 00 00 00 00 mov     dword [fs:0x0], ecx
006d93d9  c9               leave
006d93da  c2 08 00         retn    0x8
