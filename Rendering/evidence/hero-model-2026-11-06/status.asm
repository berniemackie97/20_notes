File: /Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb

# Block 1 at 0x66f766
0066f766  6a 21            push    0x21  ; Role_HasStatusFlag(hero, 0x21). statuseffect.ini row 33 = 'bless' (Heaven Blessing). Was misnamed HasExtendedPhysicalForceGaugeStatus (it also feeds CHero_GetEffectiveMaxPhysicalForce). Gates Revive Here in CHero_RequestReborn (StrRes 10484).
0066f768  e8 67 59 07 00   call    Role_HasStatusFlag
0066f76d  0f b6 c0         movzx   eax, al
0066f770  c3               retn
File: /Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb

# Block 1 at 0x6e50d4
006e50d4  8b 44 24 04      mov     eax, dword [esp+0x4]  ; Tests one of 128 role status bits stored as four consecutive 32-bit words at role+0x70..+0x7F. Returns false for indexes outside [0,127]; otherwise selects dword index>>5 and mask 1<<(index&31). Role_TickAndRender uses status 0x32 for mounted, 0x5F for aiming, and 0x76 for war-flag escort.
006e50d8  8b d1            mov     edx, ecx
006e50da  85 c0            test    eax, eax
006e50dc  7c 23            jl      0x6e5101

# Block 3 at 0x6e50de
006e50de  b9 80 00 00 00   mov     ecx, 0x80
006e50e3  3b c1            cmp     eax, ecx
006e50e5  7d 1a            jge     0x6e5101

# Block 4 at 0x6e50e7
006e50e7  73 18            jae     0x6e5101

# Block 5 at 0x6e50e9
006e50e9  56               push    esi
006e50ea  8b c8            mov     ecx, eax
006e50ec  6a 01            push    0x1
006e50ee  83 e1 1f         and     ecx, 0x1f
006e50f1  5e               pop     esi
006e50f2  d3 e6            shl     esi, cl
006e50f4  c1 e8 05         shr     eax, 0x5
006e50f7  85 74 82 70      test    dword [edx+eax*4+0x70], esi
006e50fb  5e               pop     esi
006e50fc  0f 95 c0         setne   al
006e50ff  eb 02            jmp     0x6e5103

# Block 2 at 0x6e5101
006e5101  32 c0            xor     al, al

# Block 6 at 0x6e5103
006e5103  c2 04 00         retn    0x4

