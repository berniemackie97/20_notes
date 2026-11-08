00644e0e  56               push    esi  ; (entry, a, b) -> BOOL. Half-open footprint containment on a type-2 subcomponent.
00644e0f  8b 71 0c         mov     esi, dword [ecx+0xc]
00644e12  57               push    edi
00644e13  8b 79 10         mov     edi, dword [ecx+0x10]
00644e16  8b c6            mov     eax, esi
00644e18  8b d7            mov     edx, edi
00644e1a  2b 41 1c         sub     eax, dword [ecx+0x1c]
00644e1d  2b 51 20         sub     edx, dword [ecx+0x20]
00644e20  39 74 24 0c      cmp     dword [esp+0xc], esi
00644e24  7f 17            jg      0x644e3d
00644e26  39 7c 24 10      cmp     dword [esp+0x10], edi
00644e2a  7f 11            jg      0x644e3d
00644e2c  39 44 24 0c      cmp     dword [esp+0xc], eax
00644e30  7e 0b            jle     0x644e3d
00644e32  39 54 24 10      cmp     dword [esp+0x10], edx
00644e36  7e 05            jle     0x644e3d
00644e38  6a 01            push    0x1
00644e3a  58               pop     eax
00644e3b  eb 02            jmp     0x644e3f
00644e3d  33 c0            xor     eax, eax
00644e3f  5f               pop     edi
00644e40  5e               pop     esi
00644e41  c2 08 00         retn    0x8
