00740602  0f b6 41 04      movzx   eax, byte [ecx+0x4]
00740606  80 79 0c 09      cmp     byte [ecx+0xc], 0x9
0074060a  99               cdq
0074060b  74 32            je      0x74063f  ; Full-width selector branch: compare packet +0x0C as uint32_t to exactly 9. Only exact raw value 9 selects the 24-direction path.
0074060d  6a 08            push    0x8
0074060f  5f               pop     edi
00740610  f7 ff            idiv    edi
00740612  88 51 04         mov     byte [ecx+0x4], dl
00740615  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
0074061b  0f b6 48 04      movzx   ecx, byte [eax+0x4]
0074061f  c1 e1 02         shl     ecx, 0x2
00740622  8b b9 c4 c7 86 00 mov     edi, dword [ecx+0x86c7c4]
00740628  8b 99 e4 c7 86 00 mov     ebx, dword [ecx+0x86c7e4]
0074062e  8a 48 0c         mov     cl, byte [eax+0xc]  ; Non-9 selector split: command type 0x17 only when the low byte of packet +0x0C equals 1; every other non-9 raw value selects type 0x16.
007406c1  e8 26 2c fd ff   call    j_XteaProtectedInt_Get
007406c6  8d 4e 1c         lea     ecx, [esi+0x1c]
007406c9  89 45 e4         mov     dword [ebp-0x1c], eax
007406cc  e8 1b 2c fd ff   call    j_XteaProtectedInt_Get
007406d1  8b f0            mov     esi, eax
007406d3  e8 88 3d cc ff   call    CHero_GetSingletonPtr
007406d8  8b 4d e4         mov     ecx, dword [ebp-0x1c]
007406db  03 f3            add     esi, ebx
007406dd  03 cf            add     ecx, edi
007406df  56               push    esi
007406e0  51               push    ecx
007406e1  8b c8            mov     ecx, eax
007406e3  e8 0b c4 f1 ff   call    Role_UpdateCoordinateGateAndMapFromTilePair
007406e8  e9 29 01 00 00   jmp     0x740816
