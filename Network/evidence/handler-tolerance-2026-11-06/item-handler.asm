# CMsg1008__Process; CP2.4b static clean5517 Binary Ninja excerpt
00762d75  e8 9f e1 ca ff   call    SharedPtr_ReleaseControlBlockSlot
00762d7a  e9 49 12 00 00   jmp     0x763fc8
00762d7f  68 ec 01 00 00   push    0x1ec
00762d84  e8 eb 44 01 00   call    ??2@YAPAXI@Z
00762d89  59               pop     ecx
00762d8a  8b c8            mov     ecx, eax
00762d8c  89 4d ec         mov     dword [ebp-0x14], ecx
00762d8f  33 db            xor     ebx, ebx
00762d91  c7 45 fc 04 00 00 00 mov     dword [ebp-0x4], 0x4
00762d98  3b cb            cmp     ecx, ebx
00762d9a  74 0a            je      0x762da6
00762d9c  e8 56 79 f1 ff   call    0x67a6f7
00762da1  89 45 ec         mov     dword [ebp-0x14], eax
00762da4  eb 03            jmp     0x762da9
00762da6  89 5d ec         mov     dword [ebp-0x14], ebx
00762da9  8b 45 ec         mov     eax, dword [ebp-0x14]
00762dac  83 cf ff         or      edi, 0xffffffff
00762daf  50               push    eax
00762db0  8d 4d e8         lea     ecx, [ebp-0x18]
00762db3  89 7d fc         mov     dword [ebp-0x4], edi
00762db6  89 45 e4         mov     dword [ebp-0x1c], eax
00762db9  e8 41 ae cc ff   call    0x42dbff
00762dbe  ff 75 ec         push    dword [ebp-0x14]
00762dc1  8d 45 e8         lea     eax, [ebp-0x18]
00762dc4  c7 45 fc 05 00 00 00 mov     dword [ebp-0x4], 0x5
00762dcb  ff 75 ec         push    dword [ebp-0x14]
00762dce  50               push    eax
00762dcf  e8 8f c4 f4 ff   call    NoOpFunction_Return
00762dd4  83 c4 0c         add     esp, 0xc
00762dd7  8b 4d e4         mov     ecx, dword [ebp-0x1c]
00762dda  c7 45 fc 06 00 00 00 mov     dword [ebp-0x4], 0x6
00762de1  3b cb            cmp     ecx, ebx
00762de3  0f 84 b6 02 00 00 je      0x76309f
00762de9  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
00762def  ff 70 08         push    dword [eax+0x8]
00762df2  ff 70 04         push    dword [eax+0x4]
00762df5  e8 71 7f f1 ff   call    CItem_InitIdentityFromItemType
00762dfa  85 c0            test    eax, eax
00762dfc  0f 84 9d 02 00 00 je      0x76309f  ; CP2.4b: 1008 kind 1 create - CItem init sub_67ad6b fails for UID 0, type 0 or ItemType.dat miss -> release item and return. No add, no post, no disconnect.
00762e02  8b 4d e4         mov     ecx, dword [ebp-0x1c]
00762e05  e8 f5 99 f1 ff   call    CItem__IsEquipmentCategory
00763570  e8 eb 0e ca ff   call    CHero_GetSingletonPtr
00763575  8b 8e 04 04 00 00 mov     ecx, dword [esi+0x404]
0076357b  33 db            xor     ebx, ebx
0076357d  53               push    ebx
0076357e  ff 71 04         push    dword [ecx+0x4]
00763581  8d 4d e4         lea     ecx, [ebp-0x1c]
00763584  51               push    ecx
00763585  8b c8            mov     ecx, eax
00763587  e8 bf 5c f7 ff   call    CHeroItem__FindItemByUid
0076358c  39 5d e4         cmp     dword [ebp-0x1c], ebx
0076358f  c7 45 fc 11 00 00 00 mov     dword [ebp-0x4], 0x11
00763596  75 4c            jne     0x7635e4
00763598  e8 c3 0e ca ff   call    CHero_GetSingletonPtr
0076359d  8b 8e 04 04 00 00 mov     ecx, dword [esi+0x404]
007635a3  ff 71 04         push    dword [ecx+0x4]
007635a6  8d 4d d4         lea     ecx, [ebp-0x2c]
007635a9  51               push    ecx
007635aa  8b c8            mov     ecx, eax
007635ac  e8 f2 85 f7 ff   call    CHeroItem__FindTrackedItemByUid
007635b1  8b 08            mov     ecx, dword [eax]
007635b3  83 c0 04         add     eax, 0x4
007635b6  89 4d e4         mov     dword [ebp-0x1c], ecx
007635b9  50               push    eax
007635ba  8d 4d e8         lea     ecx, [ebp-0x18]
007635bd  c6 45 fc 12      mov     byte [ebp-0x4], 0x12
007635c1  e8 5f d9 ca ff   call    0x410f25
007635c6  8b 4d d8         mov     ecx, dword [ebp-0x28]
007635c9  c6 45 fc 11      mov     byte [ebp-0x4], 0x11
007635cd  3b cb            cmp     ecx, ebx
007635cf  74 05            je      0x7635d6
007635d1  e8 0e 17 ca ff   call    SharedPtrControlBlock_DecrementStrongReference
007635d6  39 5d e4         cmp     dword [ebp-0x1c], ebx
007635d9  75 09            jne     0x7635e4
007635db  83 4d fc ff      or      dword [ebp-0x4], 0xffffffff
007635df  e9 c6 02 00 00   jmp     0x7638aa
007635e4  8b 4d e4         mov     ecx, dword [ebp-0x1c]
007635e7  88 5d f3         mov     byte [ebp-0xd], bl
007635ea  e8 0e 95 f1 ff   call    CItem_PassesUnlockedEquipmentScoreThreshold
007635ef  84 c0            test    al, al
007635f1  75 04            jne     0x7635f7
007635f3  c6 45 f3 01      mov     byte [ebp-0xd], 0x1
007635f7  8b 7d e4         mov     edi, dword [ebp-0x1c]
007635fa  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
00763600  8b 57 1c         mov     edx, dword [edi+0x1c]
00763603  8b 48 08         mov     ecx, dword [eax+0x8]
00763606  3b d1            cmp     edx, ecx
00763608  74 0f            je      0x763619
0076360a  51               push    ecx
0076360b  8b cf            mov     ecx, edi
0076360d  ff 70 04         push    dword [eax+0x4]
00763610  e8 56 77 f1 ff   call    CItem_InitIdentityFromItemType
00763615  85 c0            test    eax, eax
00763617  74 c2            je      0x7635db  ; CP2.4b: 1008 kind 3 update - existing item found by UID; a changed type re-runs init sub_67ad6b, and failure skips the update. Unknown UID already skipped at 0x763596.
00763619  8b 4d e4         mov     ecx, dword [ebp-0x1c]
0076361c  e8 de 91 f1 ff   call    CItem__IsEquipmentCategory
007637e6  e8 2a 98 ee ff   call    Conquer_PostMainWindowMessage464
007637eb  59               pop     ecx
007637ec  59               pop     ecx
007637ed  e8 6e 0c ca ff   call    CHero_GetSingletonPtr
007637f2  8b 8e 04 04 00 00 mov     ecx, dword [esi+0x404]
007637f8  6a 01            push    0x1  ; CP2.4b: kind 3 placement test - FindItemByUid flag 1 (inventory only). In inventory -> post 0x3EB only, +0x12 ignored. Otherwise (tracked) -> TrackItemAtPosition(+0x12) at 0x763867, a no-op for positions outside 1..18/21..29.
007637fa  ff 71 04         push    dword [ecx+0x4]
007637fd  8d 4d cc         lea     ecx, [ebp-0x34]
00763800  51               push    ecx
00763801  8b c8            mov     ecx, eax
00763803  e8 43 5a f7 ff   call    CHeroItem__FindItemByUid
00763808  39 18            cmp     dword [eax], ebx
0076380a  8b 4d d0         mov     ecx, dword [ebp-0x30]
0076380d  0f 95 45 f3      setne   byte [ebp-0xd]
00763811  3b cb            cmp     ecx, ebx
00763813  74 05            je      0x76381a
00763815  e8 ca 14 ca ff   call    SharedPtrControlBlock_DecrementStrongReference
0076381a  38 5d f3         cmp     byte [ebp-0xd], bl
0076381d  74 0f            je      0x76382e
0076381f  53               push    ebx
00763820  68 eb 03 00 00   push    0x3eb
00763825  e8 eb 97 ee ff   call    Conquer_PostMainWindowMessage464
0076382a  59               pop     ecx
0076382b  59               pop     ecx
0076382c  eb 79            jmp     0x7638a7
0076382e  51               push    ecx
0076382f  51               push    ecx
00763830  8b 4d e4         mov     ecx, dword [ebp-0x1c]
00763833  8b c4            mov     eax, esp
00763835  89 65 ec         mov     dword [ebp-0x14], esp
00763838  89 08            mov     dword [eax], ecx
0076383a  8b 4d e8         mov     ecx, dword [ebp-0x18]
0076383d  89 48 04         mov     dword [eax+0x4], ecx
00763840  8b 45 e8         mov     eax, dword [ebp-0x18]
00763843  3b c3            cmp     eax, ebx
00763845  74 0a            je      0x763851
00763847  6a 01            push    0x1
00763849  83 c0 04         add     eax, 0x4
0076384c  59               pop     ecx
0076384d  f0 0f c1 08      lock xadd dword [eax], ecx
00763851  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
00763857  c6 45 fc 11      mov     byte [ebp-0x4], 0x11
0076385b  0f b6 40 12      movzx   eax, byte [eax+0x12]
0076385f  50               push    eax
00763860  e8 23 07 ca ff   call    j_CHero_GetSingletonPtr
00763865  8b c8            mov     ecx, eax
00763867  e8 b5 77 f7 ff   call    CHeroItem__TrackItemAtPosition
0076386c  e8 ef 0b ca ff   call    CHero_GetSingletonPtr
00763871  8b c8            mov     ecx, eax
00763873  e8 57 eb ef ff   call    CHero__RefreshEquipmentDerivedStats
