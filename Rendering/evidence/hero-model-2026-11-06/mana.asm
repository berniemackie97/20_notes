File: /Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb

# Block 1 at 0x65d25a
0065d25a  56               push    esi  ; CHero::GetEffectiveMaxMana -- verified byte-exact from 0x65D285..0x65D318, because HLIL
renders the descending multiplier chain with a shared store address (0x65D2BD is reused by
the >=5, >=4 and >=2 arms) and cannot be read as written.

OVERRIDE GATE -- simpler than max life, and it does NOT consult role+0xEC
  if (hero+0x518 > 0 && CGameMap_HasFlags64Bit0x40()) return hero+0x518;

BASE
  spirit = hero+0x50C
  result = spirit * 5                    ; lea esi,[ecx+ecx*4], the DEFAULT

PROFESSION MULTIPLIER -- applies only when (prof % 1000) / 10 > 10  (UNSIGNED jbe skips <= 10)
  t = prof % 10                          ; SIGNED comparisons (jl)
  t >= 5 -> spirit * 30   (imul 0x1E)
  t >= 4 -> spirit * 25   (imul 0x19)
  t >= 3 -> spirit * 20   (lea *5 then shl 2)
  t >= 2 -> spirit * 15   (imul 0x0F)
  t >= 1 -> spirit * 10   (lea *5 then shl 1)
  t == 0 -> leaves the spirit * 5 default

Note the asymmetry with max life, which gates on == 1 rather than > 10 and applies a
percentage rather than replacing the multiplier.

EQUIPMENT -- 18 iterations from hero+0xE8C, stride 8, reading the RAW pointer
  (max life instead walks slots 1..0x12 through the shared_ptr accessor)
  if (*p) result += (int16)CItem_GetEffectiveMana(*p)     ; movsx ax

No overlay bonus and no tier table, unlike max life.

CLAMP
  return result >= 0 ? result : 0

See 20_notes/Rendering/14_hero_effective_max_life_mana.md
0065d25b  57               push    edi
0065d25c  8b f9            mov     edi, ecx
0065d25e  83 bf 18 05 00 00 00 cmp     dword [edi+0x518], 0x0
0065d265  8d b7 18 05 00 00 lea     esi, [edi+0x518]
0065d26b  76 17            jbe     0x65d284

# Block 3 at 0x65d26d
0065d26d  e8 13 34 db ff   call    CGameMap_GetSingletonPtr
0065d272  8b c8            mov     ecx, eax
0065d274  e8 4f 34 fc ff   call    CGameMap_HasFlags64HighBit6_Analyst
0065d279  84 c0            test    al, al
0065d27b  74 07            je      0x65d284

# Block 6 at 0x65d27d
0065d27d  8b 06            mov     eax, dword [esi]
0065d27f  e9 93 00 00 00   jmp     0x65d317

# Block 2 at 0x65d284
0065d284  53               push    ebx
0065d285  8b 9f 2c 08 00 00 mov     ebx, dword [edi+0x82c]
0065d28b  55               push    ebp
0065d28c  8b c3            mov     eax, ebx
0065d28e  33 d2            xor     edx, edx
0065d290  bd e8 03 00 00   mov     ebp, 0x3e8
0065d295  f7 f5            div     ebp
0065d297  6a 0a            push    0xa
0065d299  8b 8f 0c 05 00 00 mov     ecx, dword [edi+0x50c]
0065d29f  5d               pop     ebp
0065d2a0  8d 34 89         lea     esi, [ecx+ecx*4]
0065d2a3  8b c2            mov     eax, edx
0065d2a5  33 d2            xor     edx, edx
0065d2a7  f7 f5            div     ebp
0065d2a9  3b c5            cmp     eax, ebp
0065d2ab  76 3f            jbe     0x65d2ec

# Block 5 at 0x65d2ad
0065d2ad  55               push    ebp
0065d2ae  8b c3            mov     eax, ebx
0065d2b0  33 d2            xor     edx, edx
0065d2b2  5b               pop     ebx
0065d2b3  f7 f3            div     ebx
0065d2b5  83 fa 05         cmp     edx, 0x5
0065d2b8  7c 07            jl      0x65d2c1

# Block 10 at 0x65d2ba
0065d2ba  6b c9 1e         imul    ecx, ecx, 0x1e

# Block 20 at 0x65d2bd
0065d2bd  8b f1            mov     esi, ecx
0065d2bf  eb 2b            jmp     0x65d2ec

# Block 9 at 0x65d2c1
0065d2c1  83 fa 04         cmp     edx, 0x4
0065d2c4  7c 05            jl      0x65d2cb

# Block 15 at 0x65d2c6
0065d2c6  6b c9 19         imul    ecx, ecx, 0x19
0065d2c9  eb f2            jmp     0x65d2bd

# Block 14 at 0x65d2cb
0065d2cb  83 fa 03         cmp     edx, 0x3
0065d2ce  7c 08            jl      0x65d2d8

# Block 19 at 0x65d2d0
0065d2d0  8d 34 89         lea     esi, [ecx+ecx*4]
0065d2d3  c1 e6 02         shl     esi, 0x2
0065d2d6  eb 14            jmp     0x65d2ec

# Block 18 at 0x65d2d8
0065d2d8  83 fa 02         cmp     edx, 0x2
0065d2db  7c 05            jl      0x65d2e2

# Block 22 at 0x65d2dd
0065d2dd  6b c9 0f         imul    ecx, ecx, 0xf
0065d2e0  eb db            jmp     0x65d2bd

# Block 21 at 0x65d2e2
0065d2e2  83 fa 01         cmp     edx, 0x1
0065d2e5  7c 05            jl      0x65d2ec

# Block 23 at 0x65d2e7
0065d2e7  8d 34 89         lea     esi, [ecx+ecx*4]
0065d2ea  d1 e6            shl     esi, 0x1

# Block 4 at 0x65d2ec
0065d2ec  6a 12            push    0x12
0065d2ee  81 c7 8c 0e 00 00 add     edi, 0xe8c
0065d2f4  5b               pop     ebx

# Block 12 at 0x65d2f5
0065d2f5  8b 0f            mov     ecx, dword [edi]
0065d2f7  85 c9            test    ecx, ecx
0065d2f9  74 0a            je      0x65d305

# Block 8 at 0x65d2fb
0065d2fb  e8 3b 09 02 00   call    CItem_GetEffectiveMana
0065d300  0f bf c0         movsx   eax, ax
0065d303  03 f0            add     esi, eax

# Block 7 at 0x65d305
0065d305  83 c7 08         add     edi, 0x8
0065d308  4b               dec     ebx
0065d309  75 ea            jne     0x65d2f5

# Block 13 at 0x65d30b
0065d30b  5d               pop     ebp
0065d30c  5b               pop     ebx
0065d30d  85 f6            test    esi, esi
0065d30f  7d 04            jge     0x65d315

# Block 17 at 0x65d311
0065d311  33 c0            xor     eax, eax
0065d313  eb 02            jmp     0x65d317

# Block 16 at 0x65d315
0065d315  8b c6            mov     eax, esi

# Block 11 at 0x65d317
0065d317  5f               pop     edi
0065d318  5e               pop     esi
0065d319  c3               retn

