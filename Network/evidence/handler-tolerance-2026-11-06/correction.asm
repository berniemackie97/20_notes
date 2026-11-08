006ff15d  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006ff163  6a 01            push    0x1
006ff165  5f               pop     edi
006ff166  b9 18 b0 96 00   mov     ecx, 0x96b018
006ff16b  57               push    edi
006ff16c  ff 70 04         push    dword [eax+0x4]
006ff16f  8d 45 dc         lea     eax, [ebp-0x24]
006ff172  50               push    eax
006ff173  e8 05 93 fe ff   call    EntityRef_ResolveByIdOrLocalHero  ; 5517 correction, 2026-10-05: packet+4 must RESOLVE via EntityRef_ResolveByIdOrLocalHero(0x6E847D,includeLocalHero=1); this accepts the local hero OR a matching role in the entity container, not only the local hero. Unresolved -> 0x700974 for 0x4B..0x4E/0x61/0xFB. Use the local hero ID for a bootstrap reply. Client 0xFB request has zero ID, so blindly echoing it fails this gate in a logged-in state.
006ff178  8b 4d dc         mov     ecx, dword [ebp-0x24]
006ff17b  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006ff181  3b cb            cmp     ecx, ebx
006ff183  c7 45 fc 05 00 00 00 mov     dword [ebp-0x4], 0x5
006ff18a  0f 85 a1 00 00 00 jne     0x6ff231
006ffcbf  8b b9 cc 00 00 00 mov     edi, dword [ecx+0xcc]
006ffcc5  e8 96 47 d0 ff   call    CHero_GetSingletonPtr
006ffcca  3b b8 cc 00 00 00 cmp     edi, dword [eax+0xcc]
006ffcd0  0f 85 9e 0c 00 00 jne     0x700974  ; CP2.4b: 108 resolved role (+0xCC) is not the hero -> jne 0x700974 = silent exit (unresolved ids already exit at the common gate). Hero path reads only packet +0x18/+0x1A (u16); +8/+0xC/+0x16/+0x1C/+0x20/+0x24/+0x25 are not read.
006ffcd6  e8 85 47 d0 ff   call    CHero_GetSingletonPtr
006ffcdb  8b 10            mov     edx, dword [eax]
006ffcdd  8d 4d e4         lea     ecx, [ebp-0x1c]
006ffce0  51               push    ecx
006ffce1  8b c8            mov     ecx, eax
006ffce3  ff 52 14         call    dword [edx+0x14]
006ffce6  8b b6 04 04 00 00 mov     esi, dword [esi+0x404]
006ffcec  0f b7 46 18      movzx   eax, word [esi+0x18]
006ffcf0  89 45 e4         mov     dword [ebp-0x1c], eax
006ffcf3  0f b7 46 1a      movzx   eax, word [esi+0x1a]
006ffcf7  89 45 e8         mov     dword [ebp-0x18], eax
006ffcfa  e8 61 47 d0 ff   call    CHero_GetSingletonPtr
006ffcff  8b c8            mov     ecx, eax
006ffd01  e8 9f ec f4 ff   call    Role_RecomputeCoordinateGateCacheFromProjectedPosition
006ffd06  e8 55 47 d0 ff   call    CHero_GetSingletonPtr
006ffd0b  8b c8            mov     ecx, eax
006ffd0d  e8 34 d0 db ff   call    NoOpFunction_Return_4BCD46
006ffd12  e8 49 47 d0 ff   call    CHero_GetSingletonPtr
006ffd17  ff 75 e8         push    dword [ebp-0x18]
006ffd1a  8b 10            mov     edx, dword [eax]
006ffd1c  8b c8            mov     ecx, eax
006ffd1e  ff 75 e4         push    dword [ebp-0x1c]
006ffd21  ff 52 18         call    dword [edx+0x18]
006ffd24  e8 37 47 d0 ff   call    CHero_GetSingletonPtr
006ffd29  ff 75 e8         push    dword [ebp-0x18]
006ffd2c  8b c8            mov     ecx, eax
006ffd2e  ff 75 e4         push    dword [ebp-0x1c]
006ffd31  e8 bd cd f5 ff   call    Role_UpdateCoordinateGateAndMapFromTilePair
006ffd36  8d 8d 30 f9 ff ff lea     ecx, [ebp-0x6d0]
006ffd3c  e8 62 eb ff ff   call    CMsgAction_Ctor
006ffd41  c6 45 fc 15      mov     byte [ebp-0x4], 0x15
006ffd45  e8 16 47 d0 ff   call    CHero_GetSingletonPtr
006ffd4a  8b b0 7c 01 00 00 mov     esi, dword [eax+0x17c]
006ffd50  e8 0b 47 d0 ff   call    CHero_GetSingletonPtr
006ffd55  8b b8 cc 00 00 00 mov     edi, dword [eax+0xcc]
006ffd5b  6a ff            push    0xffffffff
006ffd5d  e8 23 09 d1 ff   call    CGameMap_GetSingletonPtr
006ffd62  8b c8            mov     ecx, eax
006ffd64  e8 00 68 df ff   call    CGameMap_GetMapId
006ffd69  50               push    eax
006ffd6a  53               push    ebx
006ffd6b  ff 75 e8         push    dword [ebp-0x18]
006ffd6e  8d 8d 30 f9 ff ff lea     ecx, [ebp-0x6d0]
006ffd74  ff 75 e4         push    dword [ebp-0x1c]
006ffd77  68 92 00 00 00   push    0x92
006ffd7c  56               push    esi
006ffd7d  53               push    ebx
006ffd7e  53               push    ebx
006ffd7f  57               push    edi
006ffd80  e8 6e ec ff ff   call    CMsgAction_CreateExtended
006ffd85  85 c0            test    eax, eax
