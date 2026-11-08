0064f811  8b 45 c0         mov     eax, dword [ebp-0x40]  ; Role_TickAndRender continuation containing transform setup and render-time RoleView action/frame dispatch. At 0x64FA0E: CRole+0x60 !=1 re-pushes CRole+0x1A4 and the normal facing/frame selector. CRole+0x60 ==1 plus status 0x2E active dispatches action 0x390 and sets selector 0x0A to ((timeGetTime()-CRole+0x64)/Role_ComputeFrameIntervalFromAction(role,0x390)) % frameCount. If the latch is 1 but status 0x2E is clear, it clears CRole+0x60, calls Role_UpdateActionAndDispatchRoleViewMotion, then re-pushes current action and CRole+0x1A8. Status 0x2E is the Shuriken Vortex action override, corroborated by clean 5517 action/magic data.
0064f814  8b 8e b4 03 00 00 mov     ecx, dword [esi+0x3b4]
0064f81a  2b 45 e4         sub     eax, dword [ebp-0x1c]
0064f81d  51               push    ecx
0064f81e  db 45 c4         fild    st0, dword [ebp-0x3c]
0064f821  2b 45 e8         sub     eax, dword [ebp-0x18]
0064f824  d9 5d c8         fstp    dword [ebp-0x38], st0
0064f827  89 45 b4         mov     dword [ebp-0x4c], eax
0064f82a  8b 01            mov     eax, dword [ecx]
0064f82c  db 45 b4         fild    st0, dword [ebp-0x4c]
0064f82f  d9 5d cc         fstp    dword [ebp-0x34], st0
0064f832  db 45 e4         fild    st0, dword [ebp-0x1c]
0064f835  d9 5d d0         fstp    dword [ebp-0x30], st0
0064f838  d9 45 d8         fld     st0, dword [ebp-0x28]
0064f83b  d9 1c 24         fstp    dword [esp], st0
0064f83e  d9 45 d0         fld     st0, dword [ebp-0x30]
0064f841  57               push    edi
0064f842  51               push    ecx
0064f843  d9 1c 24         fstp    dword [esp], st0
0064f846  d9 45 cc         fld     st0, dword [ebp-0x34]
0064f849  51               push    ecx
0064f84a  d9 1c 24         fstp    dword [esp], st0
0064f84d  d9 45 c8         fld     st0, dword [ebp-0x38]
0064f850  51               push    ecx
0064f851  d9 1c 24         fstp    dword [esp], st0
0064f854  ff 50 10         call    dword [eax+0x10]
