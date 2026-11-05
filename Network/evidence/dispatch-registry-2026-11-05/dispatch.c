File: /Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517-bninja/Conquer.exe.bndb

00777650        int32_t var_8_184 = 0xffffffff
00777652        int32_t (* var_c)() = sub_832b90
00777659        TEB* fsbase
00777659        struct _EXCEPTION_REGISTRATION_RECORD* ExceptionList = fsbase->NtTib.ExceptionList
0077765e        fsbase->NtTib.ExceptionList = &ExceptionList
0077766d        void* const var_14_2 = &data_6df3bf
006df3bf        int32_t ecx
006df3bf        int32_t var_14 = ecx
006df3c0        int32_t var_18 = ecx
006df3c8        int32_t __saved_edi
006df3c8        int32_t* var_14_1 = &__saved_edi
006df3d8        void*** result
006df3d8        if (arg1 == 0 || arg2 s> 0x400)
006e137b        result = nullptr
006df3de        int32_t var_28_1 = arg2
006df3eb        uint32_t eax_1 = zx.d(CNetMsg__GetType(arg1))
006df3f5        void*** result_1
006df3f5        if (eax_1 s> 0x520)
006dff57        if (eax_1 s<= 0x8a1)
006dff5d        if (eax_1 == 0x8a1)
006e099f        void*** eax_157 = operator new(0x408)
006e09a7        void*** var_18_124 = eax_157
006e09ac        int32_t var_8_126 = 0x69
006e09b3        if (eax_157 == 0)
006e09b3        goto label_6e134f
006e09b9        result_1 = sub_71bd04(eax_157)
006e09be        goto label_6e1351
006dff6a        if (eax_1 s<= 0x81b)
006dff70        if (eax_1 == 0x81b)
006e0490        void*** eax_114 = operator new(0x408)
006e0498        void*** var_18_96 = eax_114
006e049d        int32_t var_8_98 = 0x3c
006e04a4        if (eax_114 == 0)
006e04a4        goto label_6e134f
006e04aa        result_1 = sub_75c570(eax_114)
006e04af        goto label_6e1351
006dff7b        if (eax_1 s<= 0x7ff)
006dff81        if (eax_1 == 0x7ff)
006e0236        void*** eax_98 = operator new(0x408)
006e023e        void*** var_18_82 = eax_98
006e0243        int32_t var_8_84 = 0x59
006e024a        if (eax_98 == 0)
006e024a        goto label_6e134f
006e0250        result_1 = sub_75cca3(eax_98)
006e0255        goto label_6e1351
006dff8e        if (eax_1 s> 0x7f2)
006e0118        switch (eax_1)
006e0113        case 0x7f3
006e020d        void*** eax_97 = operator new(0x408)
006e0215        void*** var_18_81 = eax_97
006e021a        int32_t var_8_83 = 0x4e
006e0221        if (eax_97 == 0)
006e0221        goto label_6e134f
006e0227        result_1 = CMsgPetSpawn__Create(eax_97)
006e022c        goto label_6e1351
006e011e        case 0x7f4
006e01e4        void*** eax_96 = operator new(0x408)
006e01ec        void*** var_18_80 = eax_96
006e01f1        int32_t var_8_82 = 0x4f
006e01f8        if (eax_96 == 0)
006e01f8        goto label_6e134f
006e01fe        result_1 = sub_716d37(eax_96)
006e0203        goto label_6e1351
006e0125        case 0x7fb
006e01bb        void*** eax_95 = operator new(0x408)
006e01c3        void*** var_18_79 = eax_95
006e01c8        int32_t var_8_81 = 0x54
006e01cf        if (eax_95 == 0)
006e01cf        goto label_6e134f
006e01d5        result_1 = sub_75d0a8(eax_95)
006e01da        goto label_6e1351
006e012e        case 0x7fc
006e0192        void*** eax_94 = operator new(0x408)
006e019a        void*** var_18_78 = eax_94
006e019f        int32_t var_8_80 = 0x55
006e01a6        if (eax_94 == 0)
006e01a6        goto label_6e134f
006e01ac        result_1 = sub_744046(eax_94)
006e01b1        goto label_6e1351
006e0131        case 0x7fd
006e0169        void*** eax_93 = operator new(0x408)
006e0171        void*** var_18_77 = eax_93
006e0176        int32_t var_8_79 = 0x57
006e017d        if (eax_93 == 0)
006e017d        goto label_6e134f
006e0183        result_1 = sub_70a355(eax_93)
006e0188        goto label_6e1351
006e0134        case 0x7fe
006e0140        void*** eax_92 = operator new(0x408)
006e0148        void*** var_18_76 = eax_92
006e014d        int32_t var_8_78 = 0x58
006e0154        if (eax_92 == 0)
006e0154        goto label_6e134f
006e015a        result_1 = sub_72b454(eax_92)
006e015f        goto label_6e1351
006e137b        result = nullptr
006dff94        if (eax_1 == 0x7f2)
006e00ef        void*** eax_85 = operator new(0x408)
006e00f7        void*** var_18_75 = eax_85
006e00fc        int32_t var_8_77 = 0x45
006e0103        if (eax_85 == 0)
006e0103        goto label_6e134f
006e0109        result_1 = sub_75d18e(eax_85)
006e010e        goto label_6e1351
006dff9f        if (eax_1 == 0x521)
006e00c6        void*** eax_84 = operator new(0x408)
006e00ce        void*** var_18_74 = eax_84
006e00d3        int32_t var_8_76 = 0x93
006e00da        if (eax_84 == 0)
006e00da        goto label_6e134f
006e00e0        result_1 = sub_7069f1(eax_84)
006e00e5        goto label_6e1351
006dffa6        if (eax_1 == 0x522)
006e009d        void*** eax_83 = operator new(0x408)
006e00a5        void*** var_18_73 = eax_83
006e00aa        int32_t var_8_75 = 0xb0
006e00b1        if (eax_83 == 0)
006e00b1        goto label_6e134f
006e00b7        result_1 = sub_74de0f(eax_83)
006e00bc        goto label_6e1351
006dffac        int32_t var_28_2 = 0x24
006dffb1        if (eax_1 == 0x546)
006e0074        void*** eax_82 = operator new(0x408)
006e007c        void*** var_18_72 = eax_82
006e0081        int32_t var_8_74 = 0x31
006e0088        if (eax_82 == 0)
006e0088        goto label_6e134f
006e008e        result_1 = sub_75d217(eax_82)
006e0093        goto label_6e1351
006dffbc        if (eax_1 == 0x7ee)
006e004b        void*** eax_81 = operator new(0x414)
006e0053        void*** var_18_71 = eax_81
006e0058        int32_t var_8_73 = 0x25
006e005f        if (eax_81 == 0)
006e005f        goto label_6e134f
006e0065        result_1 = CMsgNpcInfo__Create(eax_81)
006e006a        goto label_6e1351
006dffc3        if (eax_1 == 0x7ef)
006e0026        void*** eax_80 = operator new(0x408)
006e002e        void*** var_18_70 = eax_80
006e0033        int32_t var_8_72 = 0x24
006e0036        if (eax_80 == 0)
006e0036        goto label_6e134f
006e003c        result_1 = sub_72cb79(eax_80)
006e0041        goto label_6e1351
006dffc6        if (eax_1 == 0x7f0)
006dfffd        void*** eax_79 = operator new(0x414)
006e0005        void*** var_18_69 = eax_79
006e000a        int32_t var_8_71 = 0x37
006e0011        if (eax_79 == 0)
006e0011        goto label_6e134f
006e0017        result_1 = sub_72bbff(eax_79)
006e001c        goto label_6e1351
006dffc9        if (eax_1 == 0x7f1)
006dffd4        void*** eax_78 = operator new(0x408)
006dffdc        void*** var_18_68 = eax_78
006dffe1        int32_t var_8_70 = 0x43
006dffe8        if (eax_78 == 0)
006dffe8        goto label_6e134f
006dffee        result_1 = sub_75d2d9(eax_78)
006dfff3        goto label_6e1351
006e137b        result = nullptr
006e0262        if (eax_1 - 0x800 u> 0x19)
006e137b        result = nullptr
006e0262        switch (eax_1)
006e03c3        case 0x800
006e03c3        void*** eax_109 = operator new(0x408)
006e03cb        void*** var_18_91 = eax_109
006e03d0        int32_t var_8_93 = 0x5a
006e03d7        if (eax_109 == 0)
006e03d7        goto label_6e134f
006e03dd        result_1 = sub_6e702e(eax_109)
006e03e2        goto label_6e1351
006e137b        case 0x801, 0x804, 0x805, 0x806, 0x807, 0x808, 0x809, 0x80a, 0x80b, 0x80c, 0x80d, 0x80e, 0x80f
006e137b        result = nullptr
006e0348        case 0x802
006e0348        void*** eax_106 = operator new(0x414)
006e0350        void*** var_18_88 = eax_106
006e0355        int32_t var_8_90 = 0x52
006e035c        if (eax_106 == 0)
006e035c        goto label_6e134f
006e0362        result_1 = sub_7189b6(eax_106)
006e0367        goto label_6e1351
006e0371        case 0x803
006e0371        void*** eax_107 = operator new(0x408)
006e0379        void*** var_18_89 = eax_107
006e037e        int32_t var_8_91 = 0x53
006e0385        if (eax_107 == 0)
006e0385        goto label_6e134f
006e038b        result_1 = sub_75c9a0(eax_107)
006e0390        goto label_6e1351
006e039a        case 0x810
006e039a        void*** eax_108 = operator new(0x414)
006e03a2        void*** var_18_90 = eax_108
006e03a7        int32_t var_8_92 = 0x56
006e03ae        if (eax_108 == 0)
006e03ae        goto label_6e134f
006e03b4        result_1 = sub_74a132(eax_108)
006e03b9        goto label_6e1351
006e02a4        case 0x811
006e02a4        void*** eax_102 = operator new(0x414)
006e02ac        void*** var_18_84 = eax_102
006e02b1        int32_t var_8_86 = 4
006e02b8        if (eax_102 == 0)
006e02b8        goto label_6e134f
006e02be        result_1 = sub_74c355(eax_102)
006e02c3        goto label_6e1351
006e02cd        case 0x812
006e02cd        void*** eax_103 = operator new(0x414)
006e02d5        void*** var_18_85 = eax_103
006e02da        int32_t var_8_87 = 5
006e02e1        if (eax_103 == 0)
006e02e1        goto label_6e134f
006e02e7        result_1 = sub_7155cf(eax_103)
006e02ec        goto label_6e1351
006e027b        case 0x813
006e027b        void*** eax_101 = operator new(0x414)
006e0283        void*** var_18_83 = eax_101
006e0288        int32_t var_8_85 = 2
006e028f        if (eax_101 == 0)
006e028f        goto label_6e134f
006e0295        result_1 = sub_716106(eax_101)
006e029a        goto label_6e1351
006e03ec        case 0x814
006e03ec        void*** eax_110 = operator new(0x414)
006e03f4        void*** var_18_92 = eax_110
006e03f9        int32_t var_8_94 = 0x74
006e0400        if (eax_110 == 0)
006e0400        goto label_6e134f
006e0406        result_1 = sub_71eb16(eax_110)
006e040b        goto label_6e1351
006e0415        case 0x815
006e0415        void*** eax_111 = operator new(0x408)
006e041d        void*** var_18_93 = eax_111
006e0422        int32_t var_8_95 = 0x75
006e0429        if (eax_111 == 0)
006e0429        goto label_6e134f
006e042f        result_1 = sub_75c8ff(eax_111)
006e0434        goto label_6e1351
006e043e        case 0x816
006e043e        void*** eax_112 = operator new(0x408)
006e0446        void*** var_18_94 = eax_112
006e044b        int32_t var_8_96 = 0x7d
006e0452        if (eax_112 == 0)
006e0452        goto label_6e134f
006e0458        result_1 = sub_707c29(eax_112)
006e045d        goto label_6e1351
006e0467        case 0x817
006e0467        void*** eax_113 = operator new(0x408)
006e046f        void*** var_18_95 = eax_113
006e0474        int32_t var_8_97 = 0x7e
006e047b        if (eax_113 == 0)
006e047b        goto label_6e134f
006e0481        result_1 = sub_75c7ec(eax_113)
006e0486        goto label_6e1351
006e02f6        case 0x818
006e02f6        void*** eax_104 = operator new(0x408)
006e02fe        void*** var_18_86 = eax_104
006e0303        int32_t var_8_88 = 0x28
006e030a        if (eax_104 == 0)
006e030a        goto label_6e134f
006e0310        result_1 = sub_74f3e1(eax_104)
006e0315        goto label_6e1351
006e031f        case 0x819
006e031f        void*** eax_105 = operator new(0x408)
006e0327        void*** var_18_87 = eax_105
006e032c        int32_t var_8_89 = 0x29
006e0333        if (eax_105 == 0)
006e0333        goto label_6e134f
006e0339        result_1 = sub_75cb87(eax_105)
006e033e        goto label_6e1351
006e04bb        if (eax_1 s<= 0x835)
006e04c1        if (eax_1 == 0x835)
006e06fd        void*** eax_130 = operator new(0x408)
006e0705        void*** var_18_110 = eax_130
006e070a        int32_t var_8_112 = 0x21
006e0711        if (eax_130 == 0)
006e0711        goto label_6e134f
006e0717        result_1 = sub_7022af(eax_130)
006e071c        goto label_6e1351
006e04cf        if (eax_1 - 0x81d u> 0x15)
006e137b        result = nullptr
006e04cf        switch (eax_1)
006e0659        case 0x81d
006e0659        void*** eax_126 = operator new(0x408)
006e0661        void*** var_18_106 = eax_126
006e0666        int32_t var_8_108 = 0x3d
006e066d        if (eax_126 == 0)
006e066d        goto label_6e134f
006e0673        result_1 = sub_75b05b(eax_126)
006e0678        goto label_6e1351
006e0682        case 0x81e
006e0682        void*** eax_127 = operator new(0x408)
006e068a        void*** var_18_107 = eax_127
006e068f        int32_t var_8_109 = 0x3f
006e0696        if (eax_127 == 0)
006e0696        goto label_6e134f
006e069c        result_1 = CMsgAccountLoginAlert2078__Ctor(eax_127)
006e06a1        goto label_6e1351
006e06ab        case 0x81f
006e06ab        void*** eax_128 = operator new(0x408)
006e06b3        void*** var_18_108 = eax_128
006e06b8        int32_t var_8_110 = 0x40
006e06bf        if (eax_128 == 0)
006e06bf        goto label_6e134f
006e06c5        result_1 = CMsgServerState2079__Ctor(eax_128)
006e06ca        goto label_6e1351
006e06d4        case 0x820
006e06d4        void*** eax_129 = operator new(0x408)
006e06dc        void*** var_18_109 = eax_129
006e06e1        int32_t var_8_111 = 0x9f
006e06e8        if (eax_129 == 0)
006e06e8        goto label_6e134f
006e06ee        result_1 = sub_74b5ae(eax_129)
006e06f3        goto label_6e1351
006e137b        case 0x821, 0x822, 0x823, 0x824, 0x825, 0x826, 0x827, 0x828, 0x829
006e137b        result = nullptr
006e04e8        case 0x82a
006e04e8        void*** eax_117 = operator new(0x408)
006e04f0        void*** var_18_97 = eax_117
006e04f5        int32_t var_8_99 = 7
006e04fc        if (eax_117 == 0)
006e04fc        goto label_6e134f
006e0502        result_1 = sub_7513b2(eax_117)
006e0507        goto label_6e1351
006e058c        case 0x82b
006e058c        void*** eax_121 = operator new(0x408)
006e0594        void*** var_18_101 = eax_121
006e0599        int32_t var_8_103 = 0xb
006e05a0        if (eax_121 == 0)
006e05a0        goto label_6e134f
006e05a6        result_1 = sub_75bd80(eax_121)
006e05ab        goto label_6e1351
006e0563        case 0x82c
006e0563        void*** eax_120 = operator new(0x408)
006e056b        void*** var_18_100 = eax_120
006e0570        int32_t var_8_102 = 0xa
006e0577        if (eax_120 == 0)
006e0577        goto label_6e134f
006e057d        result_1 = sub_75c272(eax_120)
006e0582        goto label_6e1351
006e05b5        case 0x82d
006e05b5        void*** eax_122 = operator new(0x408)
006e05bd        void*** var_18_102 = eax_122
006e05c2        int32_t var_8_104 = 0xc
006e05c9        if (eax_122 == 0)
006e05c9        goto label_6e134f
006e05cf        result_1 = sub_75106f(eax_122)
006e05d4        goto label_6e1351
006e05de        case 0x82e
006e05de        void*** eax_123 = operator new(0x408)
006e05e6        void*** var_18_103 = eax_123
006e05eb        int32_t var_8_105 = 0xd
006e05f2        if (eax_123 == 0)
006e05f2        goto label_6e134f
006e05f8        result_1 = sub_75baae(eax_123)
006e05fd        goto label_6e1351
006e0607        case 0x82f
006e0607        void*** eax_124 = operator new(0x408)
006e060f        void*** var_18_104 = eax_124
006e0614        int32_t var_8_106 = 0xe
006e061b        if (eax_124 == 0)
006e061b        goto label_6e134f
006e0621        result_1 = sub_75b80f(eax_124)
006e0626        goto label_6e1351
006e0511        case 0x830
006e0511        void*** eax_118 = operator new(0x408)
006e0519        void*** var_18_98 = eax_118
006e051e        int32_t var_8_100 = 8
006e0525        if (eax_118 == 0)
006e0525        goto label_6e134f
006e052b        result_1 = sub_75125e(eax_118)
006e0530        goto label_6e1351
006e053a        case 0x831
006e053a        void*** eax_119 = operator new(0x408)
006e0542        void*** var_18_99 = eax_119
006e0547        int32_t var_8_101 = 9
006e054e        if (eax_119 == 0)
006e054e        goto label_6e134f
006e0554        result_1 = sub_75c471(eax_119)
006e0559        goto label_6e1351
006e0630        case 0x832
006e0630        void*** eax_125 = operator new(0x408)
006e0638        void*** var_18_105 = eax_125
006e063d        int32_t var_8_107 = 0xf
006e0644        if (eax_125 == 0)
006e0644        goto label_6e134f
006e064a        result_1 = sub_75b575(eax_125)
006e064f        goto label_6e1351
006e0728        if (eax_1 s> 0x899)
006e0882        switch (eax_1)
006e087d        case 0x89a
006e0976        void*** eax_156 = operator new(0x408)
006e097e        void*** var_18_123 = eax_156
006e0983        int32_t var_8_125 = 0x82
006e098a        if (eax_156 == 0)
006e098a        goto label_6e134f
006e0990        result_1 = sub_752ea9(eax_156)
006e0995        goto label_6e1351
006e0888        case 0x89b
006e094d        void*** eax_155 = operator new(0x408)
006e0955        void*** var_18_122 = eax_155
006e095a        int32_t var_8_124 = 0x80
006e0961        if (eax_155 == 0)
006e0961        goto label_6e134f
006e0967        result_1 = sub_709f7f(eax_155)
006e096c        goto label_6e1351
006e0890        case 0x89d
006e0924        void*** eax_154 = operator new(0x408)
006e092c        void*** var_18_121 = eax_154
006e0931        int32_t var_8_123 = 0x65
006e0938        if (eax_154 == 0)
006e0938        goto label_6e134f
006e093e        result_1 = sub_71b76e(eax_154)
006e0943        goto label_6e1351
006e0897        case 0x89e
006e08fb        void*** eax_153 = operator new(0x408)
006e0903        void*** var_18_120 = eax_153
006e0908        int32_t var_8_122 = 0x66
006e090f        if (eax_153 == 0)
006e090f        goto label_6e134f
006e0915        result_1 = sub_71bef7(eax_153)
006e091a        goto label_6e1351
006e089a        case 0x89f
006e08d2        void*** eax_152 = operator new(0x408)
006e08da        void*** var_18_119 = eax_152
006e08df        int32_t var_8_121 = 0x67
006e08e6        if (eax_152 == 0)
006e08e6        goto label_6e134f
006e08ec        result_1 = sub_71c1b3(eax_152)
006e08f1        goto label_6e1351
006e089d        case 0x8a0
006e08a9        void*** eax_151 = operator new(0x408)
006e08b1        void*** var_18_118 = eax_151
006e08b6        int32_t var_8_120 = 0x68
006e08bd        if (eax_151 == 0)
006e08bd        goto label_6e134f
006e08c3        result_1 = sub_71bb50(eax_151)
006e08c8        goto label_6e1351
006e137b        result = nullptr
006e072e        switch (eax_1)
006e0734        case 0x836
006e0830        void*** eax_142 = operator new(0x408)
006e0838        void*** var_18_116 = eax_142
006e083d        int32_t var_8_118 = 0x22
006e0844        if (eax_142 == 0)
006e0844        goto label_6e134f
006e084a        result_1 = sub_75a834(eax_142)
006e084f        goto label_6e1351
006e073f        case 0x837
006e0807        void*** eax_141 = operator new(0x408)
006e080f        void*** var_18_115 = eax_141
006e0814        int32_t var_8_117 = 0x4c
006e081b        if (eax_141 == 0)
006e081b        goto label_6e134f
006e0821        result_1 = sub_6ecb23(eax_141)
006e0826        goto label_6e1351
006e0746        case 0x83e
006e07de        void*** eax_140 = operator new(0x408)
006e07e6        void*** var_18_114 = eax_140
006e07eb        int32_t var_8_116 = 0x88
006e07f2        if (eax_140 == 0)
006e07f2        goto label_6e134f
006e07f8        result_1 = sub_7518e3(eax_140)
006e07fd        goto label_6e1351
006e074f        case 0x87a
006e07b5        void*** eax_139 = operator new(0x414)
006e07bd        void*** var_18_113 = eax_139
006e07c2        int32_t var_8_115 = 0x77
006e07c9        if (eax_139 == 0)
006e07c9        goto label_6e134f
006e07cf        result_1 = sub_72c4cd(eax_139)
006e07d4        goto label_6e1351
006e0754        case 0x87b
006e078c        void*** eax_138 = operator new(0x408)
006e0794        void*** var_18_112 = eax_138
006e0799        int32_t var_8_114 = 0x79
006e07a0        if (eax_138 == 0)
006e07a0        goto label_6e134f
006e07a6        result_1 = sub_744da5(eax_138)
006e07ab        goto label_6e1351
006e0757        case 0x87c
006e0763        void*** eax_137 = operator new(0x408)
006e076b        void*** var_18_111 = eax_137
006e0770        int32_t var_8_113 = 0x7a
006e0777        if (eax_137 == 0)
006e0777        goto label_6e134f
006e077d        result_1 = sub_75aa46(eax_137)
006e0782        goto label_6e1351
006e0726        case 0x899
006e0859        void*** eax_143 = operator new(0x408)
006e0861        void*** var_18_117 = eax_143
006e0866        int32_t var_8_119 = 0x81
006e086d        if (eax_143 == 0)
006e086d        goto label_6e134f
006e0873        result_1 = sub_75a695(eax_143)
006e0878        goto label_6e1351
006e137b        result = nullptr
006e09ca        if (eax_1 s<= 0x8d4)
006e09d0        if (eax_1 == 0x8d4)
006e0f39        void*** eax_192 = operator new(0x408)
006e0f41        void*** var_18_158 = eax_192
006e0f46        int32_t var_8_160 = 0xaa
006e0f4d        if (eax_192 == 0)
006e0f4d        goto label_6e134f
006e0f53        result_1 = sub_72997b(eax_192)
006e0f58        goto label_6e1351
006e09de        if (eax_1 - 0x8a2 u> 0x2b)
006e137b        result = nullptr
006e09de        switch (eax_1)
006e0c05        case 0x8a2
006e0c05        void*** eax_172 = operator new(0x408)
006e0c0d        void*** var_18_138 = eax_172
006e0c12        int32_t var_8_140 = 0x72
006e0c19        if (eax_172 == 0)
006e0c19        goto label_6e134f
006e0c1f        result_1 = sub_71c382(eax_172)
006e0c24        goto label_6e1351
006e0cd2        case 0x8a3
006e0cd2        void*** eax_177 = operator new(0x408)
006e0cda        void*** var_18_143 = eax_177
006e0cdf        int32_t var_8_145 = 0x94
006e0ce6        if (eax_177 == 0)
006e0ce6        goto label_6e134f
006e0cec        result_1 = sub_6e6cb6(eax_177)
006e0cf1        goto label_6e1351
006e09f0        case 0x8a4
006e09f0        void*** eax_159 = operator new(0x408)
006e09f8        void*** var_18_125 = eax_159
006e09fd        int32_t var_8_127 = 0x5c
006e0a04        if (eax_159 == 0)
006e0a04        goto label_6e134f
006e0a0a        result_1 = sub_704c32(eax_159)
006e0a0f        goto label_6e1351
006e0a94        case 0x8a5
006e0a94        void*** eax_163 = operator new(0x408)
006e0a9c        void*** var_18_129 = eax_163
006e0aa1        int32_t var_8_131 = 0x60
006e0aa8        if (eax_163 == 0)
006e0aa8        goto label_6e134f
006e0aae        result_1 = sub_7054be(eax_163)
006e0ab3        goto label_6e1351
006e0abd        case 0x8a6
006e0abd        void*** eax_164 = operator new(0x408)
006e0ac5        void*** var_18_130 = eax_164
006e0aca        int32_t var_8_132 = 0x61
006e0ad1        if (eax_164 == 0)
006e0ad1        goto label_6e134f
006e0ad7        result_1 = sub_70574f(eax_164)
006e0adc        goto label_6e1351
006e0a6b        case 0x8a7
006e0a6b        void*** eax_162 = operator new(0x408)
006e0a73        void*** var_18_128 = eax_162
006e0a78        int32_t var_8_130 = 0x5f
006e0a7f        if (eax_162 == 0)
006e0a7f        goto label_6e134f
006e0a85        result_1 = sub_70535c(eax_162)
006e0a8a        goto label_6e1351
006e0a42        case 0x8a8
006e0a42        void*** eax_161 = operator new(0x408)
006e0a4a        void*** var_18_127 = eax_161
006e0a4f        int32_t var_8_129 = 0x5e
006e0a56        if (eax_161 == 0)
006e0a56        goto label_6e134f
006e0a5c        result_1 = sub_705171(eax_161)
006e0a61        goto label_6e1351
006e0a19        case 0x8a9
006e0a19        void*** eax_160 = operator new(0x408)
006e0a21        void*** var_18_126 = eax_160
006e0a26        int32_t var_8_128 = 0x5d
006e0a2d        if (eax_160 == 0)
006e0a2d        goto label_6e134f
006e0a33        result_1 = sub_704fc3(eax_160)
006e0a38        goto label_6e1351
006e0cfb        case 0x8aa
006e0cfb        void*** eax_178 = operator new(0x408)
006e0d03        void*** var_18_144 = eax_178
006e0d08        int32_t var_8_146 = 0x9a
006e0d0f        if (eax_178 == 0)
006e0d0f        goto label_6e134f
006e0d15        result_1 = sub_75a35c(eax_178)
006e0d1a        goto label_6e1351
006e0d24        case 0x8ab
006e0d24        void*** eax_179 = operator new(0x408)
006e0d2c        void*** var_18_145 = eax_179
006e0d31        int32_t var_8_147 = 0x9b
006e0d38        if (eax_179 == 0)
006e0d38        goto label_6e134f
006e0d3e        result_1 = sub_6de376(eax_179)
006e0d43        goto label_6e1351
006e0c2e        case 0x8ac
006e0c2e        void*** eax_173 = operator new(0x408)
006e0c36        void*** var_18_139 = eax_173
006e0c3b        int32_t var_8_141 = 0x83
006e0c42        if (eax_173 == 0)
006e0c42        goto label_6e134f
006e0c48        result_1 = sub_74ea42(eax_173)
006e0c4d        goto label_6e1351
006e0ca9        case 0x8ad
006e0ca9        void*** eax_176 = operator new(0x408)
006e0cb1        void*** var_18_142 = eax_176
006e0cb6        int32_t var_8_144 = 0x8e
006e0cbd        if (eax_176 == 0)
006e0cbd        goto label_6e134f
006e0cc3        result_1 = sub_75a4ef(eax_176)
006e0cc8        goto label_6e1351
006e0d4d        case 0x8ae
006e0d4d        void*** eax_180 = operator new(0x408)
006e0d55        void*** var_18_146 = eax_180
006e0d5a        int32_t var_8_148 = 0x9c
006e0d61        if (eax_180 == 0)
006e0d61        goto label_6e134f
006e0d67        result_1 = sub_75a236(eax_180)
006e0d6c        goto label_6e1351
006e0d76        case 0x8af
006e0d76        void*** eax_181 = operator new(0x408)
006e0d7e        void*** var_18_147 = eax_181
006e0d83        int32_t var_8_149 = 0x9d
006e0d8a        if (eax_181 == 0)
006e0d8a        goto label_6e134f
006e0d90        result_1 = sub_72e552(eax_181)
006e0d95        goto label_6e1351
006e0d9f        case 0x8b0
006e0d9f        void*** eax_182 = operator new(0x408)
006e0da7        void*** var_18_148 = eax_182
006e0dac        int32_t var_8_150 = 0xa0
006e0db3        if (eax_182 == 0)
006e0db3        goto label_6e134f
006e0db9        result_1 = sub_74ba9b(eax_182)
006e0dbe        goto label_6e1351
006e0c57        case 0x8b1
006e0c57        void*** eax_174 = operator new(0x408)
006e0c5f        void*** var_18_140 = eax_174
006e0c64        int32_t var_8_142 = 0x8b
006e0c6b        if (eax_174 == 0)
006e0c6b        goto label_6e134f
006e0c71        result_1 = sub_74d26b(eax_174)
006e0c76        goto label_6e1351
006e0c80        case 0x8b2
006e0c80        void*** eax_175 = operator new(0x408)
006e0c88        void*** var_18_141 = eax_175
006e0c8d        int32_t var_8_143 = 0x8c
006e0c94        if (eax_175 == 0)
006e0c94        goto label_6e134f
006e0c9a        result_1 = sub_74cf8b(eax_175)
006e0c9f        goto label_6e1351
006e137b        case 0x8b3, 0x8b4, 0x8b5, 0x8ba, 0x8bb, 0x8bc, 0x8bd, 0x8be, 0x8bf, 0x8c8, 0x8c9
006e137b        result = nullptr
006e0e1a        case 0x8b6
006e0e1a        void*** eax_185 = operator new(0x408)
006e0e22        void*** var_18_151 = eax_185
006e0e27        int32_t var_8_153 = 0xa4
006e0e2e        if (eax_185 == 0)
006e0e2e        goto label_6e134f
006e0e34        result_1 = sub_759eca(eax_185)
006e0e39        goto label_6e1351
006e0dc8        case 0x8b7
006e0dc8        void*** eax_183 = operator new(0x408)
006e0dd0        void*** var_18_149 = eax_183
006e0dd5        int32_t var_8_151 = 0xa2
006e0ddc        if (eax_183 == 0)
006e0ddc        goto label_6e134f
006e0de2        result_1 = sub_75a110(eax_183)
006e0de7        goto label_6e1351
006e0e6c        case 0x8b8
006e0e6c        void*** eax_187 = operator new(0x408)
006e0e74        void*** var_18_153 = eax_187
006e0e79        int32_t var_8_155 = 0xa6
006e0e80        if (eax_187 == 0)
006e0e80        goto label_6e134f
006e0e86        result_1 = sub_6e267e(eax_187)
006e0e8b        goto label_6e1351
006e0df1        case 0x8b9
006e0df1        void*** eax_184 = operator new(0x408)
006e0df9        void*** var_18_150 = eax_184
006e0dfe        int32_t var_8_152 = 0xa3
006e0e05        if (eax_184 == 0)
006e0e05        goto label_6e134f
006e0e0b        result_1 = sub_72e342(eax_184)
006e0e10        goto label_6e1351
006e0e43        case 0x8c0
006e0e43        void*** eax_186 = operator new(0x408)
006e0e4b        void*** var_18_152 = eax_186
006e0e50        int32_t var_8_154 = 0xa5
006e0e57        if (eax_186 == 0)
006e0e57        goto label_6e134f
006e0e5d        result_1 = sub_729704(eax_186)
006e0e62        goto label_6e1351
006e0ae6        case 0x8c1
006e0ae6        void*** eax_165 = operator new(0x408)
006e0aee        void*** var_18_131 = eax_165
006e0af3        int32_t var_8_133 = 0x6b
006e0afa        if (eax_165 == 0)
006e0afa        goto label_6e134f
006e0b00        result_1 = sub_751c46(eax_165)
006e0b05        goto label_6e1351
006e0b61        case 0x8c2
006e0b61        void*** eax_168 = operator new(0x408)
006e0b69        void*** var_18_134 = eax_168
006e0b6e        int32_t var_8_136 = 0x6e
006e0b75        if (eax_168 == 0)
006e0b75        goto label_6e134f
006e0b7b        result_1 = sub_75272b(eax_168)
006e0b80        goto label_6e1351
006e0bb3        case 0x8c3
006e0bb3        void*** eax_170 = operator new(0x408)
006e0bbb        void*** var_18_136 = eax_170
006e0bc0        int32_t var_8_138 = 0x70
006e0bc7        if (eax_170 == 0)
006e0bc7        goto label_6e134f
006e0bcd        result_1 = sub_752250(eax_170)
006e0bd2        goto label_6e1351
006e0b38        case 0x8c4
006e0b38        void*** eax_167 = operator new(0x408)
006e0b40        void*** var_18_133 = eax_167
006e0b45        int32_t var_8_135 = 0x6d
006e0b4c        if (eax_167 == 0)
006e0b4c        goto label_6e134f
006e0b52        result_1 = sub_75207e(eax_167)
006e0b57        goto label_6e1351
006e0b0f        case 0x8c5
006e0b0f        void*** eax_166 = operator new(0x408)
006e0b17        void*** var_18_132 = eax_166
006e0b1c        int32_t var_8_134 = 0x6c
006e0b23        if (eax_166 == 0)
006e0b23        goto label_6e134f
006e0b29        result_1 = sub_752487(eax_166)
006e0b2e        goto label_6e1351
006e0bdc        case 0x8c6
006e0bdc        void*** eax_171 = operator new(0x408)
006e0be4        void*** var_18_137 = eax_171
006e0be9        int32_t var_8_139 = 0x71
006e0bf0        if (eax_171 == 0)
006e0bf0        goto label_6e134f
006e0bf6        result_1 = sub_752d26(eax_171)
006e0bfb        goto label_6e1351
006e0b8a        case 0x8c7
006e0b8a        void*** eax_169 = operator new(0x408)
006e0b92        void*** var_18_135 = eax_169
006e0b97        int32_t var_8_137 = 0x6f
006e0b9e        if (eax_169 == 0)
006e0b9e        goto label_6e134f
006e0ba4        result_1 = sub_75297f(eax_169)
006e0ba9        goto label_6e1351
006e0ee7        case 0x8ca
006e0ee7        void*** eax_190 = operator new(0x408)
006e0eef        void*** var_18_156 = eax_190
006e0ef4        int32_t var_8_158 = 0xa9
006e0efb        if (eax_190 == 0)
006e0efb        goto label_6e134f
006e0f01        result_1 = sub_759bfb(eax_190)
006e0f06        goto label_6e1351
006e0e95        case 0x8cb
006e0e95        void*** eax_188 = operator new(0x408)
006e0e9d        void*** var_18_154 = eax_188
006e0ea2        int32_t var_8_156 = 0xa7
006e0ea9        if (eax_188 == 0)
006e0ea9        goto label_6e134f
006e0eaf        result_1 = sub_759e41(eax_188)
006e0eb4        goto label_6e1351
006e0f10        case 0x8cc
006e0f10        void*** eax_191 = operator new(0x408)
006e0f18        void*** var_18_157 = eax_191
006e0f1d        int32_t var_8_159 = 0xab
006e0f24        if (eax_191 == 0)
006e0f24        goto label_6e134f
006e0f2a        result_1 = sub_6e2d6c(eax_191)
006e0f2f        goto label_6e1351
006e0ebe        case 0x8cd
006e0ebe        void*** eax_189 = operator new(0x408)
006e0ec6        void*** var_18_155 = eax_189
006e0ecb        int32_t var_8_157 = 0xa8
006e0ed2        if (eax_189 == 0)
006e0ed2        goto label_6e134f
006e0ed8        result_1 = sub_72e132(eax_189)
006e0edd        goto label_6e1351
006e0f64        if (eax_1 s<= 0x9c6)
006e0f6a        if (eax_1 == 0x9c6)
006e115f        void*** eax_212 = operator new(0x408)
006e1167        void*** var_18_169 = eax_212
006e116c        int32_t var_8_171 = 0xa1
006e1173        if (eax_212 == 0)
006e1173        goto label_6e134f
006e1179        result_1 = sub_7592fb(eax_212)
006e117e        goto label_6e1351
006e0f75        if (eax_1 s> 0x960)
006e109d        if (eax_1 == 0x961)
006e1136        void*** eax_211 = operator new(0x414)
006e113e        void*** var_18_168 = eax_211
006e1143        int32_t var_8_170 = 0x35
006e114a        if (eax_211 == 0)
006e114a        goto label_6e134f
006e1150        result_1 = sub_6f8f5f(eax_211)
006e1155        goto label_6e1351
006e10a6        if (eax_1 == 0x96a)
006e110d        void*** eax_210 = operator new(0x408)
006e1115        void*** var_18_167 = eax_210
006e111a        int32_t var_8_169 = 0x89
006e1121        if (eax_210 == 0)
006e1121        goto label_6e134f
006e1127        result_1 = sub_74a6fb(eax_210)
006e112c        goto label_6e1351
006e10ab        if (eax_1 == 0x974)
006e10e4        void*** eax_209 = operator new(0x408)
006e10ec        void*** var_18_166 = eax_209
006e10f1        int32_t var_8_168 = 0xb5
006e10f8        if (eax_209 == 0)
006e10f8        goto label_6e134f
006e10fe        result_1 = sub_7593d9(eax_209)
006e1103        goto label_6e1351
006e10b0        if (eax_1 == 0x9c5)
006e10bb        void*** eax_208 = operator new(0x408)
006e10c3        void*** var_18_165 = eax_208
006e10c8        int32_t var_8_167 = 0xad
006e10cf        if (eax_208 == 0)
006e10cf        goto label_6e134f
006e10d5        result_1 = sub_759776(eax_208)
006e10da        goto label_6e1351
006e137b        result = nullptr
006e0f7b        switch (eax_1)
006e0f81        case 0x910
006e104b        void*** eax_202 = operator new(0x408)
006e1053        void*** var_18_163 = eax_202
006e1058        int32_t var_8_165 = 0x73
006e105f        if (eax_202 == 0)
006e105f        goto label_6e134f
006e1065        result_1 = CMsgSubProfession__Ctor(eax_202)
006e106a        goto label_6e1351
006e0f8c        case 0x91a
006e1022        void*** eax_201 = operator new(0x408)
006e102a        void*** var_18_162 = eax_201
006e102f        int32_t var_8_164 = 0x84
006e1036        if (eax_201 == 0)
006e1036        goto label_6e134f
006e103c        result_1 = sub_74d417(eax_201)
006e1041        goto label_6e1351
006e0f95        case 0x91b
006e0ff9        void*** eax_200 = operator new(0x408)
006e1001        void*** var_18_161 = eax_200
006e1006        int32_t var_8_163 = 0x87
006e100d        if (eax_200 == 0)
006e100d        goto label_6e134f
006e1013        result_1 = sub_7599b4(eax_200)
006e1018        goto label_6e1351
006e0f98        case 0x91c
006e0fd0        void*** eax_199 = operator new(0x408)
006e0fd8        void*** var_18_160 = eax_199
006e0fdd        int32_t var_8_162 = 0x85
006e0fe4        if (eax_199 == 0)
006e0fe4        goto label_6e134f
006e0fea        result_1 = sub_759aa9(eax_199)
006e0fef        goto label_6e1351
006e0f9b        case 0x91d
006e0fa7        void*** eax_198 = operator new(0x408)
006e0faf        void*** var_18_159 = eax_198
006e0fb4        int32_t var_8_161 = 0x86
006e0fbb        if (eax_198 == 0)
006e0fbb        goto label_6e134f
006e0fc1        result_1 = sub_71c4f8(eax_198)
006e0fc6        goto label_6e1351
006e0f73        case 0x960
006e1074        void*** eax_203 = operator new(0x408)
006e107c        void*** var_18_164 = eax_203
006e1081        int32_t var_8_166 = 0x34
006e1088        if (eax_203 == 0)
006e1088        goto label_6e134f
006e108e        result_1 = CMsgMapInfo2400__Ctor(eax_203)
006e1093        goto label_6e1351
006e137b        result = nullptr
006e118a        if (eax_1 s> 0x9d8)
006e12b2        if (eax_1 == 0x2715)
006e1332        void*** eax_230 = operator new(0x408)
006e133a        void*** var_18_178 = eax_230
006e133f        int32_t var_8_181 = 0x1d
006e1346        if (eax_230 == 0)
006e1346        goto label_6e134f
006e1348        result_1 = CMsgEntityAction_Ctor(eax_230)
006e134d        goto label_6e1351
006e12b7        if (eax_1 == 0x271a)
006e1310        struct CMsgAction* message_3 = operator new(0x414)
006e1318        struct CMsgAction* message_7 = message_3
006e131d        int32_t var_8_180 = 0x11
006e1324        if (message_3 == 0)
006e1324        goto label_6e134f
006e1326        result_1 = CMsgAction_Ctor(message_3)
006e132b        goto label_6e1351
006e12bc        if (eax_1 == 0x271e)
006e12ee        void*** eax_229 = operator new(0x414)
006e12f6        void*** var_18_177 = eax_229
006e12fb        int32_t var_8_179 = 0x12
006e1302        if (eax_229 == 0)
006e1302        goto label_6e134f
006e1304        result_1 = CMsgPlayerSpawn__Ctor(eax_229)
006e1309        goto label_6e1351
006e12c1        if (eax_1 == 0x2721)
006e12cc        void*** eax_228 = operator new(0x408)
006e12d4        void*** var_18_176 = eax_228
006e12d9        int32_t var_8_178 = 0x1c
006e12e0        if (eax_228 == 0)
006e12e0        goto label_6e134f
006e12e2        result_1 = CMsgUserAttribEx__Create(eax_228)
006e12e7        goto label_6e1351
006e137b        result = nullptr
006e1190        switch (eax_1)
006e1196        case 0x9c8
006e1260        void*** eax_222 = operator new(0x408)
006e1268        void*** var_18_174 = eax_222
006e126d        int32_t var_8_176 = 0xb3
006e1274        if (eax_222 == 0)
006e1274        goto label_6e134f
006e127a        result_1 = sub_74c15f(eax_222)
006e127f        goto label_6e1351
006e11a1        case 0x9c9
006e1237        void*** eax_221 = operator new(0x408)
006e123f        void*** var_18_173 = eax_221
006e1244        int32_t var_8_175 = 0xb1
006e124b        if (eax_221 == 0)
006e124b        goto label_6e134f
006e1251        result_1 = sub_75904e(eax_221)
006e1256        goto label_6e1351
006e11a8        case 0x9ca
006e120e        void*** eax_220 = operator new(0x408)
006e1216        void*** var_18_172 = eax_220
006e121b        int32_t var_8_174 = 0xb2
006e1222        if (eax_220 == 0)
006e1222        goto label_6e134f
006e1228        result_1 = sub_7531bd(eax_220)
006e122d        goto label_6e1351
006e11ab        case 0x9cb
006e11e5        void*** eax_219 = operator new(0x408)
006e11ed        void*** var_18_171 = eax_219
006e11f2        int32_t var_8_173 = 0xb4
006e11f9        if (eax_219 == 0)
006e11f9        goto label_6e134f
006e11ff        result_1 = sub_74b7ed(eax_219)
006e1204        goto label_6e1351
006e11ae        case 0x9ce
006e11bc        void*** eax_218 = operator new(0x414)
006e11c4        void*** var_18_170 = eax_218
006e11c9        int32_t var_8_172 = 0xae
006e11d0        if (eax_218 == 0)
006e11d0        goto label_6e134f
006e11d6        result_1 = sub_701ee1(eax_218)
006e11db        goto label_6e1351
006e1188        case 0x9d8
006e1289        struct CMsgStrCheckKey2520* eax_223 = operator new(0x408)
006e1291        struct CMsgStrCheckKey2520* var_18_175 = eax_223
006e1296        int32_t var_8_177 = 0x6a
006e129d        if (eax_223 == 0)
006e129d        goto label_6e134f
006e12a3        result_1 = CMsgStrCheckKey2520__Ctor(eax_223)
006e12a8        goto label_6e1351
006e137b        result = nullptr
006df3fb        if (eax_1 == 0x520)
006dff2c        void*** eax_70 = operator new(0x414)
006dff34        void*** var_18_67 = eax_70
006dff39        int32_t var_8_69 = 0x78
006dff40        if (eax_70 == 0)
006e134f        label_6e134f:
006e134f        result_1 = nullptr
006e134f        goto label_6e1351
006dff46        result_1 = sub_703be1(eax_70)
006e1351        label_6e1351:
006e1351        int32_t var_8_182 = 0xffffffff
006e1359        if (result_1 == 0)
006e137b        result = nullptr
006e136a        if ((*result_1)[1](arg1, arg2) != 0)
006e13b0        result = result_1
006e1372        int32_t var_8_183 = 0xb6
006e1379        (**result_1)(1)
006e137b        result = nullptr
006df40d        if (eax_1 - 0x3ea u> 0x95)
006e137b        result = nullptr
006df40d        switch (eax_1)
006df49e        case 0x3ea
006df49e        void*** eax_7 = operator new(0x408)
006df4a6        void*** var_18_4 = eax_7
006df4ab        int32_t var_8_3 = 6
006df4b2        if (eax_7 == 0)
006df4b2        goto label_6e134f
006df4b8        result_1 = sub_753f88(eax_7)
006df4bd        goto label_6e1351
006e137b        case 0x3eb, 0x3ed, 0x3ef, 0x3f2, 0x3f3, 0x3f5, 0x3f6, 0x3f9, 0x3fa, 0x3fc, 0x3fd, 0x406, 0x407, 0x414, 0x415, 0x416, 0x417, 0x418, 0x419, 0x41a, 0x41b, 0x41d, 0x41e, 0x424, 0x428, 0x42b, 0x42c, 0x42d, 0x42e, 0x430, 0x431, 0x434, 0x435, 0x436, 0x437, 0x438, 0x43a, 0x43c, 0x43d, 0x43e, 0x43f, 0x440, 0x441, 0x442, 0x443, 0x444, 0x445, 0x446, 0x447, 0x448, 0x449, 0x44a, 0x44b, 0x44c, 0x45c, 0x45d, 0x45e, 0x45f, 0x460, 0x461, 0x462, 0x463, 0x464, 0x465, 0x46b, 0x46c, 0x46d, 0x470, 0x471, 0x472, 0x473, 0x474, 0x475, 0x476, 0x477, 0x478, 0x479, 0x47a, 0x47b, 0x47c, 0x47d
006e137b        result = nullptr
006df4c7        case 0x3ec
006df4c7        void*** eax_8 = operator new(0x414)
006df4cf        void*** var_18_5 = eax_8
006df4d4        int32_t var_8_4 = 0x10
006df4db        if (eax_8 == 0)
006df4db        goto label_6e134f
006df4e1        result_1 = CMsgTalk__Ctor(eax_8)
006df4e6        goto label_6e1351
006df519        case 0x3ee
006df519        void*** eax_10 = operator new(0x414)
006df521        void*** var_18_7 = eax_10
006df526        int32_t var_8_6 = 0x14
006df52d        if (eax_10 == 0)
006df52d        goto label_6e134f
006df533        result_1 = CMsgUserInfo__Ctor(eax_10)
006df538        goto label_6e1351
006df5bd        case 0x3f0
006df5bd        void*** eax_13 = operator new(0x408)
006df5c5        void*** var_18_10 = eax_13
006df5ca        int32_t var_8_10 = 0x18
006df5d1        if (eax_13 == 0)
006df5d1        goto label_6e134f
006df5d7        result_1 = CMsgItem__Ctor(eax_13)
006df5dc        goto label_6e1351
006df56b        case 0x3f1
006df56b        void*** eax_11 = operator new(0x408)
006df573        void*** var_18_8 = eax_11
006df578        int32_t var_8_8 = 0x16
006df57f        if (eax_11 == 0)
006df57f        goto label_6e134f
006df585        result_1 = CMsgTick__Ctor(eax_11)
006df58a        goto label_6e1351
006df4f0        case 0x3f4
006df4f0        void*** eax_9 = operator new(0x408)
006df4f8        void*** var_18_6 = eax_9
006df4fd        int32_t var_8_5 = 0x13
006df504        if (eax_9 == 0)
006df504        goto label_6e134f
006df50a        result_1 = sub_764997(eax_9)
006df50f        goto label_6e1351
006df60f        case 0x3f7
006df60f        void*** eax_14 = operator new(0x414)
006df617        void*** var_18_11 = eax_14
006df61c        int32_t var_8_12 = 0x1a
006df623        if (eax_14 == 0)
006df623        goto label_6e134f
006df629        result_1 = sub_73ecc9(eax_14)
006df62e        goto label_6e1351
006df9e7        case 0x3f8
006df9e7        void*** eax_38 = operator new(0x408)
006df9ef        void*** var_18_35 = eax_38
006df9f4        int32_t var_8_36 = 0x42
006df9fb        if (eax_38 == 0)
006df9fb        goto label_6e134f
006dfa01        result_1 = CMsgWeatherUpdate__Ctor(eax_38)
006dfa06        goto label_6e1351
006df542        case 0x3fb
006df542        void* message = operator new(0x408)
006df54a        void* message_4 = message
006df54f        int32_t var_8_7 = 0x15
006df556        if (message == 0)
006df556        goto label_6e134f
006df55c        result_1 = CMsgFriend__ctor(message)
006df561        goto label_6e1351
006df5e6        case 0x3fe
006df5e6        void* message_1 = operator new(0x408)
006df5ee        void* message_5 = message_1
006df5f3        int32_t var_8_11 = 0x19
006df5fa        if (message_1 == 0)
006df5fa        goto label_6e134f
006df600        result_1 = CMsgInteract__ctor(message_1)
006df605        goto label_6e1351
006df876        case 0x3ff
006df876        void*** eax_29 = operator new(0x408)
006df87e        void*** var_18_26 = eax_29
006df883        int32_t var_8_27 = 0x32
006df88a        if (eax_29 == 0)
006df88a        goto label_6e134f
006df890        result_1 = sub_72ac9a(eax_29)
006df895        goto label_6e1351
006dff03        case 0x400
006dff03        void*** eax_69 = operator new(0x408)
006dff0b        void*** var_18_66 = eax_69
006dff10        int32_t var_8_68 = 0xaf
006dff17        if (eax_69 == 0)
006dff17        goto label_6e134f
006dff1d        result_1 = sub_740951(eax_69)
006dff22        goto label_6e1351
006df7a9        case 0x401
006df7a9        void*** eax_24 = operator new(0x408)
006df7b1        void*** var_18_21 = eax_24
006df7b6        int32_t var_8_22 = 0x2c
006df7bd        if (eax_24 == 0)
006df7bd        goto label_6e134f
006df7c3        result_1 = sub_761fd0(eax_24)
006df7c8        goto label_6e1351
006df89f        case 0x402
006df89f        void*** eax_30 = operator new(0x408)
006df8a7        void*** var_18_27 = eax_30
006df8ac        int32_t var_8_28 = 0x33
006df8b3        if (eax_30 == 0)
006df8b3        goto label_6e134f
006df8b9        result_1 = CMsgTeamMember1026__Ctor(eax_30)
006df8be        goto label_6e1351
006dfa10        case 0x403
006dfa10        void*** eax_39 = operator new(0x408)
006dfa18        void*** var_18_36 = eax_39
006dfa1d        int32_t var_8_37 = 0x44
006dfa24        if (eax_39 == 0)
006dfa24        goto label_6e134f
006dfa2a        result_1 = sub_7533ae(eax_39)
006dfa2f        goto label_6e1351
006df44c        case 0x404
006df44c        void*** eax_5 = operator new(0x408)
006df454        void*** var_18_2 = eax_5
006df459        int32_t var_8_1 = 1
006df460        if (eax_5 == 0)
006df460        goto label_6e134f
006df466        result_1 = sub_7534a1(eax_5)
006df46b        goto label_6e1351
006dfb58        case 0x405
006dfb58        void*** eax_46 = operator new(0x408)
006dfb60        void*** var_18_43 = eax_46
006dfb65        int32_t var_8_45 = 0x50
006dfb6c        if (eax_46 == 0)
006dfb6c        goto label_6e134f
006dfb72        result_1 = CMsgTeamAward__Create(eax_46)
006dfb77        goto label_6e1351
006dfb81        case 0x408
006dfb81        void*** eax_47 = operator new(0x408)
006dfb89        void*** var_18_44 = eax_47
006dfb8e        int32_t var_8_46 = 0x51
006dfb95        if (eax_47 == 0)
006dfb95        goto label_6e134f
006dfb9b        result_1 = sub_75e304(eax_47)
006dfba0        goto label_6e1351
006dfbaa        case 0x409
006dfbaa        void*** eax_48 = operator new(0x408)
006dfbb2        void*** var_18_45 = eax_48
006dfbb7        int32_t var_8_47 = 0x5b
006dfbbe        if (eax_48 == 0)
006dfbbe        goto label_6e134f
006dfbc4        result_1 = sub_74a4e6(eax_48)
006dfbc9        goto label_6e1351
006dfbd3        case 0x40a
006dfbd3        void*** eax_49 = operator new(0x408)
006dfbdb        void*** var_18_46 = eax_49
006dfbe0        int32_t var_8_48 = 0x62
006dfbe7        if (eax_49 == 0)
006dfbe7        goto label_6e134f
006dfbed        result_1 = sub_75df38(eax_49)
006dfbf2        goto label_6e1351
006dfbfc        case 0x40b
006dfbfc        void*** eax_50 = operator new(0x408)
006dfc04        void*** var_18_47 = eax_50
006dfc09        int32_t var_8_49 = 0x63
006dfc10        if (eax_50 == 0)
006dfc10        goto label_6e134f
006dfc16        result_1 = sub_75db5b(eax_50)
006dfc1b        goto label_6e1351
006df475        case 0x40c
006df475        void*** eax_6 = operator new(0x408)
006df47d        void*** var_18_3 = eax_6
006df482        int32_t var_8_2 = 3
006df489        if (eax_6 == 0)
006df489        goto label_6e134f
006df48f        result_1 = sub_716545(eax_6)
006df494        goto label_6e1351
006dfc4e        case 0x40d
006dfc4e        void*** eax_52 = operator new(0x408)
006dfc56        void*** var_18_49 = eax_52
006dfc5b        int32_t var_8_51 = 0x76
006dfc62        if (eax_52 == 0)
006dfc62        goto label_6e134f
006dfc68        result_1 = sub_743f64(eax_52)
006dfc6d        goto label_6e1351
006dfde8        case 0x40e
006dfde8        void*** eax_62 = operator new(0x408)
006dfdf0        void*** var_18_59 = eax_62
006dfdf5        int32_t var_8_61 = 0x95
006dfdf8        if (eax_62 == 0)
006dfdf8        goto label_6e134f
006dfdfe        result_1 = sub_717afa(eax_62)
006dfe03        goto label_6e1351
006dfe0d        case 0x40f
006dfe0d        void*** eax_63 = operator new(0x414)
006dfe15        void*** var_18_60 = eax_63
006dfe1a        int32_t var_8_62 = 0x96
006dfe21        if (eax_63 == 0)
006dfe21        goto label_6e134f
006dfe27        result_1 = sub_72b91e(eax_63)
006dfe2c        goto label_6e1351
006df72e        case 0x410
006df72e        void*** eax_21 = operator new(0x408)
006df736        void*** var_18_18 = eax_21
006df73b        int32_t var_8_19 = 0x27
006df742        if (eax_21 == 0)
006df742        goto label_6e134f
006df748        result_1 = sub_72ccef(eax_21)
006df74d        goto label_6e1351
006df780        case 0x411
006df780        void*** eax_23 = operator new(0x408)
006df788        void*** var_18_20 = eax_23
006df78d        int32_t var_8_21 = 0x2b
006df794        if (eax_23 == 0)
006df794        goto label_6e134f
006df79a        result_1 = CMsgEnemyList__ctor(eax_23)
006df79f        goto label_6e1351
006df7fb        case 0x412
006df7fb        void*** eax_26 = operator new(0x408)
006df803        void*** var_18_23 = eax_26
006df808        int32_t var_8_24 = 0x2e
006df80f        if (eax_26 == 0)
006df80f        goto label_6e134f
006df815        result_1 = CMsgGuide__Create(eax_26)
006df81a        goto label_6e1351
006dfeda        case 0x413
006dfeda        void*** eax_68 = operator new(0x408)
006dfee2        void*** var_18_65 = eax_68
006dfee7        int32_t var_8_67 = 0xac
006dfeee        if (eax_68 == 0)
006dfeee        goto label_6e134f
006dfef4        result_1 = sub_720357(eax_68)
006dfef9        goto label_6e1351
006df7d2        case 0x41c
006df7d2        void*** eax_25 = operator new(0x408)
006df7da        void*** var_18_22 = eax_25
006df7df        int32_t var_8_23 = 0x2d
006df7e6        if (eax_25 == 0)
006df7e6        goto label_6e134f
006df7ec        result_1 = CMsgLoginBootstrap1052__Ctor(eax_25)
006df7f1        goto label_6e1351
006df824        case 0x41f
006df824        void*** eax_27 = operator new(0x408)
006df82c        void*** var_18_24 = eax_27
006df831        int32_t var_8_25 = 0x2f
006df838        if (eax_27 == 0)
006df838        goto label_6e134f
006df83e        result_1 = CMsgAccountAuthResponse__Ctor(eax_27)
006df843        goto label_6e1351
006df68a        case 0x420
006df68a        void*** eax_17 = operator new(0x408)
006df692        void*** var_18_14 = eax_17
006df697        int32_t var_8_15 = 0x1f
006df69e        if (eax_17 == 0)
006df69e        goto label_6e134f
006df6a4        result_1 = sub_7622f4(eax_17)
006df6a9        goto label_6e1351
006df84d        case 0x421
006df84d        void*** eax_28 = operator new(0x408)
006df855        void*** var_18_25 = eax_28
006df85a        int32_t var_8_26 = 0x30
006df861        if (eax_28 == 0)
006df861        goto label_6e134f
006df867        result_1 = CMsgAccountAuthResponse1057__Ctor(eax_28)
006df86c        goto label_6e1351
006df6b3        case 0x422
006df6b3        void*** eax_18 = operator new(0x408)
006df6bb        void*** var_18_15 = eax_18
006df6c0        int32_t var_8_16 = 0x20
006df6c7        if (eax_18 == 0)
006df6c7        goto label_6e134f
006df6cd        result_1 = sub_701c52(eax_18)
006df6d2        goto label_6e1351
006df426        case 0x423
006df426        void*** eax_4 = operator new(0x408)
006df42e        void*** var_18_1 = eax_4
006df431        int32_t var_8 = 0
006df437        if (eax_4 == 0)
006df437        goto label_6e134f
006df43d        result_1 = sub_764b3d(eax_4)
006df442        goto label_6e1351
006df6dc        case 0x425
006df6dc        void*** eax_19 = operator new(0x408)
006df6e4        void*** var_18_16 = eax_19
006df6e9        int32_t var_8_17 = 0x23
006df6f0        if (eax_19 == 0)
006df6f0        goto label_6e134f
006df6f6        result_1 = CMsg1060__Ctor(eax_19)
006df6fb        goto label_6e1351
006dfe5f        case 0x426
006dfe5f        void*** eax_65 = operator new(0x408)
006dfe67        void*** var_18_62 = eax_65
006dfe6c        int32_t var_8_64 = 0x98
006dfe73        if (eax_65 == 0)
006dfe73        goto label_6e134f
006dfe79        result_1 = sub_75d5fd(eax_65)
006dfe7e        goto label_6e1351
006dfe88        case 0x427
006dfe88        void*** eax_66 = operator new(0x408)
006dfe90        void*** var_18_63 = eax_66
006dfe95        int32_t var_8_65 = 0x99
006dfe9c        if (eax_66 == 0)
006dfe9c        goto label_6e134f
006dfea2        result_1 = sub_6f448c(eax_66)
006dfea7        goto label_6e1351
006dfca0        case 0x429
006dfca0        void*** eax_54 = operator new(0x408)
006dfca8        void*** var_18_51 = eax_54
006dfcad        int32_t var_8_53 = 0x7c
006dfcb4        if (eax_54 == 0)
006dfcb4        goto label_6e134f
006dfcba        result_1 = sub_6f942f(eax_54)
006dfcbf        goto label_6e1351
006dfeb1        case 0x42a
006dfeb1        void*** eax_67 = operator new(0x408)
006dfeb9        void*** var_18_64 = eax_67
006dfebe        int32_t var_8_66 = 0x9e
006dfec5        if (eax_67 == 0)
006dfec5        goto label_6e134f
006dfecb        result_1 = sub_716722(eax_67)
006dfed0        goto label_6e1351
006df757        case 0x42f
006df757        void*** eax_22 = operator new(0x408)
006df75f        void*** var_18_19 = eax_22
006df764        int32_t var_8_20 = 0x2a
006df76b        if (eax_22 == 0)
006df76b        goto label_6e134f
006df771        result_1 = sub_76208e(eax_22)
006df776        goto label_6e1351
006dfd96        case 0x432
006dfd96        void*** eax_60 = operator new(0x408)
006dfd9e        void*** var_18_57 = eax_60
006dfda3        int32_t var_8_59 = 0x91
006dfdaa        if (eax_60 == 0)
006dfdaa        goto label_6e134f
006dfdb0        result_1 = sub_75d874(eax_60)
006dfdb5        goto label_6e1351
006dfd44        case 0x433
006dfd44        void*** eax_58 = operator new(0x408)
006dfd4c        void*** var_18_55 = eax_58
006dfd51        int32_t var_8_57 = 0x8f
006dfd58        if (eax_58 == 0)
006dfd58        goto label_6e134f
006dfd5e        result_1 = CMsgPictureKey1075__Ctor(eax_58)
006dfd63        goto label_6e1351
006dfd6d        case 0x439
006dfd6d        void*** eax_59 = operator new(0x414)
006dfd75        void*** var_18_56 = eax_59
006dfd7a        int32_t var_8_58 = 0x90
006dfd81        if (eax_59 == 0)
006dfd81        goto label_6e134f
006dfd87        result_1 = sub_75d90e(eax_59)
006dfd8c        goto label_6e1351
006dfdbf        case 0x43b
006dfdbf        void*** eax_61 = operator new(0x408)
006dfdc7        void*** var_18_58 = eax_61
006dfdcc        int32_t var_8_60 = 0x92
006dfdd3        if (eax_61 == 0)
006dfdd3        goto label_6e134f
006dfdd9        result_1 = sub_714b0b(eax_61)
006dfdde        goto label_6e1351
006df661        case 0x44d
006df661        void*** eax_16 = operator new(0x408)
006df669        void*** var_18_13 = eax_16
006df66e        int32_t var_8_14 = 0x1e
006df675        if (eax_16 == 0)
006df675        goto label_6e134f
006df67b        result_1 = sub_73fda7(eax_16)
006df680        goto label_6e1351
006df705        case 0x44e
006df705        void*** eax_20 = operator new(0x408)
006df70d        void*** var_18_17 = eax_20
006df712        int32_t var_8_18 = 0x26
006df719        if (eax_20 == 0)
006df719        goto label_6e134f
006df71f        result_1 = CMsgAccount1102__Ctor(eax_20)
006df724        goto label_6e1351
006df91a        case 0x44f
006df91a        void*** eax_33 = operator new(0x408)
006df922        void*** var_18_30 = eax_33
006df927        int32_t var_8_31 = 0x39
006df92e        if (eax_33 == 0)
006df92e        goto label_6e134f
006df934        result_1 = sub_760abc(eax_33)
006df939        goto label_6e1351
006df8c8        case 0x450
006df8c8        void*** eax_31 = operator new(0x408)
006df8d0        void*** var_18_28 = eax_31
006df8d5        int32_t var_8_29 = 0x36
006df8dc        if (eax_31 == 0)
006df8dc        goto label_6e134f
006df8e2        result_1 = CMsgFlushExp1104__ctor(eax_31)
006df8e7        goto label_6e1351
006df8f1        case 0x451
006df8f1        void*** eax_32 = operator new(0x408)
006df8f9        void*** var_18_29 = eax_32
006df8fe        int32_t var_8_30 = 0x38
006df905        if (eax_32 == 0)
006df905        goto label_6e134f
006df90b        result_1 = sub_760b79(eax_32)
006df910        goto label_6e1351
006df9be        case 0x452
006df9be        void* eax_37 = operator new(0x408)
006df9c6        void* var_18_34 = eax_37
006df9cb        int32_t var_8_35 = 0x41
006df9d2        if (eax_37 == 0)
006df9d2        goto label_6e134f
006df9d8        result_1 = CMsgSyndicateAttributeInfo1106__Ctor(eax_37)
006df9dd        goto label_6e1351
006df943        case 0x453
006df943        void*** eax_34 = operator new(0x414)
006df94b        void*** var_18_31 = eax_34
006df950        int32_t var_8_32 = 0x3a
006df957        if (eax_34 == 0)
006df957        goto label_6e134f
006df95d        result_1 = sub_702520(eax_34)
006df962        goto label_6e1351
006dfa39        case 0x454
006dfa39        void*** eax_40 = operator new(0x408)
006dfa41        void*** var_18_37 = eax_40
006dfa46        int32_t var_8_38 = 0x46
006dfa4d        if (eax_40 == 0)
006dfa4d        goto label_6e134f
006dfa53        result_1 = sub_75f94e(eax_40)
006dfa58        goto label_6e1351
006dfa62        case 0x455
006dfa62        void*** eax_41 = operator new(0x414)
006dfa6a        void*** var_18_38 = eax_41
006dfa6f        int32_t var_8_39 = 0x47
006dfa76        if (eax_41 == 0)
006dfa76        goto label_6e134f
006dfa7c        result_1 = sub_75eeb0(eax_41)
006dfa81        goto label_6e1351
006dfa8b        case 0x456
006dfa8b        void* message_2 = operator new(0x408)
006dfa93        void* message_6 = message_2
006dfa98        int32_t var_8_40 = 0x48
006dfa9f        if (message_2 == 0)
006dfa9f        goto label_6e134f
006dfaa5        result_1 = CMsgMapInfo1110__Ctor(message_2)
006dfaaa        goto label_6e1351
006dfadd        case 0x457
006dfadd        void*** eax_43 = operator new(0x414)
006dfae5        void*** var_18_40 = eax_43
006dfaea        int32_t var_8_42 = 0x4a
006dfaf1        if (eax_43 == 0)
006dfaf1        goto label_6e134f
006dfaf7        result_1 = sub_75ed21(eax_43)
006dfafc        goto label_6e1351
006dfb06        case 0x458
006dfb06        void*** eax_44 = operator new(0x408)
006dfb0e        void*** var_18_41 = eax_44
006dfb13        int32_t var_8_43 = 0x4b
006dfb1a        if (eax_44 == 0)
006dfb1a        goto label_6e134f
006dfb20        result_1 = sub_75ebfc(eax_44)
006dfb25        goto label_6e1351
006dfb2f        case 0x459
006dfb2f        void*** eax_45 = operator new(0x408)
006dfb37        void*** var_18_42 = eax_45
006dfb3c        int32_t var_8_44 = 0x4d
006dfb43        if (eax_45 == 0)
006dfb43        goto label_6e134f
006dfb49        result_1 = sub_75e53b(eax_45)
006dfb4e        goto label_6e1351
006df638        case 0x45a
006df638        void*** eax_15 = operator new(0x408)
006df640        void*** var_18_12 = eax_15
006df645        int32_t var_8_13 = 0x1b
006df64c        if (eax_15 == 0)
006df64c        goto label_6e134f
006df652        result_1 = sub_7624e8(eax_15)
006df657        goto label_6e1351
006dfe36        case 0x45b
006dfe36        void*** eax_64 = operator new(0x408)
006dfe3e        void*** var_18_61 = eax_64
006dfe43        int32_t var_8_63 = 0x97
006dfe4a        if (eax_64 == 0)
006dfe4a        goto label_6e134f
006dfe50        result_1 = CMsgKickoutNotice__Create(eax_64)
006dfe55        goto label_6e1351
006dfc25        case 0x466
006dfc25        void*** eax_51 = operator new(0x408)
006dfc2d        void*** var_18_48 = eax_51
006dfc32        int32_t var_8_50 = 0x64
006dfc39        if (eax_51 == 0)
006dfc39        goto label_6e134f
006dfc3f        result_1 = sub_72c76e(eax_51)
006dfc44        goto label_6e1351
006dfcc9        case 0x467
006dfcc9        void*** eax_55 = operator new(0x408)
006dfcd1        void*** var_18_52 = eax_55
006dfcd6        int32_t var_8_54 = 0x7f
006dfcdd        if (eax_55 == 0)
006dfcdd        goto label_6e134f
006dfce3        result_1 = sub_6ed9f1(eax_55)
006dfce8        goto label_6e1351
006dfcf2        case 0x468
006dfcf2        void*** eax_56 = operator new(0x408)
006dfcfa        void*** var_18_53 = eax_56
006dfcff        int32_t var_8_55 = 0x8a
006dfd06        if (eax_56 == 0)
006dfd06        goto label_6e134f
006dfd0c        result_1 = sub_72a561(eax_56)
006dfd11        goto label_6e1351
006dfd1b        case 0x469
006dfd1b        void*** eax_57 = operator new(0x408)
006dfd23        void*** var_18_54 = eax_57
006dfd28        int32_t var_8_56 = 0x8d
006dfd2f        if (eax_57 == 0)
006dfd2f        goto label_6e134f
006dfd35        result_1 = sub_75da61(eax_57)
006dfd3a        goto label_6e1351
006dfc77        case 0x46a
006dfc77        void*** eax_53 = operator new(0x408)
006dfc7f        void*** var_18_50 = eax_53
006dfc84        int32_t var_8_52 = 0x7b
006dfc8b        if (eax_53 == 0)
006dfc8b        goto label_6e134f
006dfc91        result_1 = sub_6ec7de(eax_53)
006dfc96        goto label_6e1351
006df96c        case 0x46e
006df96c        void*** eax_35 = operator new(0x408)
006df974        void*** var_18_32 = eax_35
006df979        int32_t var_8_33 = 0x3b
006df980        if (eax_35 == 0)
006df980        goto label_6e134f
006df986        result_1 = CMsgMissionSystemUpdate__Create(eax_35)
006df98b        goto label_6e1351
006df995        case 0x46f
006df995        void*** eax_36 = operator new(0x408)
006df99d        void*** var_18_33 = eax_36
006df9a2        int32_t var_8_34 = 0x3e
006df9a9        if (eax_36 == 0)
006df9a9        goto label_6e134f
006df9af        result_1 = sub_716b20(eax_36)
006df9b4        goto label_6e1351
006df594        case 0x47e
006df594        void*** eax_12 = operator new(0x408)
006df59c        void*** var_18_9 = eax_12
006df5a1        int32_t var_8_9 = 0x17
006df5a8        if (eax_12 == 0)
006df5a8        goto label_6e134f
006df5ae        result_1 = sub_76400b(eax_12)
006df5b3        goto label_6e1351
006dfab4        case 0x47f
006dfab4        void*** eax_42 = operator new(0x408)
006dfabc        void*** var_18_39 = eax_42
006dfac1        int32_t var_8_41 = 0x49
006dfac8        if (eax_42 == 0)
006dfac8        goto label_6e134f
006dface        result_1 = sub_706d07(eax_42)
006dfad3        goto label_6e1351
006e1382        fsbase->NtTib.ExceptionList = ExceptionList
006e138b        return result