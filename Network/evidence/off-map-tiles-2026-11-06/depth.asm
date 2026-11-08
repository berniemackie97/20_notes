00635ae6  b8 37 c7 81 00   mov     eax, 0x81c737  ; Depth insert of child N into active render deque +0x74 (see 20_notes Game_Map/world_render_contract_5517.md). 1) N.type!=2: first active type-2 E whose footprint contains N.tile adopts N (InsertChildForDepth). 2) Walk active list: x-overlap([x-w+1,x]) -> if N.y<E.y backward-insert else extend insert-after cursor; y-overlap -> if N.x<E.x backward-insert else extend cursor. Cursor scans stop at first element whose x+y differs from E and >= / <= N.x+N.y. 3) No cursor: insert before first E with N.x+N.y < E.x+E.y, else push back.
00635aeb  e8 60 1b 14 00   call    __EH_prolog
00635af0  81 ec b4 00 00 00 sub     esp, 0xb4
00635af6  53               push    ebx
00635af7  56               push    esi
00635af8  33 f6            xor     esi, esi
00635afa  57               push    edi
00635afb  39 75 08         cmp     dword [ebp+0x8], esi
00635afe  89 65 f0         mov     dword [ebp-0x10], esp
00635b01  0f 84 a3 04 00 00 je      0x635faa
00635b07  83 c1 74         add     ecx, 0x74
00635b0a  89 4d ec         mov     dword [ebp-0x14], ecx
00635b0d  e8 34 6d 10 00   call    0x73c846
00635b12  8b 4d 08         mov     ecx, dword [ebp+0x8]
00635b15  89 45 dc         mov     dword [ebp-0x24], eax
00635b18  8b 01            mov     eax, dword [ecx]  ; vtable +0x0C is the subcomponent TYPE CODE getter, compared against 2 here and at 0x635B58.
00635b1a  ff 50 0c         call    dword [eax+0xc]
00635b1d  83 f8 02         cmp     eax, 0x2
00635b20  0f 84 a9 00 00 00 je      0x635bcf
00635b26  89 75 fc         mov     dword [ebp-0x4], esi
00635b29  89 75 e8         mov     dword [ebp-0x18], esi
00635b2c  8b 45 e8         mov     eax, dword [ebp-0x18]
00635b2f  3b 45 dc         cmp     eax, dword [ebp-0x24]
00635b32  0f 83 91 00 00 00 jae     0x635bc9
00635b38  8b 75 ec         mov     esi, dword [ebp-0x14]
00635b3b  8d 7d a0         lea     edi, [ebp-0x60]
00635b3e  a5               movsd   dword [edi], [esi]
00635b3f  a5               movsd   dword [edi], [esi]
00635b40  a5               movsd   dword [edi], [esi]
00635b41  50               push    eax
00635b42  8d 4d a0         lea     ecx, [ebp-0x60]
00635b45  a5               movsd   dword [edi], [esi]
00635b46  e8 b4 22 00 00   call    StdDequePtr_AdvanceIteratorByOffset
00635b4b  8b 45 a0         mov     eax, dword [ebp-0x60]
00635b4e  8b 18            mov     ebx, dword [eax]
00635b50  85 db            test    ebx, ebx
00635b52  74 67            je      0x635bbb
00635b54  8b 03            mov     eax, dword [ebx]
00635b56  8b cb            mov     ecx, ebx
00635b58  ff 50 0c         call    dword [eax+0xc]
00635b5b  83 f8 02         cmp     eax, 0x2
00635b5e  75 5b            jne     0x635bbb
00635b60  8b 4d 08         mov     ecx, dword [ebp+0x8]
00635b63  8d 55 c0         lea     edx, [ebp-0x40]
00635b66  52               push    edx
00635b67  8b 01            mov     eax, dword [ecx]
00635b69  ff 50 14         call    dword [eax+0x14]
00635b6c  ff 75 c4         push    dword [ebp-0x3c]
00635b6f  8b cb            mov     ecx, ebx
00635b71  ff 75 c0         push    dword [ebp-0x40]
00635b74  e8 95 f2 00 00   call    CMapSceneryType2Subcomponent_FootprintContainsTile
00635b79  85 c0            test    eax, eax
00635b7b  74 3e            je      0x635bbb
00635b7d  8b 4d 08         mov     ecx, dword [ebp+0x8]
00635b80  51               push    ecx
00635b81  51               push    ecx
00635b82  8b c4            mov     eax, esp
00635b84  89 65 cc         mov     dword [ebp-0x34], esp
00635b87  8b f9            mov     edi, ecx
00635b89  89 45 cc         mov     dword [ebp-0x34], eax
00635b8c  89 08            mov     dword [eax], ecx
00635b8e  ff 75 08         push    dword [ebp+0x8]
00635b91  8d 70 04         lea     esi, [eax+0x4]
00635b94  57               push    edi
00635b95  8b ce            mov     ecx, esi
00635b97  e8 cb 12 00 00   call    SharedPtrCMapObj_CreateNonOwningControlBlock
00635b9c  57               push    edi
00635b9d  57               push    edi
00635b9e  56               push    esi
00635b9f  c6 45 fc 01      mov     byte [ebp-0x4], 0x1
00635ba3  e8 bb 96 07 00   call    NoOpFunction_Return
00635ba8  80 65 fc 00      and     byte [ebp-0x4], 0x0
00635bac  83 c4 0c         add     esp, 0xc
00635baf  8b cb            mov     ecx, ebx
00635bb1  e8 f3 ef 00 00   call    CMapSceneryType2Subcomponent_InsertChildForDepth
00635bb6  e9 ef 03 00 00   jmp     0x635faa
00635bbb  ff 45 e8         inc     dword [ebp-0x18]
00635bbe  e9 69 ff ff ff   jmp     0x635b2c
00635bc9  83 4d fc ff      or      dword [ebp-0x4], 0xffffffff
00635bcd  33 f6            xor     esi, esi
00635bcf  8b 4d 08         mov     ecx, dword [ebp+0x8]
00635bd2  8d 55 98         lea     edx, [ebp-0x68]
00635bd5  52               push    edx
00635bd6  8b 01            mov     eax, dword [ecx]
00635bd8  ff 50 14         call    dword [eax+0x14]
00635bdb  8b 45 98         mov     eax, dword [ebp-0x68]
00635bde  83 4d d0 ff      or      dword [ebp-0x30], 0xffffffff
00635be2  39 75 dc         cmp     dword [ebp-0x24], esi
00635be5  89 45 d8         mov     dword [ebp-0x28], eax
00635be8  8b 45 9c         mov     eax, dword [ebp-0x64]
00635beb  89 75 e8         mov     dword [ebp-0x18], esi
00635bee  89 45 d4         mov     dword [ebp-0x2c], eax
00635bf1  0f 86 32 02 00 00 jbe     0x635e29
00635bf7  8b 75 ec         mov     esi, dword [ebp-0x14]
00635bfa  8d bd 60 ff ff ff lea     edi, [ebp-0xa0]
00635c00  a5               movsd   dword [edi], [esi]
00635c01  a5               movsd   dword [edi], [esi]
00635c02  ff 75 e8         push    dword [ebp-0x18]
00635c05  8d 8d 60 ff ff ff lea     ecx, [ebp-0xa0]
00635c0b  a5               movsd   dword [edi], [esi]
00635c0c  a5               movsd   dword [edi], [esi]
00635c0d  e8 ed 21 00 00   call    StdDequePtr_AdvanceIteratorByOffset
00635c12  8b 85 60 ff ff ff mov     eax, dword [ebp-0xa0]
00635c18  8d 8d 70 ff ff ff lea     ecx, [ebp-0x90]
00635c1e  51               push    ecx
00635c1f  8b 30            mov     esi, dword [eax]
00635c21  8b ce            mov     ecx, esi
00635c23  8b 06            mov     eax, dword [esi]
00635c25  ff 50 14         call    dword [eax+0x14]
00635c28  8b bd 74 ff ff ff mov     edi, dword [ebp-0x8c]
00635c2e  8b 9d 70 ff ff ff mov     ebx, dword [ebp-0x90]
00635c34  8d 45 80         lea     eax, [ebp-0x80]
00635c37  56               push    esi
00635c38  50               push    eax
00635c39  89 7d c4         mov     dword [ebp-0x3c], edi
00635c3c  e8 44 aa dd ff   call    CGameMap_GetSingletonPtr
00635c41  8b c8            mov     ecx, eax
00635c43  e8 74 84 fe ff   call    CGameMap_GetType3SubcomponentDepthSpanOrDefault
00635c48  e8 38 aa dd ff   call    CGameMap_GetSingletonPtr
00635c4d  ff 75 08         push    dword [ebp+0x8]
00635c50  8d 8d 78 ff ff ff lea     ecx, [ebp-0x88]
00635c56  51               push    ecx
00635c57  8b c8            mov     ecx, eax
00635c59  e8 5e 84 fe ff   call    CGameMap_GetType3SubcomponentDepthSpanOrDefault
00635c5e  8b 45 d8         mov     eax, dword [ebp-0x28]
00635c61  2b 85 78 ff ff ff sub     eax, dword [ebp-0x88]
00635c67  2b c3            sub     eax, ebx
00635c69  40               inc     eax
00635c6a  85 c0            test    eax, eax
00635c6c  7f 7f            jg      0x635ced
00635c6e  8b c3            mov     eax, ebx
00635c70  2b 45 80         sub     eax, dword [ebp-0x80]
00635c73  2b 45 d8         sub     eax, dword [ebp-0x28]
00635c76  40               inc     eax
00635c77  85 c0            test    eax, eax
00635c79  7f 72            jg      0x635ced
00635c7b  39 7d d4         cmp     dword [ebp-0x2c], edi
00635c7e  8b 45 e8         mov     eax, dword [ebp-0x18]
00635c81  0f 8c 08 01 00 00 jl      0x635d8f
00635c87  89 45 d0         mov     dword [ebp-0x30], eax
00635c8a  40               inc     eax
00635c8b  89 45 e4         mov     dword [ebp-0x1c], eax
00635c8e  3b 45 dc         cmp     eax, dword [ebp-0x24]
00635c91  0f 8d e1 00 00 00 jge     0x635d78
00635c97  8b 75 ec         mov     esi, dword [ebp-0x14]
00635c9a  8d 7d 88         lea     edi, [ebp-0x78]
00635c9d  a5               movsd   dword [edi], [esi]
00635c9e  a5               movsd   dword [edi], [esi]
00635c9f  ff 75 e4         push    dword [ebp-0x1c]
00635ca2  8d 4d 88         lea     ecx, [ebp-0x78]
00635ca5  a5               movsd   dword [edi], [esi]
00635ca6  a5               movsd   dword [edi], [esi]
00635ca7  e8 53 21 00 00   call    StdDequePtr_AdvanceIteratorByOffset
00635cac  8b 45 88         mov     eax, dword [ebp-0x78]
00635caf  8b 08            mov     ecx, dword [eax]
00635cb1  85 c9            test    ecx, ecx
00635cb3  74 30            je      0x635ce5
00635cb5  8b 01            mov     eax, dword [ecx]
00635cb7  8d 55 c8         lea     edx, [ebp-0x38]
00635cba  52               push    edx
00635cbb  ff 50 14         call    dword [eax+0x14]
00635cbe  8b 45 c8         mov     eax, dword [ebp-0x38]
00635cc1  8b 4d cc         mov     ecx, dword [ebp-0x34]
00635cc4  03 c1            add     eax, ecx
00635cc6  8b 4d c4         mov     ecx, dword [ebp-0x3c]
00635cc9  03 cb            add     ecx, ebx
00635ccb  3b c8            cmp     ecx, eax
00635ccd  74 10            je      0x635cdf
00635ccf  8b 4d d4         mov     ecx, dword [ebp-0x2c]
00635cd2  8b 55 d8         mov     edx, dword [ebp-0x28]
00635cd5  03 ca            add     ecx, edx
00635cd7  3b c8            cmp     ecx, eax
00635cd9  0f 8e 99 00 00 00 jle     0x635d78
00635cdf  8b 45 e4         mov     eax, dword [ebp-0x1c]
00635ce2  89 45 d0         mov     dword [ebp-0x30], eax
00635ce5  ff 45 e4         inc     dword [ebp-0x1c]
00635ce8  8b 45 e4         mov     eax, dword [ebp-0x1c]
00635ceb  eb a1            jmp     0x635c8e
00635ced  8b 45 d4         mov     eax, dword [ebp-0x2c]
00635cf0  2b 85 7c ff ff ff sub     eax, dword [ebp-0x84]
00635cf6  2b c7            sub     eax, edi
00635cf8  40               inc     eax
00635cf9  85 c0            test    eax, eax
00635cfb  7f 7b            jg      0x635d78
00635cfd  2b 7d 84         sub     edi, dword [ebp-0x7c]
00635d00  2b 7d d4         sub     edi, dword [ebp-0x2c]
00635d03  47               inc     edi
00635d04  85 ff            test    edi, edi
00635d06  7f 70            jg      0x635d78
00635d08  39 5d d8         cmp     dword [ebp-0x28], ebx
00635d0b  8b 45 e8         mov     eax, dword [ebp-0x18]
00635d0e  0f 8c 68 01 00 00 jl      0x635e7c
00635d14  89 45 d0         mov     dword [ebp-0x30], eax
00635d17  40               inc     eax
00635d18  3b 45 dc         cmp     eax, dword [ebp-0x24]
00635d1b  89 45 e4         mov     dword [ebp-0x1c], eax
00635d1e  7d 58            jge     0x635d78
00635d20  eb 03            jmp     0x635d25
00635d22  8b 45 e4         mov     eax, dword [ebp-0x1c]
00635d25  8b 75 ec         mov     esi, dword [ebp-0x14]
00635d28  8d 7d b0         lea     edi, [ebp-0x50]
00635d2b  a5               movsd   dword [edi], [esi]
00635d2c  a5               movsd   dword [edi], [esi]
00635d2d  a5               movsd   dword [edi], [esi]
00635d2e  50               push    eax
00635d2f  8d 4d b0         lea     ecx, [ebp-0x50]
00635d32  a5               movsd   dword [edi], [esi]
00635d33  e8 c7 20 00 00   call    StdDequePtr_AdvanceIteratorByOffset
00635d38  8b 45 b0         mov     eax, dword [ebp-0x50]
00635d3b  8b 08            mov     ecx, dword [eax]
00635d3d  85 c9            test    ecx, ecx
00635d3f  74 2c            je      0x635d6d
00635d41  8b 01            mov     eax, dword [ecx]
00635d43  8d 55 a8         lea     edx, [ebp-0x58]
00635d46  52               push    edx
00635d47  ff 50 14         call    dword [eax+0x14]
00635d4a  8b 45 a8         mov     eax, dword [ebp-0x58]
00635d4d  8b 4d ac         mov     ecx, dword [ebp-0x54]
00635d50  03 c1            add     eax, ecx
00635d52  8b 4d c4         mov     ecx, dword [ebp-0x3c]
00635d55  03 cb            add     ecx, ebx
00635d57  3b c8            cmp     ecx, eax
00635d59  74 0c            je      0x635d67
00635d5b  8b 4d d4         mov     ecx, dword [ebp-0x2c]
00635d5e  8b 55 d8         mov     edx, dword [ebp-0x28]
00635d61  03 ca            add     ecx, edx
00635d63  3b c8            cmp     ecx, eax
00635d65  7e 11            jle     0x635d78
00635d67  8b 45 e4         mov     eax, dword [ebp-0x1c]
00635d6a  89 45 d0         mov     dword [ebp-0x30], eax
00635d6d  ff 45 e4         inc     dword [ebp-0x1c]
00635d70  8b 45 e4         mov     eax, dword [ebp-0x1c]
00635d73  3b 45 dc         cmp     eax, dword [ebp-0x24]
00635d76  7c aa            jl      0x635d22
00635d78  ff 45 e8         inc     dword [ebp-0x18]
00635d7b  8b 45 e8         mov     eax, dword [ebp-0x18]
00635d7e  3b 45 dc         cmp     eax, dword [ebp-0x24]
00635d81  0f 82 70 fe ff ff jb      0x635bf7
00635d87  8b 75 d0         mov     esi, dword [ebp-0x30]
00635d8a  e9 7e 01 00 00   jmp     0x635f0d
00635d8f  89 45 cc         mov     dword [ebp-0x34], eax
00635d92  48               dec     eax
00635d93  85 c0            test    eax, eax
00635d95  89 45 e4         mov     dword [ebp-0x1c], eax
00635d98  7c 54            jl      0x635dee
00635d9a  8b 75 ec         mov     esi, dword [ebp-0x14]
00635d9d  8d 7d b0         lea     edi, [ebp-0x50]
00635da0  a5               movsd   dword [edi], [esi]
00635da1  a5               movsd   dword [edi], [esi]
00635da2  ff 75 e4         push    dword [ebp-0x1c]
00635da5  8d 4d b0         lea     ecx, [ebp-0x50]
00635da8  a5               movsd   dword [edi], [esi]
00635da9  a5               movsd   dword [edi], [esi]
00635daa  e8 50 20 00 00   call    StdDequePtr_AdvanceIteratorByOffset
00635daf  8b 45 b0         mov     eax, dword [ebp-0x50]
00635db2  8b 08            mov     ecx, dword [eax]
00635db4  85 c9            test    ecx, ecx
00635db6  74 31            je      0x635de9
00635db8  8b 01            mov     eax, dword [ecx]
00635dba  8d 55 a8         lea     edx, [ebp-0x58]
00635dbd  52               push    edx
00635dbe  ff 50 14         call    dword [eax+0x14]
00635dc1  8b 45 a8         mov     eax, dword [ebp-0x58]
00635dc4  8b 4d ac         mov     ecx, dword [ebp-0x54]
00635dc7  03 c1            add     eax, ecx
00635dc9  8b 4d c4         mov     ecx, dword [ebp-0x3c]
00635dcc  03 cb            add     ecx, ebx
00635dce  3b c8            cmp     ecx, eax
00635dd0  74 0c            je      0x635dde
00635dd2  8b 4d d4         mov     ecx, dword [ebp-0x2c]
00635dd5  8b 55 d8         mov     edx, dword [ebp-0x28]
00635dd8  03 ca            add     ecx, edx
00635dda  3b c8            cmp     ecx, eax
00635ddc  7d 10            jge     0x635dee
00635dde  8b 45 e4         mov     eax, dword [ebp-0x1c]
00635de1  3b 45 d0         cmp     eax, dword [ebp-0x30]
00635de4  7e 08            jle     0x635dee
00635de6  89 45 cc         mov     dword [ebp-0x34], eax
00635de9  ff 4d e4         dec     dword [ebp-0x1c]
00635dec  79 ac            jns     0x635d9a
00635dee  8d 45 08         lea     eax, [ebp+0x8]
00635df1  8b 4d ec         mov     ecx, dword [ebp-0x14]
00635df4  50               push    eax
00635df5  83 ec 10         sub     esp, 0x10
00635df8  8b c4            mov     eax, esp
00635dfa  89 65 c4         mov     dword [ebp-0x3c], esp
00635dfd  ff 75 cc         push    dword [ebp-0x34]
00635e00  50               push    eax
00635e01  8d 45 b0         lea     eax, [ebp-0x50]
00635e04  50               push    eax
00635e05  e8 15 b6 fe ff   call    StdDequePtr_CopyBeginIterator
00635e0a  8b c8            mov     ecx, eax
00635e0c  e8 35 b7 fe ff   call    StdDequePtr_IteratorPlusOffset
00635e11  8b 4d ec         mov     ecx, dword [ebp-0x14]
00635e14  8d 45 88         lea     eax, [ebp-0x78]
00635e17  50               push    eax
00635e18  e8 14 05 00 00   call    StdDequePtr_Insert
00635e1d  8b 45 e8         mov     eax, dword [ebp-0x18]
00635e20  3b 45 dc         cmp     eax, dword [ebp-0x24]
00635e23  0f 82 81 01 00 00 jb      0x635faa
00635e29  33 db            xor     ebx, ebx
00635e2b  39 5d dc         cmp     dword [ebp-0x24], ebx
00635e2e  0f 8e 6a 01 00 00 jle     0x635f9e
00635e34  8b 75 ec         mov     esi, dword [ebp-0x14]
00635e37  8d 7d b0         lea     edi, [ebp-0x50]
00635e3a  a5               movsd   dword [edi], [esi]
00635e3b  a5               movsd   dword [edi], [esi]
00635e3c  a5               movsd   dword [edi], [esi]
00635e3d  53               push    ebx
00635e3e  8d 4d b0         lea     ecx, [ebp-0x50]
00635e41  a5               movsd   dword [edi], [esi]
00635e42  e8 b8 1f 00 00   call    StdDequePtr_AdvanceIteratorByOffset
00635e47  8b 45 b0         mov     eax, dword [ebp-0x50]
00635e4a  8b 08            mov     ecx, dword [eax]
00635e4c  85 c9            test    ecx, ecx
00635e4e  74 21            je      0x635e71
00635e50  8b 01            mov     eax, dword [ecx]
00635e52  8d 55 e0         lea     edx, [ebp-0x20]
00635e55  52               push    edx
00635e56  ff 50 14         call    dword [eax+0x14]
00635e59  8b 45 e0         mov     eax, dword [ebp-0x20]
00635e5c  8b 4d e4         mov     ecx, dword [ebp-0x1c]
00635e5f  8b 55 d8         mov     edx, dword [ebp-0x28]
00635e62  03 c8            add     ecx, eax
00635e64  8b 45 d4         mov     eax, dword [ebp-0x2c]
00635e67  03 c2            add     eax, edx
00635e69  3b c1            cmp     eax, ecx
00635e6b  0f 8c f5 00 00 00 jl      0x635f66
00635e71  43               inc     ebx
00635e72  3b 5d dc         cmp     ebx, dword [ebp-0x24]
00635e75  7c bd            jl      0x635e34
00635e77  e9 1d 01 00 00   jmp     0x635f99
00635e7c  89 45 cc         mov     dword [ebp-0x34], eax
00635e7f  48               dec     eax
00635e80  85 c0            test    eax, eax
00635e82  89 45 e4         mov     dword [ebp-0x1c], eax
00635e85  7c 54            jl      0x635edb
00635e87  8b 75 ec         mov     esi, dword [ebp-0x14]
00635e8a  8d 7d b0         lea     edi, [ebp-0x50]
00635e8d  a5               movsd   dword [edi], [esi]
00635e8e  a5               movsd   dword [edi], [esi]
00635e8f  ff 75 e4         push    dword [ebp-0x1c]
00635e92  8d 4d b0         lea     ecx, [ebp-0x50]
00635e95  a5               movsd   dword [edi], [esi]
00635e96  a5               movsd   dword [edi], [esi]
00635e97  e8 63 1f 00 00   call    StdDequePtr_AdvanceIteratorByOffset
00635e9c  8b 45 b0         mov     eax, dword [ebp-0x50]
00635e9f  8b 08            mov     ecx, dword [eax]
00635ea1  85 c9            test    ecx, ecx
00635ea3  74 31            je      0x635ed6
00635ea5  8b 01            mov     eax, dword [ecx]
00635ea7  8d 55 a8         lea     edx, [ebp-0x58]
00635eaa  52               push    edx
00635eab  ff 50 14         call    dword [eax+0x14]
00635eae  8b 45 a8         mov     eax, dword [ebp-0x58]
00635eb1  8b 4d ac         mov     ecx, dword [ebp-0x54]
00635eb4  03 c1            add     eax, ecx
00635eb6  8b 4d c4         mov     ecx, dword [ebp-0x3c]
00635eb9  03 cb            add     ecx, ebx
00635ebb  3b c8            cmp     ecx, eax
00635ebd  74 0c            je      0x635ecb
00635ebf  8b 4d d4         mov     ecx, dword [ebp-0x2c]
00635ec2  8b 55 d8         mov     edx, dword [ebp-0x28]
00635ec5  03 ca            add     ecx, edx
00635ec7  3b c8            cmp     ecx, eax
00635ec9  7d 10            jge     0x635edb
00635ecb  8b 45 e4         mov     eax, dword [ebp-0x1c]
00635ece  3b 45 d0         cmp     eax, dword [ebp-0x30]
00635ed1  7e 08            jle     0x635edb
00635ed3  89 45 cc         mov     dword [ebp-0x34], eax
00635ed6  ff 4d e4         dec     dword [ebp-0x1c]
00635ed9  79 ac            jns     0x635e87
00635edb  8d 45 08         lea     eax, [ebp+0x8]
00635ede  8b 4d ec         mov     ecx, dword [ebp-0x14]
00635ee1  50               push    eax
00635ee2  83 ce ff         or      esi, 0xffffffff
00635ee5  83 ec 10         sub     esp, 0x10
00635ee8  8b c4            mov     eax, esp
00635eea  89 65 c4         mov     dword [ebp-0x3c], esp
00635eed  ff 75 cc         push    dword [ebp-0x34]
00635ef0  50               push    eax
00635ef1  8d 45 b0         lea     eax, [ebp-0x50]
00635ef4  50               push    eax
00635ef5  e8 25 b5 fe ff   call    StdDequePtr_CopyBeginIterator
00635efa  8b c8            mov     ecx, eax
00635efc  e8 45 b6 fe ff   call    StdDequePtr_IteratorPlusOffset
00635f01  8b 4d ec         mov     ecx, dword [ebp-0x14]
00635f04  8d 45 88         lea     eax, [ebp-0x78]
00635f07  50               push    eax
00635f08  e8 24 04 00 00   call    StdDequePtr_Insert
00635f0d  83 fe ff         cmp     esi, 0xffffffff
00635f10  0f 84 07 ff ff ff je      0x635e1d
00635f16  8b 7d ec         mov     edi, dword [ebp-0x14]
00635f19  8b cf            mov     ecx, edi
00635f1b  e8 26 69 10 00   call    0x73c846
00635f20  48               dec     eax
00635f21  3b f0            cmp     esi, eax
00635f23  8d 45 08         lea     eax, [ebp+0x8]
00635f26  50               push    eax
00635f27  7c 04            jl      0x635f2d
00635f29  8b cf            mov     ecx, edi
00635f2b  eb 78            jmp     0x635fa5
00635f2d  83 ec 10         sub     esp, 0x10
00635f30  8b cf            mov     ecx, edi
00635f32  8b c4            mov     eax, esp
00635f34  89 65 cc         mov     dword [ebp-0x34], esp
00635f37  6a 01            push    0x1
00635f39  50               push    eax
00635f3a  8d 45 b0         lea     eax, [ebp-0x50]
00635f3d  56               push    esi
00635f3e  50               push    eax
00635f3f  8d 45 88         lea     eax, [ebp-0x78]
00635f42  50               push    eax
00635f43  e8 d7 b4 fe ff   call    StdDequePtr_CopyBeginIterator
00635f48  8b c8            mov     ecx, eax
00635f4a  e8 f7 b5 fe ff   call    StdDequePtr_IteratorPlusOffset
00635f4f  8b c8            mov     ecx, eax
00635f51  e8 f0 b5 fe ff   call    StdDequePtr_IteratorPlusOffset
00635f56  8d 85 60 ff ff ff lea     eax, [ebp-0xa0]
00635f5c  8b cf            mov     ecx, edi
00635f5e  50               push    eax
00635f5f  e8 cd 03 00 00   call    StdDequePtr_Insert
00635f64  eb 44            jmp     0x635faa
00635f66  8d 45 08         lea     eax, [ebp+0x8]
00635f69  8b 4d ec         mov     ecx, dword [ebp-0x14]
00635f6c  50               push    eax
00635f6d  83 ec 10         sub     esp, 0x10
00635f70  8b c4            mov     eax, esp
00635f72  89 65 cc         mov     dword [ebp-0x34], esp
00635f75  53               push    ebx
00635f76  50               push    eax
00635f77  8d 85 50 ff ff ff lea     eax, [ebp-0xb0]
00635f7d  50               push    eax
00635f7e  e8 9c b4 fe ff   call    StdDequePtr_CopyBeginIterator
00635f83  8b c8            mov     ecx, eax
00635f85  e8 bc b5 fe ff   call    StdDequePtr_IteratorPlusOffset
00635f8a  8b 4d ec         mov     ecx, dword [ebp-0x14]
00635f8d  8d 85 40 ff ff ff lea     eax, [ebp-0xc0]
00635f93  50               push    eax
00635f94  e8 98 03 00 00   call    StdDequePtr_Insert
00635f99  3b 5d dc         cmp     ebx, dword [ebp-0x24]
00635f9c  7c 0c            jl      0x635faa
00635f9e  8b 4d ec         mov     ecx, dword [ebp-0x14]
00635fa1  8d 45 08         lea     eax, [ebp+0x8]
00635fa4  50               push    eax
00635fa5  e8 5c 03 00 00   call    StdDequePtr_PushBack
00635faa  8b 4d f4         mov     ecx, dword [ebp-0xc]
00635fad  5f               pop     edi
00635fae  5e               pop     esi
00635faf  64 89 0d 00 00 00 00 mov     dword [fs:0x0], ecx
00635fb6  5b               pop     ebx
00635fb7  c9               leave
00635fb8  c2 04 00         retn    0x4
