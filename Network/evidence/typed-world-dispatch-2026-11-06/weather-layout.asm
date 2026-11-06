00760683  c7 06 e0 d4 86 00 mov     dword [esi], 0x86d4e0
00760689  e8 f3 eb f7 ff   call    CNetMsg__ResetPacketBuffer
0076068e  8b 4d f4         mov     ecx, dword [ebp-0xc]
00760691  8d 46 04         lea     eax, [esi+0x4]
00760694  89 86 04 04 00 00 mov     dword [esi+0x404], eax
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
00760804  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
0076080a  ff 70 10         push    dword [eax+0x10]
0076080d  ff 70 0c         push    dword [eax+0xc]
00760810  ff 70 08         push    dword [eax+0x8]
00760813  ff 70 04         push    dword [eax+0x4]
00760816  e8 b2 fe ff ff   call    CMsgWeatherUpdate__ValidateAndNormalize
0076081b  85 c0            test    eax, eax
0076081d  74 63            je      0x760882
