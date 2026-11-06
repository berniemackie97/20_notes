# Static Binary Ninja instruction excerpts; addresses are packet-relative where stated in note.
006fe971  8b ce            mov     ecx, esi
006fe973  e8 09 09 fe ff   call    CNetMsg__ResetPacketBuffer
006fe978  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe97e  66 c7 00 26 00   mov     word [eax], 0x26
006fe983  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe989  66 c7 40 02 1a 27 mov     word [eax+0x2], 0x271a
006fe98f  e8 57 a6 06 00   call    Conquer_GetTimeGetTime
006fe994  8b 8e 04 04 00 00 mov     ecx, dword [esi+0x404]
006fe99a  6a 01            push    0x1
006fe99c  89 41 10         mov     dword [ecx+0x10], eax
006fe99f  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe9a5  66 8b 4d 0c      mov     cx, word [ebp+0xc]
006fe9a9  89 78 04         mov     dword [eax+0x4], edi
006fe9ac  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe9b2  66 89 48 18      mov     word [eax+0x18], cx
006fe9b6  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe9bc  66 8b 4d 10      mov     cx, word [ebp+0x10]
006fe9c0  66 89 48 1a      mov     word [eax+0x1a], cx
006fe9c4  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe9ca  66 8b 4d 14      mov     cx, word [ebp+0x14]
006fe9ce  66 89 48 16      mov     word [eax+0x16], cx
006fe9d2  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe9d8  8b 4d 1c         mov     ecx, dword [ebp+0x1c]
006fe9db  89 48 08         mov     dword [eax+0x8], ecx
006fe9de  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fe9e4  66 8b 4d 18      mov     cx, word [ebp+0x18]
006fe9e8  66 89 48 14      mov     word [eax+0x14], cx
006fea08  8b ce            mov     ecx, esi
006fea0a  e8 72 08 fe ff   call    CNetMsg__ResetPacketBuffer
006fea0f  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea15  66 c7 00 26 00   mov     word [eax], 0x26
006fea1a  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea20  66 c7 40 02 1a 27 mov     word [eax+0x2], 0x271a
006fea26  8b 45 24         mov     eax, dword [ebp+0x24]
006fea29  85 c0            test    eax, eax
006fea2b  75 05            jne     0x6fea32
006fea2d  e8 b9 a5 06 00   call    Conquer_GetTimeGetTime
006fea32  8b 8e 04 04 00 00 mov     ecx, dword [esi+0x404]
006fea38  89 41 10         mov     dword [ecx+0x10], eax
006fea3b  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea41  66 8b 4d 0c      mov     cx, word [ebp+0xc]
006fea45  89 78 04         mov     dword [eax+0x4], edi
006fea48  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea4e  66 89 48 18      mov     word [eax+0x18], cx
006fea52  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea58  66 8b 4d 10      mov     cx, word [ebp+0x10]
006fea5c  66 89 48 1a      mov     word [eax+0x1a], cx
006fea60  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea66  66 8b 4d 14      mov     cx, word [ebp+0x14]
006fea6a  66 89 48 16      mov     word [eax+0x16], cx
006fea6e  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea74  66 8b 4d 18      mov     cx, word [ebp+0x18]
006fea78  66 89 48 14      mov     word [eax+0x14], cx
006fea7c  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea82  8b 4d 28         mov     ecx, dword [ebp+0x28]
006fea85  89 48 1c         mov     dword [eax+0x1c], ecx
006fea88  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea8e  66 8b 4d 1c      mov     cx, word [ebp+0x1c]
006fea92  66 89 48 08      mov     word [eax+0x8], cx
006fea96  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fea9c  66 8b 4d 20      mov     cx, word [ebp+0x20]
006feaa0  66 89 48 0a      mov     word [eax+0xa], cx
006feaa4  8b 8e 04 04 00 00 mov     ecx, dword [esi+0x404]
006feaaa  8b 45 2c         mov     eax, dword [ebp+0x2c]
006feaad  83 f8 ff         cmp     eax, 0xffffffff
006feab0  89 41 20         mov     dword [ecx+0x20], eax
006feadb  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feae1  66 c7 00 26 00   mov     word [eax], 0x26
006feae6  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feaec  66 c7 40 02 1a 27 mov     word [eax+0x2], 0x271a
006feaf2  e8 f4 a4 06 00   call    Conquer_GetTimeGetTime
006feaf7  8b 8e 04 04 00 00 mov     ecx, dword [esi+0x404]
006feafd  6a 00            push    0x0
006feaff  89 41 10         mov     dword [ecx+0x10], eax
006feb02  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb08  8b 4d 08         mov     ecx, dword [ebp+0x8]
006feb0b  66 c7 40 14 89 00 mov     word [eax+0x14], 0x89
006feb11  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb17  c6 40 24 01      mov     byte [eax+0x24], 0x1
006feb1b  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb21  89 48 04         mov     dword [eax+0x4], ecx
006feb24  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb2a  66 8b 4d 0c      mov     cx, word [ebp+0xc]
006feb2e  66 89 48 18      mov     word [eax+0x18], cx
006feb32  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb38  66 8b 4d 10      mov     cx, word [ebp+0x10]
006feb3c  66 89 48 1a      mov     word [eax+0x1a], cx
006feb40  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb46  66 8b 4d 14      mov     cx, word [ebp+0x14]
006feb4a  66 89 48 16      mov     word [eax+0x16], cx
006feb4e  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb54  8b 4d 20         mov     ecx, dword [ebp+0x20]
006feb57  89 48 1c         mov     dword [eax+0x1c], ecx
006feb5a  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb60  66 8b 4d 18      mov     cx, word [ebp+0x18]
006feb64  66 89 48 08      mov     word [eax+0x8], cx
006feb68  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb6e  66 8b 4d 1c      mov     cx, word [ebp+0x1c]
006feb72  66 89 48 0a      mov     word [eax+0xa], cx
006feb76  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006feb7c  83 48 20 ff      or      dword [eax+0x20], 0xffffffff
006fe8d1  c7 06 d8 ba 86 00 mov     dword [esi], 0x86bad8
006fe8d7  e8 a5 09 fe ff   call    CNetMsg__ResetPacketBuffer
006fe8dc  8d 46 04         lea     eax, [esi+0x4]
006fe8df  68 db 03 00 00   push    0x3db
006fe8e4  89 86 04 04 00 00 mov     dword [esi+0x404], eax
006fe8ea  83 c0 25         add     eax, 0x25
006fe8ed  50               push    eax
006fe8ee  8b cf            mov     ecx, edi
006fe8f0  e8 45 36 07 00   call    0x771f3a
006fed3b  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fed41  bf 18 b0 96 00   mov     edi, 0x96b018
006fed46  0f b7 48 14      movzx   ecx, word [eax+0x14]
006fed4a  3b ca            cmp     ecx, edx
006fed4c  0f 8f 23 02 00 00 jg      0x6fef75
006fefc3  8b 86 04 04 00 00 mov     eax, dword [esi+0x404]
006fefc9  ff 70 0c         push    dword [eax+0xc]
006fefcc  ff 70 08         push    dword [eax+0x8]
006fefcf  e8 27 75 04 00   call    0x7464fb
006ffc27  83 fa 6f         cmp     edx, 0x6f
006ffc2a  0f 8f 55 02 00 00 jg      0x6ffe85
006ffc30  0f 84 1a 02 00 00 je      0x6ffe50
006ffc36  83 ea 64         sub     edx, 0x64
006ffc39  0f 84 0b 02 00 00 je      0x6ffe4a
006ffc3f  83 ea 03         sub     edx, 0x3
006ffc42  0f 84 b8 01 00 00 je      0x6ffe00
006ffc48  83 ea 05         sub     edx, 0x5
006ffc4b  74 72            je      0x6ffcbf
006ffcbf  8b b9 cc 00 00 00 mov     edi, dword [ecx+0xcc]
006ffcc5  e8 96 47 d0 ff   call    CHero_GetSingletonPtr
006ffcca  3b b8 cc 00 00 00 cmp     edi, dword [eax+0xcc]
006ffcd0  0f 85 9e 0c 00 00 jne     0x700974
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
007003a9  8b 4d dc         mov     ecx, dword [ebp-0x24]
007003ac  8d 95 60 fe ff ff lea     edx, [ebp-0x1a0]
007003b2  38 5e 24         cmp     byte [esi+0x24], bl
007003b5  89 9d 64 fe ff ff mov     dword [ebp-0x19c], ebx
007003bb  52               push    edx
007003bc  0f 95 c0         setne   al
