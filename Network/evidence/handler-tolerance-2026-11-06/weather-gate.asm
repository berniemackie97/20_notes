007606cd  55               push    ebp  ; MsgWeatherUpdate (1016) input gate. VERIFIED 2026-08-16. Returns 1 on accept, 0 on reject.
007606ce  8b ec            mov     ebp, esp
007606d0  53               push    ebx
007606d1  8b 5d 08         mov     ebx, dword [ebp+0x8]
007606d4  56               push    esi
007606d5  57               push    edi
007606d6  85 db            test    ebx, ebx
007606d8  8b f1            mov     esi, ecx
007606da  0f 8e c9 00 00 00 jle     0x7607a9
007606e0  83 fb 0c         cmp     ebx, 0xc
007606e3  0f 8d c0 00 00 00 jge     0x7607a9
007606e9  83 7d 0c 00      cmp     dword [ebp+0xc], 0x0
007606ed  0f 8c b6 00 00 00 jl      0x7607a9
007606f3  81 7d 0c ff 03 00 00 cmp     dword [ebp+0xc], 0x3ff
007606fa  0f 8d a9 00 00 00 jge     0x7607a9
00760700  8b 7d 10         mov     edi, dword [ebp+0x10]
00760703  85 ff            test    edi, edi
00760705  0f 8c 9e 00 00 00 jl      0x7607a9
0076070b  81 ff 68 01 00 00 cmp     edi, 0x168
00760711  0f 8d 92 00 00 00 jge     0x7607a9
00760717  e8 65 eb f7 ff   call    CNetMsg__ResetPacketBuffer
0076071c  81 ff b4 00 00 00 cmp     edi, 0xb4
00760722  7e 06            jle     0x76072a
00760724  81 c7 98 fe ff ff add     edi, 0xfffffe98
0076072a  8d 43 ff         lea     eax, [ebx-0x1]
0076072d  83 f8 0a         cmp     eax, 0xa
00760730  77 77            ja      0x7607a9
00760732  8b 4d 14         mov     ecx, dword [ebp+0x14]
00760735  ff 24 85 b2 07 76 00 jmp     dword [eax*4+0x7607b2]
0076073c  6a 01            push    0x1
0076073e  eb 21            jmp     0x760761
00760740  6a 02            push    0x2
00760742  eb 1d            jmp     0x760761
00760744  8d 41 03         lea     eax, [ecx+0x3]
00760747  eb 1d            jmp     0x760766
00760749  8d 41 0a         lea     eax, [ecx+0xa]
0076074c  eb 18            jmp     0x760766
0076074e  6a 0d            push    0xd
00760750  eb 0f            jmp     0x760761
00760752  8d 41 0e         lea     eax, [ecx+0xe]
00760755  eb 0f            jmp     0x760766
00760757  6a 12            push    0x12
00760759  eb 06            jmp     0x760761
0076075b  6a 13            push    0x13
0076075d  eb 02            jmp     0x760761
0076075f  6a 14            push    0x14
00760761  58               pop     eax
00760762  eb 02            jmp     0x760766
00760764  33 c0            xor     eax, eax
00760766  8b 96 04 04 00 00 mov     edx, dword [esi+0x404]
0076076c  6a 01            push    0x1
0076076e  66 c7 02 14 00   mov     word [edx], 0x14
00760773  8b 96 04 04 00 00 mov     edx, dword [esi+0x404]
00760779  66 c7 42 02 f8 03 mov     word [edx+0x2], 0x3f8
0076077f  8b 96 04 04 00 00 mov     edx, dword [esi+0x404]
00760785  89 42 04         mov     dword [edx+0x4], eax
00760788  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
0076078e  8b 55 0c         mov     edx, dword [ebp+0xc]
00760791  89 50 08         mov     dword [eax+0x8], edx
00760794  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
0076079a  89 78 0c         mov     dword [eax+0xc], edi
0076079d  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
007607a3  89 48 10         mov     dword [eax+0x10], ecx
007607a6  58               pop     eax
007607a7  eb 02            jmp     0x7607ab
007607a9  33 c0            xor     eax, eax
007607ab  5f               pop     edi
007607ac  5e               pop     esi
007607ad  5b               pop     ebx
007607ae  5d               pop     ebp
007607af  c2 10 00         retn    0x10
