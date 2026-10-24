#include <windows.h>
#include <stdio.h>
static void probe(UINT cp, const char *label, const unsigned char *b, int n) {
    WCHAR w[32]={0}; char out[64]={0}; BOOL used=FALSE;
    SetLastError(0); int r=MultiByteToWideChar(cp,0,(const char*)b,n,w,32); DWORD err=GetLastError();
    printf("cp=%u case=%s in=",cp,label); for(int i=0;i<n;i++)printf("%02X",b[i]);
    printf(" count=%d error=%lu utf16=",r,(unsigned long)err);
    for(int i=0;i<r;i++)printf("%04X ",(unsigned)w[i]);
    int k=r?WideCharToMultiByte(cp,0,w,r,out,64,NULL,cp==65001?NULL:&used):0;
    printf(" roundtrip=");for(int i=0;i<k;i++)printf("%02X",(unsigned char)out[i]);
    printf(" default=%d\n",used);
}
int main(void) {
    printf("API-only probe; not retail client execution. ACP=%u\n",GetACP());
    unsigned char undefined[]={0x81,0x8d,0x8f,0x90,0x9d}, dbcs[]={0x81,0x40}, chinese[]={0xd6,0xd0}, utf8[]={0xc3,0xa9}, lone[]={0x81};
    UINT cps[]={0,1252,936,65001};
    for(int c=0;c<4;c++) {
        probe(cps[c],"undefined1252",undefined,5);probe(cps[c],"dbcs",dbcs,2);
        probe(cps[c],"chinese",chinese,2);probe(cps[c],"utf8_e_acute",utf8,2);probe(cps[c],"lone81",lone,1);
    }
    return 0;
}
