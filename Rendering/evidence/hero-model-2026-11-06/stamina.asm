File: /Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb

# Block 1 at 0x66f77c
0066f77c  56               push    esi
0066f77d  8b f1            mov     esi, ecx
0066f77f  e8 0e 00 00 00   call    CHero_GetEffectiveMaxPhysicalForce
0066f784  8b b6 30 08 00 00 mov     esi, dword [esi+0x830]
0066f78a  3b f0            cmp     esi, eax
0066f78c  7f 02            jg      0x66f790

# Block 3 at 0x66f78e
0066f78e  8b c6            mov     eax, esi

# Block 2 at 0x66f790
0066f790  5e               pop     esi
0066f791  c3               retn
File: /Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb

# Block 1 at 0x66f792
0066f792  56               push    esi  ; Returns hero+0x834, initialized to 100 at CHero_InitializeState:0x6570A9, or unsigned (value*3)>>1 when native status flag index 0x21 is set. With the native baseline this is 100 normally and 150 under the extended physical-force status. CDlgMain uses it as Progress46's live range.
0066f793  8b f1            mov     esi, ecx
0066f795  e8 cc ff ff ff   call    CHero_HasBlessStatus21
0066f79a  85 c0            test    eax, eax
0066f79c  8b 86 34 08 00 00 mov     eax, dword [esi+0x834]
0066f7a2  74 05            je      0x66f7a9

# Block 3 at 0x66f7a4
0066f7a4  8d 04 40         lea     eax, [eax+eax*2]
0066f7a7  d1 e8            shr     eax, 0x1

# Block 2 at 0x66f7a9
0066f7a9  5e               pop     esi
0066f7aa  c3               retn

