00651875  56               push    esi  ; Role vtable +0x14 - the tile coordinate pair getter the scenery depth ordering reads. Returns two XTEA-protected ints via j_XteaProtectedInt_Get into outPair[0] and outPair[1].
00651876  8d b1 18 03 00 00 lea     esi, [ecx+0x318]
0065187c  57               push    edi
0065187d  8b ce            mov     ecx, esi
0065187f  e8 68 1a 0c 00   call    j_XteaProtectedInt_Get
00651884  8d 4e 1c         lea     ecx, [esi+0x1c]
00651887  8b f8            mov     edi, eax
00651889  e8 5e 1a 0c 00   call    j_XteaProtectedInt_Get
0065188e  8b 4c 24 0c      mov     ecx, dword [esp+0xc]
00651892  89 39            mov     dword [ecx], edi
00651894  5f               pop     edi
00651895  89 41 04         mov     dword [ecx+0x4], eax
00651898  5e               pop     esi
00651899  c2 04 00         retn    0x4
