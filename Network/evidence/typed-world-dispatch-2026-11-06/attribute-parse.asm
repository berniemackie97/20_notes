00757351  56               push    esi
00757352  8b f1            mov     esi, ecx
00757354  ff 74 24 0c      push    dword [esp+0xc]
00757358  ff 74 24 0c      push    dword [esp+0xc]
0075735c  e8 4d 7f f8 ff   call    CNetMsg__ValidateHeaderAndCopy
00757361  85 c0            test    eax, eax
00757363  74 0b            je      0x757370
00757365  33 c0            xor     eax, eax
00757367  66 81 7e 06 21 27 cmp     word [esi+0x6], 0x2721
0075736d  0f 94 c0         sete    al
00757370  5e               pop     esi
00757371  c2 08 00         retn    0x8
