0061d850  56               push    esi
0061d851  8b 74 24 08      mov     esi, dword [esp+0x8]
0061d855  57               push    edi
0061d856  8b 7c 24 10      mov     edi, dword [esp+0x10]
0061d85a  8b c6            mov     eax, esi
0061d85c  2b c7            sub     eax, edi
0061d85e  c1 e0 06         shl     eax, 0x6
0061d861  99               cdq
0061d862  2b c2            sub     eax, edx
0061d864  8b 54 24 14      mov     edx, dword [esp+0x14]
0061d868  d1 f8            sar     eax, 0x1
0061d86a  03 41 40         add     eax, dword [ecx+0x40]
0061d86d  89 02            mov     dword [edx], eax
0061d86f  8d 04 3e         lea     eax, [esi+edi]
0061d872  c1 e0 05         shl     eax, 0x5
0061d875  99               cdq
0061d876  2b c2            sub     eax, edx
0061d878  5f               pop     edi
0061d879  d1 f8            sar     eax, 0x1
0061d87b  03 41 44         add     eax, dword [ecx+0x44]
0061d87e  8b 4c 24 14      mov     ecx, dword [esp+0x14]
0061d882  5e               pop     esi
0061d883  89 01            mov     dword [ecx], eax
0061d885  c2 10 00         retn    0x10
