# Reused CP0.1 dispatch excerpt, rechecked against the same clean PE.
006df3b5  b8 90 2b 83 00   mov     eax, 0x832b90
006df3ba  e8 91 82 09 00   call    __EH_prolog
006df3bf  51               push    ecx
006df3c0  51               push    ecx
006df3c1  83 7d 08 00      cmp     dword [ebp+0x8], 0x0
006df3c5  53               push    ebx
006df3c6  56               push    esi
006df3c7  57               push    edi
006df3c8  89 65 f0         mov     dword [ebp-0x10], esp
006df3cb  0f 84 aa 1f 00 00 je      0x6e137b
006df3d1  81 7d 0c 00 04 00 00 cmp     dword [ebp+0xc], 0x400
006df3d8  0f 8f 9d 1f 00 00 jg      0x6e137b
006df3de  ff 75 0c         push    dword [ebp+0xc]
006df3e1  ff 75 08         push    dword [ebp+0x8]
006df3e4  e8 bb ff ff ff   call    CNetMsg__GetType
006df3e9  59               pop     ecx
006df3ea  59               pop     ecx
006df3eb  0f b7 c0         movzx   eax, ax
006df3ee  b9 20 05 00 00   mov     ecx, 0x520
006df3f3  3b c1            cmp     eax, ecx
006df3f5  0f 8f 55 0b 00 00 jg      0x6dff50
006df3fb  0f 84 26 0b 00 00 je      0x6dff27
006df401  05 16 fc ff ff   add     eax, 0xfffffc16
006df406  be 95 00 00 00   mov     esi, 0x95
006df40b  3b c6            cmp     eax, esi
006df40d  0f 87 68 1f 00 00 ja      0x6e137b
006df413  0f b6 80 cc 14 6e 00 movzx   eax, byte [eax+0x6e14cc]
006df41a  ff 24 85 b4 13 6e 00 jmp     dword [eax*4+0x6e13b4]
006df9e7  e8 88 78 09 00   call    ??2@YAPAXI@Z
006df9ec  59               pop     ecx
006df9ed  8b c8            mov     ecx, eax
006df9ef  89 4d ec         mov     dword [ebp-0x14], ecx
006df9f2  85 c9            test    ecx, ecx
006df9f4  c7 45 fc 42 00 00 00 mov     dword [ebp-0x4], 0x42
006df9fb  0f 84 4e 19 00 00 je      0x6e134f
006dfa01  e8 61 0c 08 00   call    CMsgWeatherUpdate__Ctor
006dfa06  e9 46 19 00 00   jmp     0x6e1351
006e12c1  0f 85 b4 00 00 00 jne     0x6e137b
006e12c7  68 08 04 00 00   push    0x408
006e12cc  e8 a3 5f 09 00   call    ??2@YAPAXI@Z
006e12d1  59               pop     ecx
006e12d2  8b c8            mov     ecx, eax
006e12d4  89 4d ec         mov     dword [ebp-0x14], ecx
006e12d7  85 c9            test    ecx, ecx
006e12d9  c7 45 fc 1c 00 00 00 mov     dword [ebp-0x4], 0x1c
006e12e0  74 6d            je      0x6e134f
006e12e2  e8 04 60 07 00   call    CMsgUserAttribEx__Create
006e12e7  eb 68            jmp     0x6e1351
006e12e9  68 14 04 00 00   push    0x414
006e12ee  e8 81 5f 09 00   call    ??2@YAPAXI@Z
006e12f3  59               pop     ecx
006e12f4  8b c8            mov     ecx, eax
006e12f6  89 4d ec         mov     dword [ebp-0x14], ecx
006e12f9  85 c9            test    ecx, ecx
006e12fb  c7 45 fc 12 00 00 00 mov     dword [ebp-0x4], 0x12
006e1302  74 4b            je      0x6e134f
006e1304  e8 7a 4b 07 00   call    CMsgPlayerSpawn__Ctor
006e1309  eb 46            jmp     0x6e1351
006e130b  68 14 04 00 00   push    0x414
006e1310  e8 5f 5f 09 00   call    ??2@YAPAXI@Z
006e1315  59               pop     ecx
006e1316  8b c8            mov     ecx, eax
006e1318  89 4d ec         mov     dword [ebp-0x14], ecx
006e131b  85 c9            test    ecx, ecx
006e131d  c7 45 fc 11 00 00 00 mov     dword [ebp-0x4], 0x11
006e1324  74 29            je      0x6e134f
006e1326  e8 78 d5 01 00   call    CMsgAction_Ctor
006e132b  eb 24            jmp     0x6e1351
006e132d  68 08 04 00 00   push    0x408
006e1332  e8 3d 5f 09 00   call    ??2@YAPAXI@Z
006e1337  59               pop     ecx
006e1338  8b c8            mov     ecx, eax
006e1355  8b f0            mov     esi, eax
006e1357  85 f6            test    esi, esi
006e1359  74 20            je      0x6e137b
006e135b  ff 75 0c         push    dword [ebp+0xc]
006e135e  8b 06            mov     eax, dword [esi]
006e1360  8b ce            mov     ecx, esi
006e1362  ff 75 08         push    dword [ebp+0x8]
006e1365  ff 50 04         call    dword [eax+0x4]
006e1368  85 c0            test    eax, eax
006e136a  75 44            jne     0x6e13b0
006e136c  8b 06            mov     eax, dword [esi]
006e136e  6a 01            push    0x1
006e1370  8b ce            mov     ecx, esi
006e1372  c7 45 fc b6 00 00 00 mov     dword [ebp-0x4], 0xb6
006e1379  ff 10            call    dword [eax]
006e137b  33 c0            xor     eax, eax
