00650903  55               push    ebp
00650904  8b ec            mov     ebp, esp
00650906  51               push    ecx
00650907  51               push    ecx
00650908  56               push    esi
00650909  57               push    edi
0065090a  8b f1            mov     esi, ecx
0065090c  e8 72 fc ff ff   call    Role_GetMotionArcScreenHeightAnchor
00650911  8b f8            mov     edi, eax
00650913  e8 6d fd db ff   call    CGameMap_GetSingletonPtr
00650918  8d 4d fc         lea     ecx, [ebp-0x4]
0065091b  51               push    ecx
0065091c  8d 4d f8         lea     ecx, [ebp-0x8]
0065091f  51               push    ecx
00650920  8b c8            mov     ecx, eax
00650922  ff b6 54 03 00 00 push    dword [esi+0x354]
00650928  ff b6 50 03 00 00 push    dword [esi+0x350]
0065092e  e8 d4 cd fc ff   call    CGameMap_ProjectScreenPointToTileCoordinatesUnchecked
00650933  e8 4d fd db ff   call    CGameMap_GetSingletonPtr
00650938  ff 75 fc         push    dword [ebp-0x4]
0065093b  8b c8            mov     ecx, eax
0065093d  ff 75 f8         push    dword [ebp-0x8]
00650940  e8 83 d0 fc ff   call    Map_GetTileEntryByCoordinates
00650945  8b f0            mov     esi, eax
00650947  85 f6            test    esi, esi
00650949  74 31            je      0x65097c
0065094b  53               push    ebx
0065094c  e8 34 fd db ff   call    CGameMap_GetSingletonPtr
00650951  56               push    esi
00650952  8b d8            mov     ebx, eax
00650954  e8 2c fd db ff   call    CGameMap_GetSingletonPtr
00650959  8b c8            mov     ecx, eax
0065095b  e8 65 e2 fc ff   call    MapTileEntry_GetTailLinkElevation
00650960  ff 75 fc         push    dword [ebp-0x4]
00650963  8b f0            mov     esi, eax
00650965  8b cb            mov     ecx, ebx
00650967  2b f7            sub     esi, edi
00650969  ff 75 f8         push    dword [ebp-0x8]
0065096c  e8 fd de fc ff   call    Map_GetBaseTileElevationByCoordinates
00650971  2b f0            sub     esi, eax
00650973  5b               pop     ebx
00650974  85 f6            test    esi, esi
00650976  7e 02            jle     0x65097a
00650978  33 f6            xor     esi, esi
0065097a  8b c6            mov     eax, esi
0065097c  5f               pop     edi
0065097d  5e               pop     esi
0065097e  c9               leave
0065097f  c3               retn
