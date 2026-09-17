# `graphic.dll` → `c3_core_dll.dll` imports (API dependency map)

## Purpose

In the 5517 client, `graphic.dll` delegates a large portion of the low-level rendering work to `c3_core_dll.dll` (module name appears as `C3_CORE_DLL` in `graphic.dll`'s import table).

Imported entry points as they appear in `graphic.dll`'s IAT, grouped by subsystem, so other documents can cite the correct owning module and the correct imported name.

## Device / frame lifecycle

- `0x1003906C` `?Begin3D@@YAHXZ`
- `0x10039050` `?CalcRate@@YAKXZ`
- `0x1003904C` `?CapScreen@@YAXPAD@Z`
- `0x1003905C` `?ChangeDisplayResolution@@YAHKK@Z`
- `0x10039058` `?ChangeViewportResolution@@YAHKK@Z`
- `0x100390E0` `?ClearBuffer@@YAHHHK@Z`
- `0x10039068` `?End3D@@YAHXZ`
- `0x10039060` `?Flip@@YAHPBUtagRECT@@0PAUHWND__@@@Z`
- `0x10039048` `?HintGraphicDetail@@YAHK@Z`
- `0x10039074` `?IfDeviceLost@@YAHXZ`
- `0x1003907C` `?Init3DEx@@YAHPAUHWND__@@KKHK@Z`
- `0x10039078` `?Quit3D@@YAXXZ`
- `0x100390DC` `?ResetDevice@@YAHXZ`
- `0x10039130` `?g_D3DDevice@@3PAUIDirect3DDevice8@@A`
- `0x10039054` `?g_Present@@3U_D3DPRESENT_PARAMETERS_@@A`
- `0x10039064` `?g_dwTriTotal@@3KA`
- `0x10039034` `?g_nLocaleCodePage@@3IA`

## Camera

- `0x100390C4` `?Camera_BuildOrtho@@YAHPAUC3Camera@@MM@Z`
- `0x100390C0` `?Camera_BuildProject@@YAHPAUC3Camera@@@Z`
- `0x100390A8` `?Camera_BuildProjectEx@@YAHPAUC3Camera@@@Z`
- `0x100390BC` `?Camera_BuildView@@YAHPAUC3Camera@@@Z`
- `0x100390C8` `?Camera_Clear@@YAXPAUC3Camera@@@Z`

## Fonts / text

- `0x10039038` `?Font_AddFontSizeLevel@@YAXH@Z`
- `0x1003902C` `?Font_CheckPixel@@YAHPAUC3Font@@PBDK@Z`
- `0x10039030` `?Font_CloseSys@@YAXXZ`
- `0x1003903C` `?Font_Create@@YAHPAPAUC3Font@@PBDH_N@Z`
- `0x10039020` `?Font_Draw@@YAHPAUC3Font@@MMKPBDW4RENDER_TEXT_STYLE@@KJJ@Z`
- `0x10039010` `?Font_DrawArabic@@YAHPAUC3Font@@MMKG_NHW4RENDER_TEXT_STYLE@@KJJ@Z`
- `0x1003901C` `?Font_DrawBegin@@YAXXZ`
- `0x10039028` `?Font_DrawEnd@@YA_NXZ`
- `0x100390D4` `?Font_DrawW@@YAHPAUC3Font@@MMKGW4RENDER_TEXT_STYLE@@KJJ@Z`
- `0x10039018` `?Font_GetStrShowLen@@YAHPAUC3Font@@QBE@Z`
- `0x10039014` `?Font_GetStrShowLenArabic@@YAHPAUC3Font@@G_NH@Z`
- `0x100390D8` `?Font_GetStrShowLenW@@YAHPAUC3Font@@G@Z`
- `0x10039024` `?Font_Prepare@@YAXXZ`
- `0x10039040` `?Font_Release@@YAXPAPAUC3Font@@@Z`
- `0x10039070` `?Font_SetTextCornerColor@@YAXKKKK@Z`

## Sprites

- `0x1003923C` `?Sprite_Clear@@YAXPAUC3Sprite@@@Z`
- `0x10039084` `?Sprite_Create@@YAHPAPAUC3Sprite@@KKKW4_D3DFORMAT@@W4_D3DPOOL@@@Z`
- `0x10039090` `?Sprite_CreateEx@@YAPAUC3Sprite@@PAUC3Texture@@@Z`
- `0x100391EC` `?Sprite_Draw@@YAHPAUC3Sprite@@K@Z`
- `0x100391FC` `?Sprite_DrawEx@@YAHPAUC3Sprite@@KK@Z`
- `0x100390A4` `?Sprite_DrawListBatch@@YAHPAUC3Sprite@@PAUSpriteVertex@@K@Z`
- `0x10039098` `?Sprite_Load@@YAHPAPAUC3Sprite@@PBDW4_D3DPOOL@@HK@Z`
- `0x10039088` `?Sprite_Lock@@YAHPAUC3Sprite@@PAUtagRECT@@PAU_D3DLOCKED_RECT@@@Z`
- `0x100390D0` `?Sprite_Prepare@@YAXXZ`
- `0x10039080` `?Sprite_ReLoadNoFilter@@YAHPAPAUC3Sprite@@PADW4_D3DPOOL@@HK@Z`
- `0x100391F0` `?Sprite_Rotate@@YAXPAUC3Sprite@@H@Z`
- `0x10039094` `?Sprite_SetColor@@YAXPAUC3Sprite@@EEEE@Z`
- `0x100391F4` `?Sprite_SetColor@@YAXPAUC3Sprite@@K@Z`
- `0x100391F8` `?Sprite_SetCoor@@YAXPAUC3Sprite@@PAUtagRECT@@HHKK@Z`
- `0x1003909C` `?Sprite_Unload@@YAXPAPAUC3Sprite@@@Z`
- `0x1003908C` `?Sprite_Unlock@@YAHPAUC3Sprite@@@Z`

## Textures

- `0x10039200` `?Texture_Create@@YAHPAPAUC3Texture@@KKKW4_D3DFORMAT@@W4_D3DPOOL@@KH@Z`
- `0x100391D8` `?Texture_Load@@YAHPAPAUC3Texture@@PBDKW4_D3DPOOL@@HKK@Z`
- `0x100391E0` `?Texture_LockRect@@YAHPAUC3Texture@@UtagRECT@@AAU_D3DLOCKED_RECT@@@Z`
- `0x100391E8` `?Texture_Reload@@YA_NPAUC3Texture@@KW4_D3DPOOL@@KK@Z`
- `0x100391DC` `?Texture_Unload@@YAXPAPAUC3Texture@@@Z`
- `0x100391E4` `?Texture_Unlock@@YAXPAUC3Texture@@@Z`

## Resource / datafile helpers

- `0x100390E4` `?Common_CloseRes@@YAXPAX@Z`
- `0x1003911C` `?Common_GetChunk@@YAXPAXPAUChunkHeader@@@Z`
- `0x10039128` `?Common_GetSeek@@YAJPAX@Z`
- `0x1003912C` `?Common_OpenRes@@YAPAXPBDAAKH@Z`
- `0x100391D0` `?Common_ReadRes@@YAKPAX0K@Z`
- `0x10039180` `?Common_Rotate@@YAXPAUD3DXMATRIX@@MMM@Z`
- `0x10039184` `?Common_Scale@@YAXPAUD3DXMATRIX@@MMM@Z`
- `0x10039124` `?Common_SeekRes@@YAXPAXHH@Z`
- `0x1003917C` `?Common_Translate@@YAXPAUD3DXMATRIX@@MMM@Z`
- `0x10039228` `?DataFile_Close@@YAXXZ`
- `0x10039224` `?DataFile_Open@@YAXPBD@Z`

## `Phy_*`

- `0x10039148` `?Phy_Calculate@@YAHPAUC3Phy@@HHUD3DXVECTOR3@@@Z`
- `0x10039150` `?Phy_Calculate_CPU@@YAHPAUC3Phy@@HHUD3DXVECTOR3@@_N@Z`
- `0x100391B8` `?Phy_Calculate_Lite@@YAHPAUC3Phy@@@Z`
- `0x100391C0` `?Phy_ChangeMixTexture@@YAXPAUC3Phy@@H@Z`
- `0x100391BC` `?Phy_ChangeTexture@@YAXPAUC3Phy@@H@Z`
- `0x10039140` `?Phy_ClearMatrix@@YAXPAUC3Phy@@@Z`
- `0x10039144` `?Phy_DrawNormal@@YAHPAUC3Phy@@ABU_D3DMATERIAL8@@ABUC3_TEX_SHADER_DESC@@ABUC3_PIPE_RENDER_DESC@@PBUC3_SHADOW_RENDER_DESC@@@Z`
- `0x1003914C` `?Phy_DrawNormal_CPU@@YAHPAUC3Phy@@ABU_D3DMATERIAL8@@ABUC3_TEX_SHADER_DESC@@ABUC3_PIPE_RENDER_DESC@@PBUC3_SHADOW_RENDER_DESC@@@Z`
- `0x100390A0` `?Phy_DrawUp@@YAHPAUPhyOutVertex@@PAGKKPAUC3Texture@@PBU_D3DMATERIAL8@@ABUC3_PIPE_RENDER_DESC@@H@Z`
- `0x100391C8` `?Phy_DynamicCreate@@YAPAUC3Phy@@KPAUD3DXVECTOR3@@PAUD3DXVECTOR2@@@Z`
- `0x100391D4` `?Phy_GetFaceProperty@@YAEPAUC3Phy@@H@Z`
- `0x10039208` `?Phy_LightEnable@@YAXHH@Z`
- `0x10039120` `?Phy_Load@@YAHPAPAUC3Phy@@PAXHHH@Z`
- `0x100391CC` `?Phy_LoadFaceProperty@@YA_NPAUC3Phy@@PAX@Z`
- `0x100391B0` `?Phy_Muliply@@YAXPAUC3Phy@@PBUD3DXMATRIX@@@Z`
- `0x10039158` `?Phy_Prepare@@YAXXZ`
- `0x100391C4` `?Phy_ProbeIntersection@@YA_NPAUC3Phy@@ABUD3DXVECTOR3@@1_NAAMPAH@Z`
- `0x100391B4` `?Phy_SetBlendFrame@@YAXPAUC3Phy@@K@Z`
- `0x10039238` `?Phy_SetCartoonSilhouetteColor@@YAXK@Z`
- `0x10039234` `?Phy_SetCartoonSilhouetteWidth@@YAXM@Z`
- `0x10039138` `?Phy_SetColor@@YAXPAUC3Phy@@MMMM@Z`
- `0x10039230` `?Phy_SetFluidReflectSpeed@@YAXMM@Z`
- `0x10039190` `?Phy_SetFrame@@YAXPAUC3Phy@@K@Z`
- `0x10039204` `?Phy_SetLight@@YAXHMMMKKM@Z`
- `0x10039210` `?Phy_SetLightAmbient@@YAXHK@Z`
- `0x1003920C` `?Phy_SetLightDiffuse@@YAXHK@Z`
- `0x10039044` `?Phy_SetLightDir@@YAXHMMM@Z`
- `0x10039218` `?Phy_SetLightPosition@@YAXHMMM@Z`
- `0x10039214` `?Phy_SetLightType@@YAXHW4C3_RENDER_LIGHT_TYPE@@@Z`
- `0x1003921C` `?Phy_SetPointLightAttenuation@@YAXHMMM@Z`
- `0x10039220` `?Phy_SetSpotLightFalloff@@YAXHMMM@Z`
- `0x10039154` `?Phy_SetStepCount@@YAXPAUC3Phy@@K@Z`
- `0x10039118` `?Phy_Unload@@YAXPAPAUC3Phy@@@Z`

## Globals

- `0x10039240` `?g_D3DCaps@@3U_D3DCAPS8@@A`
- `0x100390AC` `?g_DisplayMode@@3U_D3DDISPLAYMODE@@A`
- `0x10039134` `?g_IDMatrix@@3UD3DXMATRIX@@A`
- `0x10039178` `?g_InvViewMatrix@@3UD3DXMATRIX@@A`
- `0x100390B0` `?g_ProjectMatrix@@3UD3DXMATRIX@@A`
- `0x100390B8` `?g_ViewMatrix@@3UD3DXMATRIX@@A`
- `0x100390B4` `?g_Viewport@@3U_D3DVIEWPORT8@@A`

## Other

- `0x100390CC` `?IntersectTriangle@@YAHABUD3DXVECTOR3@@0000AAU1@@Z`
- `0x1003913C` `?Motion_GetMatrix@@YAXPAUC3Motion@@KHPAUD3DXMATRIX@@@Z`
- `0x1003922C` `?Motion_GetMatrix_Blend@@YAXABUC3MotionTracker@@KPAUD3DXMATRIX@@@Z`
- `0x10039110` `?Motion_Load@@YAHPAPAUC3Motion@@PAX@Z`
- `0x10039114` `?Motion_Unload@@YAXPAPAUC3Motion@@@Z`
- `0x1003919C` `C3ParticleType3_CreateTransformCache` (raw: `?Ptcl3_CreateInfo@@YAPAV?$map@HUPTCL3_MATRIX@@U?$less@H@std@@V?$allocator@UPTCL3_MATRIX@@@3@@std@@H@Z`)
- `0x100391AC` `C3ParticleType3_DestroyTransformCache` (raw: `?Ptcl3_DestroyInfo@@YAXPAV?$map@HUPTCL3_MATRIX@@U?$less@H@std@@V?$allocator@UPTCL3_MATRIX@@@3@@std@@@Z`)
- `0x100391A0` `C3ParticleType3_SetGravityVector` (raw: `?Ptcl3_SetGravity@@YAXPAUC3Ptcl3@@UD3DXVECTOR3@@@Z`)
- `0x10039198` `C3ParticleType12_CreateTransformCache` (raw: `?Ptcl_CreateInfo@@YAPAV?$map@HUPTCL_MATRIX@@U?$less@H@std@@V?$allocator@UPTCL_MATRIX@@@3@@std@@H@Z`)
- `0x100391A8` `C3ParticleType12_DestroyTransformCache` (raw: `?Ptcl_DestroyInfo@@YAXPAV?$map@HUPTCL_MATRIX@@U?$less@H@std@@V?$allocator@UPTCL_MATRIX@@@3@@std@@@Z`)
- `0x10039160` `C3ParticleType2_Draw` (raw: `?Ptcl_Draw@@YAHPAUC3Ptcl2@@PBUD3DXMATRIX@@KK@Z`)
- `0x1003915C` `C3ParticleType3_Draw` (raw: `?Ptcl_Draw@@YAHPAUC3Ptcl3@@PBUD3DXMATRIX@@KKPAUD3DXVECTOR3@@@Z`)
- `0x10039168` `C3ParticleType1_Draw` (raw: `?Ptcl_Draw@@YAHPAUC3Ptcl@@PBUD3DXMATRIX@@KK@Z`)
- `0x100390F8` `C3ParticleType2_LoadFromStream` (raw: `?Ptcl_Load@@YAHPAPAUC3Ptcl2@@PAX@Z`)
- `0x100390F0` `C3ParticleType3_LoadFromStream` (raw: `?Ptcl_Load@@YAHPAPAUC3Ptcl3@@PAX@Z`)
- `0x10039100` `C3ParticleType1_LoadFromStream` (raw: `?Ptcl_Load@@YAHPAPAUC3Ptcl@@PAX@Z`)
- `0x10039164` `C3ParticleType12_AdvanceFrame` (raw: `?Ptcl_NextFrame@@YAXPAUC3Ptcl@@H@Z`)
- `0x1003916C` `C3Particle_PrepareRenderState` (raw: `?Ptcl_Prepare@@YAXXZ`)
- `0x1003918C` `C3ParticleType12_SetFrameIndex` (raw: `?Ptcl_SetFrame@@YAXPAUC3Ptcl2@@K@Z`)
- `0x10039188` `C3ParticleType12_SetFrameIndex` (raw: `?Ptcl_SetFrame@@YAXPAUC3Ptcl@@K@Z`)
- `0x100390FC` `C3ParticleType2_Unload` (raw: `?Ptcl_Unload@@YAXPAPAUC3Ptcl2@@@Z`)
- `0x100390F4` `C3ParticleType2_Unload` (raw: `?Ptcl_Unload@@YAXPAPAUC3Ptcl3@@@Z`)
- `0x10039104` `C3ParticleType1_Unload` (raw: `?Ptcl_Unload@@YAXPAPAUC3Ptcl@@@Z`)
- `0x100391A4` `C3ParticleType3_SetExternalSpeedVector` (raw: `?Ptrl3_SetExternalSpeed@@YAXPAUC3Ptcl3@@UD3DXVECTOR3@@@Z`)
- `0x100390E8` `?SMotion_Load@@YAHPAPAUC3SMotion@@PAX@Z`
- `0x100390EC` `?SMotion_Unload@@YAXPAPAUC3SMotion@@@Z`
- `0x10039170` `C3Shape_Draw` (raw: `?Shape_Draw@@YAHPAUC3Shape@@PBUD3DXMATRIX@@KK@Z`)
- `0x10039108` `C3Shape_LoadFromStream` (raw: `?Shape_Load@@YAHPAPAUC3Shape@@HPAX@Z`)
- `0x10039174` `C3Shape_PrepareRenderState` (raw: `?Shape_Prepare@@YAXXZ`)
- `0x10039194` `C3Shape_SetFrameIndex` (raw: `?Shape_SetFrame@@YAXPAUC3Shape@@K@Z`)
- `0x1003910C` `C3Shape_Unload` (raw: `?Shape_Unload@@YAXPAPAUC3Shape@@@Z`)
