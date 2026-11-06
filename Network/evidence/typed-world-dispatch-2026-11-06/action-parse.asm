006feb93  56               push    esi
006feb94  8b f1            mov     esi, ecx
006feb96  ff 74 24 0c      push    dword [esp+0xc]
006feb9a  ff 74 24 0c      push    dword [esp+0xc]
006feb9e  e8 0b 07 fe ff   call    CNetMsg__ValidateHeaderAndCopy
006feba3  85 c0            test    eax, eax
006feba5  74 0b            je      0x6febb2
006feba7  33 c0            xor     eax, eax
006feba9  66 81 7e 06 1a 27 cmp     word [esi+0x6], 0x271a
006febaf  0f 94 c0         sete    al
006febb2  5e               pop     esi
006febb3  c2 08 00         retn    0x8
