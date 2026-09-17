# `graphic.dll` — Exported Symbols (API Surface)

Exported symbols from `graphic.dll` as observed in the IDB. Names are recorded as they appear, mangled C++ exports included.

## `CMyBitmap` (class) exports
The DLL exports many `CMyBitmap::*` static entry points (only a subset shown here; see IDB for the complete list).
Examples (verified present as strings/symbols in the DLL):
- `?Init3DEx@CMyBitmap@@SAHPAUHWND__@@KKHK@Z`
- `?Begin3D@CMyBitmap@@SAHXZ`
- `?End3D@CMyBitmap@@SAHXZ`
- `?Flip@CMyBitmap@@SAHPBUtagRECT@@0PAUHWND__@@@Z`
- `?ClearBuffer@CMyBitmap@@SAHHHK@Z`
- `?IfDeviceLost@CMyBitmap@@SAHXZ`
- `?ResetDevice@CMyBitmap@@SAHXZ`
- `?GameFontCreate@CMyBitmap@@SAHXZ`
- `?GetDefaultFontName@CMyBitmap@@SAPBDXZ`
- `?ShowStringCommon@CMyBitmap@@SA?AUCMySize@@HHKPBD0HHW4RENDER_TEXT_STYLE@@KAAUCMyPos@@@Z`
- `?ShowStringW@CMyBitmap@@SA?AUCMySize@@HHKPBGPBDHHW4RENDER_TEXT_STYLE@@KAAUCMyPos@@@Z`
- `?QueryDevice@CMyBitmap@@SAPAUIDirect3DDevice8@@XZ`
- `?QueryPresentParameters@CMyBitmap@@SA?AU_D3DPRESENT_PARAMETERS_@@XZ`

Camera-related:
- `?GameCameraCreate@CMyBitmap@@SAHXZ`
- `?GameCameraDestroy@CMyBitmap@@SAXXZ`
- `?GameCameraBuild@CMyBitmap@@SAXUCMySize@@@Z`
- `?GameCameraBuild@CMyBitmap@@SAXXZ`
- `?GameCameraGetPos@CMyBitmap@@SAXAAM00K@Z`
- `?GameCameraSet@CMyBitmap@@SAXMMMK@Z`

## Non-member rendering entry points
The DLL also exports non-member functions used internally by the `CMyBitmap::*` wrappers (names appear in the IDB as export entries):
- `?Init3DEx@@YAHPAUHWND__@@KKHK@Z`
- `?Begin3D@@YAHXZ`
- `?End3D@@YAHXZ`
- `?Flip@@YAHPBUtagRECT@@0PAUHWND__@@@Z`
- `?ClearBuffer@@YAHHHK@Z`
- `?IfDeviceLost@@YAHXZ`
- `?ResetDevice@@YAHXZ`

## Sprite API (`C3Sprite`)
Export entries observed include:
- `?Sprite_Clear@@YAXPAUC3Sprite@@@Z`
- `?Sprite_Prepare@@YAXXZ`
- `?Sprite_Draw@@YAHPAUC3Sprite@@K@Z`
- `?Sprite_DrawEx@@YAHPAUC3Sprite@@KK@Z`
- `?Sprite_DrawListBatch@@YAHPAUC3Sprite@@PAUSpriteVertex@@K@Z`
- `?Sprite_Rotate@@YAXPAUC3Sprite@@H@Z`
- `?Sprite_SetColor@@YAXPAUC3Sprite@@K@Z`
- `?Sprite_SetColor@@YAXPAUC3Sprite@@EEEE@Z`
- `?Sprite_SetCoor@@YAXPAUC3Sprite@@PAUtagRECT@@HHKK@Z`
- `?Sprite_Create@@YAHPAPAUC3Sprite@@KKKW4_D3DFORMAT@@W4_D3DPOOL@@@Z`
- `?Sprite_CreateEx@@YAPAUC3Sprite@@PAUC3Texture@@@Z`
- `?Sprite_Load@@YAHPAPAUC3Sprite@@PBDW4_D3DPOOL@@HK@Z`
- `?Sprite_ReLoadNoFilter@@YAHPAPAUC3Sprite@@PADW4_D3DPOOL@@HK@Z`
- `?Sprite_Unload@@YAXPAPAUC3Sprite@@@Z`
- `?Sprite_Lock@@YAHPAUC3Sprite@@PAUtagRECT@@PAU_D3DLOCKED_RECT@@@Z`
- `?Sprite_Unlock@@YAHPAUC3Sprite@@@Z`

## Texture API (`C3Texture`)
Export entries observed include:
- `?Texture_Create@@YAHPAPAUC3Texture@@KKKW4_D3DFORMAT@@W4_D3DPOOL@@KH@Z`
- `?Texture_Load@@YAHPAPAUC3Texture@@PBDKW4_D3DPOOL@@HKK@Z`
- `?Texture_Reload@@YA_NPAUC3Texture@@KW4_D3DPOOL@@KK@Z`
- `?Texture_Unload@@YAXPAPAUC3Texture@@@Z`
- `?Texture_LockRect@@YAHPAUC3Texture@@UtagRECT@@AAU_D3DLOCKED_RECT@@@Z`
- `?Texture_Unlock@@YAXPAUC3Texture@@@Z`

## Font API (`C3Font`)
Export entries observed include:
- `?Font_Prepare@@YAXXZ`
- `?Font_DrawBegin@@YAXXZ`
- `?Font_DrawEnd@@YA_NXZ`
- `?Font_Create@@YAHPAPAUC3Font@@PBDH_N@Z`
- `?Font_Release@@YAXPAPAUC3Font@@@Z`
- `?Font_AddFontSizeLevel@@YAXH@Z`
- `?Font_CheckPixel@@YAHPAUC3Font@@PBDK@Z`
- `?Font_Draw@@YAHPAUC3Font@@MMKPBDW4RENDER_TEXT_STYLE@@KJJ@Z`
- `?Font_DrawW@@YAHPAUC3Font@@MMKGW4RENDER_TEXT_STYLE@@KJJ@Z`
- `?Font_DrawArabic@@YAHPAUC3Font@@MMKG_NHW4RENDER_TEXT_STYLE@@KJJ@Z`
- `?Font_GetStrShowLen@@YAHPAUC3Font@@QBE@Z`
- `?Font_GetStrShowLenW@@YAHPAUC3Font@@G@Z`
- `?Font_GetStrShowLenArabic@@YAHPAUC3Font@@G_NH@Z`
- `?Font_GetStrShowLenArabic@@YAHPAUC3Font@@G_NH@Z`
- `?Font_CloseSys@@YAXXZ`
- `?Font_SetTextCornerColor@@YAXKKKK@Z`

## `Phy_*` API (`C3Phy`)
Export entries observed include:
- `?Phy_Load@@YAHPAPAUC3Phy@@PAXHHH@Z`
- `?Phy_Unload@@YAXPAPAUC3Phy@@@Z`
- `?Phy_Prepare@@YAXXZ`
- `?Phy_Calculate@@YAHPAUC3Phy@@HHUD3DXVECTOR3@@@Z`
- `?Phy_Calculate_CPU@@YAHPAUC3Phy@@HHUD3DXVECTOR3@@_N@Z`
- `?Phy_Calculate_Lite@@YAHPAUC3Phy@@@Z`
- `?Phy_DrawNormal@@YAHPAUC3Phy@@ABU_D3DMATERIAL8@@ABUC3_TEX_SHADER_DESC@@ABUC3_PIPE_RENDER_DESC@@PBUC3_SHADOW_RENDER_DESC@@@Z`
- `?Phy_DrawNormal_CPU@@YAHPAUC3Phy@@ABU_D3DMATERIAL8@@ABUC3_TEX_SHADER_DESC@@ABUC3_PIPE_RENDER_DESC@@PBUC3_SHADOW_RENDER_DESC@@@Z`
- `?Phy_DrawUp@@YAHPAUPhyOutVertex@@PAGKKPAUC3Texture@@PBU_D3DMATERIAL8@@ABUC3_PIPE_RENDER_DESC@@H@Z`
- `?Phy_Muliply@@YAXPAUC3Phy@@PBUD3DXMATRIX@@@Z`
- `?Phy_ClearMatrix@@YAXPAUC3Phy@@@Z`
- `?Phy_SetFrame@@YAXPAUC3Phy@@K@Z`
- `?Phy_SetBlendFrame@@YAXPAUC3Phy@@K@Z`
- `?Phy_SetStepCount@@YAXPAUC3Phy@@K@Z`
- `?Phy_ChangeTexture@@YAXPAUC3Phy@@H@Z`
- `?Phy_ChangeMixTexture@@YAXPAUC3Phy@@H@Z`
- `?Phy_LoadFaceProperty@@YA_NPAUC3Phy@@PAX@Z`
- `?Phy_GetFaceProperty@@YAEPAUC3Phy@@H@Z`
- `?Phy_ProbeIntersection@@YA_NPAUC3Phy@@ABUD3DXVECTOR3@@1_NAAMPAH@Z`

Lighting-related:
- `?Phy_SetLight@@YAXHMMMKKM@Z`
- `?Phy_SetLightDir@@YAXHMMM@Z`
- `?Phy_LightEnable@@YAXHH@Z`
- `?Phy_SetLightDiffuse@@YAXHK@Z`
- `?Phy_SetLightAmbient@@YAXHK@Z`
- `?Phy_SetLightType@@YAXHW4C3_RENDER_LIGHT_TYPE@@@Z`
- `?Phy_SetLightPosition@@YAXHMMM@Z`
- `?Phy_SetPointLightAttenuation@@YAXHMMM@Z`
- `?Phy_SetSpotLightFalloff@@YAXHMMM@Z`
