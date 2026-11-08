0067272c  8d b3 18 03 00 00 lea     esi, [ebx+0x318]
00672732  8b ce            mov     ecx, esi
00672734  e8 b3 0b 0a 00   call    j_XteaProtectedInt_Get
00672739  8d 4e 1c         lea     ecx, [esi+0x1c]
0067273c  8b f8            mov     edi, eax
0067273e  e8 a9 0b 0a 00   call    j_XteaProtectedInt_Get
00672743  8b f0            mov     esi, eax
00672745  e8 3b df d9 ff   call    CGameMap_GetSingletonPtr
0067274a  6a 02            push    0x2
0067274c  56               push    esi
0067274d  57               push    edi
0067274e  8b c8            mov     ecx, eax
00672750  e8 b8 b8 fa ff   call    CGameMap_IsTileWithinScaledScreenBoundsWithMargin
00672755  85 c0            test    eax, eax
00672757  0f 84 ed 00 00 00 je      0x67284a
0067275d  80 bb a8 03 00 00 00 cmp     byte [ebx+0x3a8], 0x0
00672764  0f 85 e0 00 00 00 jne     0x67284a
0067276a  53               push    ebx
0067276b  e8 15 df d9 ff   call    CGameMap_GetSingletonPtr
00672770  8b c8            mov     ecx, eax
00672772  e8 d4 bf fa ff   call    CGameMap_NotifySceneryComponentSubcomponentUpdated
00672777  e9 ce 00 00 00   jmp     0x67284a
