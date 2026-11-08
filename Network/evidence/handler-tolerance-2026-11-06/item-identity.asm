# CItem_InitIdentityFromItemType; CP2.4b static clean5517 Binary Ninja excerpt
0067ad6b  56               push    esi  ; (item, uid, typeId): returns 0 when uid == 0, typeId == 0 or sub_67abb5 fails (ItemTypeDataSingleton_TryGetItemRecordByTypeId miss, logs "Read Error in ItemType.dat"); else stores uid at item+0x0C, returns 1. Callers in CMsg1008 Process skip the record on 0. CP2.4b.
0067ad6c  57               push    edi
0067ad6d  8b 7c 24 0c      mov     edi, dword [esp+0xc]
0067ad71  8b f1            mov     esi, ecx
0067ad73  85 ff            test    edi, edi
0067ad75  74 1c            je      0x67ad93
0067ad77  83 7c 24 10 00   cmp     dword [esp+0x10], 0x0
0067ad7c  74 15            je      0x67ad93
0067ad7e  ff 74 24 10      push    dword [esp+0x10]
0067ad82  e8 2e fe ff ff   call    0x67abb5
0067ad87  84 c0            test    al, al
0067ad89  74 08            je      0x67ad93
0067ad8b  6a 01            push    0x1
0067ad8d  89 7e 0c         mov     dword [esi+0xc], edi
0067ad90  58               pop     eax
0067ad91  eb 02            jmp     0x67ad95
0067ad93  33 c0            xor     eax, eax
0067ad95  5f               pop     edi
0067ad96  5e               pop     esi
0067ad97  c2 08 00         retn    0x8
