File: /Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb

# Block 1 at 0x65d06d
0065d06d  b8 b4 06 82 00   mov     eax, 0x8206b4  ; CHero::GetEffectiveMaxLife -- verified byte-exact from 0x65D0C9..0x65D132 for the base and
profession chain, because HLIL renders the descending if-chain with a shared store address
and is ambiguous there.

OVERRIDE GATE
  A = (hero+0x514 > 0) && CGameMap_HasFlags64Bit0x40()
  B = CRole_HasFlagAt0xEC(hero)          ; role+0xEC != 0
  if (A || B) return hero+0x514;         ; note this can return 0 when !A && B
  ; i.e. the normal formula runs only when !A && !B

BASE
  base = (strength +0x4FC + agility +0x504 + vitality +0x508 * 8 + spirit +0x50C) * 3
         (lea edi,[eax+eax*2] after the three adds)

PROFESSION BONUS -- applies ONLY when (prof % 1000) / 10 == 1, i.e. professions 10..19
  t = prof % 10; pct = {1:5, 2:8, 3:10, 4:12, 5:15}, else 0
  base += (pct * base) / 100             ; SIGNED idiv, truncates toward zero

EQUIPMENT, slots 1..0x12 inclusive (i < 0x13), via CHeroItem__GetEquipSlotItemRef (shared_ptr)
  skip when CItem_IsBrokenOrDisabled(item)
  base += (int16)CItem_GetEffectiveLife(item)   ; movsx  @0x65D156
        + (uint16)*(item+0x180)                 ; movzx  @0x65D15B, the ItemAdd record cache
  if (slot != 0xC) base += CItem_GetEnchantmentLifeBonus(item)
  if (CItem_GetPrimaryRefinementEffectId(item) == 0x12D)   base += CItem_GetPrimaryRefinementValue(item)
  if (CItem_GetPrimaryRefinementEffectId(item) <  0x64 &&
      CItem_GetSecondaryRefinementEffectId(item) == 0x12D) base += CItem_GetSecondaryRefinementValue(item)

OVERLAY
  if (CGameMap_HasOverlayRenderModeFlag(map)) base += hero+0xCB0

TIER TABLE
  d = CHero_GetPackedPerTypeLevelDigit(hero, 9)
  if (d > 0 && d <= 9) base += table[d] where table = {0,100,200,300,400,500,600,800,1000,1200}
  (built as var_40=0 followed by a 9-dword memcpy, indexed as (&var_40)[d])

CLAMP
  return base >= 0 ? base : 0

item+0x180 is the ItemAdd record cache filled by CItem_RefreshItemAddRecordCache (0x67AC6B) via
GameDataSingleton_TryGetActionTypeRecordByDualKey(store, (normalizedType/10)*10,
CItem_GetByte61(item), item+0x180); the life term is that record's FIRST word.

Managed mirror: Conquer.World.State.ClientWorldLocalHeroMaxStatResolver; the equipment loop is
ClientWorldLocalHeroItemStatResolver. See 20_notes/Rendering/14_hero_effective_max_life_mana.md
0065d072  e8 d9 a5 11 00   call    __EH_prolog
0065d077  83 ec 30         sub     esp, 0x30
0065d07a  56               push    esi
0065d07b  8b f1            mov     esi, ecx
0065d07d  83 be 14 05 00 00 00 cmp     dword [esi+0x514], 0x0
0065d084  76 10            jbe     0x65d096

# Block 3 at 0x65d086
0065d086  e8 fa 35 db ff   call    CGameMap_GetSingletonPtr
0065d08b  8b c8            mov     ecx, eax
0065d08d  e8 36 36 fc ff   call    CGameMap_HasFlags64HighBit6_Analyst
0065d092  84 c0            test    al, al
0065d094  75 0b            jne     0x65d0a1

# Block 2 at 0x65d096
0065d096  8b ce            mov     ecx, esi
0065d098  e8 af 3a ff ff   call    CRole_HasTransformLook
0065d09d  84 c0            test    al, al
0065d09f  74 0b            je      0x65d0ac

# Block 5 at 0x65d0a1
0065d0a1  8b 86 14 05 00 00 mov     eax, dword [esi+0x514]
0065d0a7  e9 9d 01 00 00   jmp     0x65d249

# Block 4 at 0x65d0ac
0065d0ac  8b 86 0c 05 00 00 mov     eax, dword [esi+0x50c]
0065d0b2  8b 8e 08 05 00 00 mov     ecx, dword [esi+0x508]
0065d0b8  8b 96 fc 04 00 00 mov     edx, dword [esi+0x4fc]
0065d0be  53               push    ebx
0065d0bf  57               push    edi
0065d0c0  8b be 04 05 00 00 mov     edi, dword [esi+0x504]
0065d0c6  8d 04 c8         lea     eax, [eax+ecx*8]
0065d0c9  8b 8e 2c 08 00 00 mov     ecx, dword [esi+0x82c]
0065d0cf  03 c7            add     eax, edi
0065d0d1  bb e8 03 00 00   mov     ebx, 0x3e8
0065d0d6  03 c2            add     eax, edx
0065d0d8  33 d2            xor     edx, edx
0065d0da  6a 0a            push    0xa
0065d0dc  8d 3c 40         lea     edi, [eax+eax*2]
0065d0df  8b c1            mov     eax, ecx
0065d0e1  f7 f3            div     ebx
0065d0e3  5b               pop     ebx
0065d0e4  6a 01            push    0x1
0065d0e6  8b c2            mov     eax, edx
0065d0e8  33 d2            xor     edx, edx
0065d0ea  f7 f3            div     ebx
0065d0ec  5b               pop     ebx
0065d0ed  3b c3            cmp     eax, ebx
0065d0ef  75 3a            jne     0x65d12b

# Block 7 at 0x65d0f1
0065d0f1  6a 0a            push    0xa
0065d0f3  8b c1            mov     eax, ecx
0065d0f5  33 d2            xor     edx, edx
0065d0f7  59               pop     ecx
0065d0f8  f7 f1            div     ecx
0065d0fa  4a               dec     edx
0065d0fb  74 20            je      0x65d11d

# Block 12 at 0x65d0fd
0065d0fd  4a               dec     edx
0065d0fe  74 19            je      0x65d119

# Block 17 at 0x65d100
0065d100  4a               dec     edx
0065d101  74 12            je      0x65d115

# Block 23 at 0x65d103
0065d103  4a               dec     edx
0065d104  74 0b            je      0x65d111

# Block 29 at 0x65d106
0065d106  4a               dec     edx
0065d107  74 04            je      0x65d10d

# Block 34 at 0x65d109
0065d109  33 c0            xor     eax, eax
0065d10b  eb 13            jmp     0x65d120

# Block 33 at 0x65d10d
0065d10d  6a 0f            push    0xf
0065d10f  eb 0e            jmp     0x65d11f

# Block 28 at 0x65d111
0065d111  6a 0c            push    0xc
0065d113  eb 0a            jmp     0x65d11f

# Block 22 at 0x65d115
0065d115  6a 0a            push    0xa
0065d117  eb 06            jmp     0x65d11f

# Block 16 at 0x65d119
0065d119  6a 08            push    0x8
0065d11b  eb 02            jmp     0x65d11f

# Block 11 at 0x65d11d
0065d11d  6a 05            push    0x5

# Block 21 at 0x65d11f
0065d11f  58               pop     eax

# Block 39 at 0x65d120
0065d120  0f af c7         imul    eax, edi
0065d123  6a 64            push    0x64
0065d125  99               cdq
0065d126  59               pop     ecx
0065d127  f7 f9            idiv    ecx
0065d129  03 f8            add     edi, eax

# Block 6 at 0x65d12b
0065d12b  8d 45 ec         lea     eax, [ebp-0x14]
0065d12e  53               push    ebx
0065d12f  50               push    eax
0065d130  8b ce            mov     ecx, esi
0065d132  e8 0c d7 07 00   call    CHeroItem__GetEquipSlotItemRef
0065d137  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d13a  83 65 fc 00      and     dword [ebp-0x4], 0x0
0065d13e  85 c9            test    ecx, ecx
0065d140  74 6d            je      0x65d1af

# Block 10 at 0x65d142
0065d142  e8 a7 fa 01 00   call    CItem_IsBrokenOrDisabled
0065d147  84 c0            test    al, al
0065d149  75 64            jne     0x65d1af

# Block 15 at 0x65d14b
0065d14b  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d14e  e8 d0 0a 02 00   call    CItem_GetEffectiveLife
0065d153  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d156  0f bf c0         movsx   eax, ax
0065d159  03 f8            add     edi, eax
0065d15b  0f b7 81 80 01 00 00 movzx   eax, word [ecx+0x180]
0065d162  03 f8            add     edi, eax
0065d164  83 fb 0c         cmp     ebx, 0xc
0065d167  74 07            je      0x65d170

# Block 20 at 0x65d169
0065d169  e8 e1 05 02 00   call    CItem_GetEnchantmentLifeOrSteedGreenChannel
0065d16e  03 f8            add     edi, eax

# Block 19 at 0x65d170
0065d170  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d173  e8 7e fb 01 00   call    CItem_GetPrimaryRefinementEffectId
0065d178  3d 2d 01 00 00   cmp     eax, 0x12d
0065d17d  75 0a            jne     0x65d189

# Block 27 at 0x65d17f
0065d17f  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d182  e8 68 fb 01 00   call    CItem_GetPrimaryRefinementValue
0065d187  03 f8            add     edi, eax

# Block 26 at 0x65d189
0065d189  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d18c  e8 65 fb 01 00   call    CItem_GetPrimaryRefinementEffectId
0065d191  83 f8 64         cmp     eax, 0x64
0065d194  7d 19            jge     0x65d1af

# Block 32 at 0x65d196
0065d196  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d199  e8 30 fb 01 00   call    CItem_GetSecondaryRefinementEffectId
0065d19e  3d 2d 01 00 00   cmp     eax, 0x12d
0065d1a3  75 0a            jne     0x65d1af

# Block 38 at 0x65d1a5
0065d1a5  8b 4d ec         mov     ecx, dword [ebp-0x14]
0065d1a8  e8 f9 fa 01 00   call    CItem_GetSecondaryRefinementValue
0065d1ad  03 f8            add     edi, eax

# Block 9 at 0x65d1af
0065d1af  8b 4d f0         mov     ecx, dword [ebp-0x10]
0065d1b2  83 4d fc ff      or      dword [ebp-0x4], 0xffffffff
0065d1b6  85 c9            test    ecx, ecx
0065d1b8  74 05            je      0x65d1bf

# Block 14 at 0x65d1ba
0065d1ba  e8 25 7b da ff   call    SharedPtrControlBlock_DecrementStrongReference

# Block 13 at 0x65d1bf
0065d1bf  43               inc     ebx
0065d1c0  83 fb 13         cmp     ebx, 0x13
0065d1c3  0f 8c 62 ff ff ff jl      0x65d12b

# Block 18 at 0x65d1c9
0065d1c9  e8 b7 34 db ff   call    CGameMap_GetSingletonPtr
0065d1ce  8b c8            mov     ecx, eax
0065d1d0  e8 20 0e fc ff   call    CGameMap_HasOverlayRenderModeFlag
0065d1d5  84 c0            test    al, al
0065d1d7  74 06            je      0x65d1df

# Block 25 at 0x65d1d9
0065d1d9  03 be b0 0c 00 00 add     edi, dword [esi+0xcb0]

# Block 24 at 0x65d1df
0065d1df  6a 09            push    0x9
0065d1e1  e8 7a 72 da ff   call    CHero_GetSingletonPtr
0065d1e6  8b c8            mov     ecx, eax
0065d1e8  e8 30 8a 01 00   call    CRole_GetSubProfessionPhase
0065d1ed  85 c0            test    eax, eax
0065d1ef  7e 4c            jle     0x65d23d

# Block 31 at 0x65d1f1
0065d1f1  83 f8 09         cmp     eax, 0x9
0065d1f4  7f 47            jg      0x65d23d

# Block 37 at 0x65d1f6
0065d1f6  83 65 c4 00      and     dword [ebp-0x3c], 0x0
0065d1fa  c7 45 c8 64 00 00 00 mov     dword [ebp-0x38], 0x64
0065d201  c7 45 cc c8 00 00 00 mov     dword [ebp-0x34], 0xc8
0065d208  c7 45 d0 2c 01 00 00 mov     dword [ebp-0x30], 0x12c
0065d20f  c7 45 d4 90 01 00 00 mov     dword [ebp-0x2c], 0x190
0065d216  c7 45 d8 f4 01 00 00 mov     dword [ebp-0x28], 0x1f4
0065d21d  c7 45 dc 58 02 00 00 mov     dword [ebp-0x24], 0x258
0065d224  c7 45 e0 20 03 00 00 mov     dword [ebp-0x20], 0x320
0065d22b  c7 45 e4 e8 03 00 00 mov     dword [ebp-0x1c], 0x3e8
0065d232  c7 45 e8 b0 04 00 00 mov     dword [ebp-0x18], 0x4b0
0065d239  03 7c 85 c4      add     edi, dword [ebp+eax*4-0x3c]

# Block 30 at 0x65d23d
0065d23d  85 ff            test    edi, edi
0065d23f  7d 04            jge     0x65d245

# Block 36 at 0x65d241
0065d241  33 c0            xor     eax, eax
0065d243  eb 02            jmp     0x65d247

# Block 35 at 0x65d245
0065d245  8b c7            mov     eax, edi

# Block 40 at 0x65d247
0065d247  5f               pop     edi
0065d248  5b               pop     ebx

# Block 8 at 0x65d249
0065d249  8b 4d f4         mov     ecx, dword [ebp-0xc]
0065d24c  5e               pop     esi
0065d24d  64 89 0d 00 00 00 00 mov     dword [fs:0x0], ecx
0065d254  c9               leave
0065d255  c3               retn

