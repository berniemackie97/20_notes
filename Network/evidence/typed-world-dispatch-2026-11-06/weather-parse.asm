007607de  56               push    esi
007607df  8b f1            mov     esi, ecx
007607e1  ff 74 24 0c      push    dword [esp+0xc]
007607e5  ff 74 24 0c      push    dword [esp+0xc]
007607e9  e8 c0 ea f7 ff   call    CNetMsg__ValidateHeaderAndCopy
007607ee  85 c0            test    eax, eax
007607f0  74 0b            je      0x7607fd
007607f2  33 c0            xor     eax, eax
007607f4  66 81 7e 06 f8 03 cmp     word [esi+0x6], 0x3f8
007607fa  0f 94 c0         sete    al
007607fd  5e               pop     esi
007607fe  c2 08 00         retn    0x8
