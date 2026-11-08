0061d9c8  8b 41 2c         mov     eax, dword [ecx+0x2c]
0061d9cb  39 44 24 04      cmp     dword [esp+0x4], eax
0061d9cf  7d 1b            jge     0x61d9ec
0061d9d1  8b 54 24 08      mov     edx, dword [esp+0x8]
0061d9d5  3b 51 30         cmp     edx, dword [ecx+0x30]
0061d9d8  7d 12            jge     0x61d9ec
0061d9da  83 7c 24 04 00   cmp     dword [esp+0x4], 0x0
0061d9df  7c 0b            jl      0x61d9ec
0061d9e1  85 d2            test    edx, edx
0061d9e3  7c 07            jl      0x61d9ec
0061d9e5  8b 49 50         mov     ecx, dword [ecx+0x50]
0061d9e8  85 c9            test    ecx, ecx
0061d9ea  75 04            jne     0x61d9f0
0061d9ec  33 c0            xor     eax, eax
0061d9ee  eb 0c            jmp     0x61d9fc
0061d9f0  0f af c2         imul    eax, edx
0061d9f3  03 44 24 04      add     eax, dword [esp+0x4]
0061d9f7  c1 e0 04         shl     eax, 0x4
0061d9fa  03 c1            add     eax, ecx
0061d9fc  c2 08 00         retn    0x8
