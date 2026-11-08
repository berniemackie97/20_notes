0061e74b  83 7c 24 04 00   cmp     dword [esp+0x4], 0x0
0061e750  74 14            je      0x61e766
0061e752  e8 93 ee ff ff   call    CGameMap_FindFirstComponentWithTypeCode3
0061e757  85 c0            test    eax, eax
0061e759  74 0b            je      0x61e766
0061e75b  ff 74 24 04      push    dword [esp+0x4]
0061e75f  8b c8            mov     ecx, eax
0061e761  e8 80 73 01 00   call    CMapSceneryComponent_ReorderSubcomponentForDepth
0061e766  c2 04 00         retn    0x4
