# Extraction and validation method

Read-only source files were copied from the exact clean-5517 tree; all copies and originals were rehashed before delivery. The existing Conquer.exe Binary Ninja database was used for targeted native assembly. No fresh IDA/Ghidra/REA database was substituted.

JPEXS FFDec 26.3.0 was downloaded from its official GitHub release. The used `ffdec.jar` SHA-256 is `1587e60b2ec2c0e4f5721fd5f2aaaf2379f6d416569de99054b5c5d1e9ba841c`. Runtime: OpenJDK 24.0.2. Video decoding: FFmpeg 9.0.1. Pillow 12.2.0 was used only for RGBA container conversion and separately labeled contact sheets, not for generating replacement game graphics.

Representative commands (paths abbreviated):

```
java -Djava.awt.headless=true -jar ffdec.jar -swf2xml original.swf decoded.xml
java -Djava.awt.headless=true -jar ffdec.jar -export script decoded original.swf
java -Djava.awt.headless=true -jar ffdec.jar -format script:pcodehex -export script pcode original.swf
java -Djava.awt.headless=true -jar ffdec.jar -ignorebackground -format shape:png,image:png,sprite:png,button:png -export sprite,button,shape,image,movie renders original.swf
java -Djava.awt.headless=true -jar ffdec.jar -ignorebackground -format frame:png -export frame renders original.swf
ffmpeg -i extracted.flv -fps_mode passthrough -pix_fmt rgba frames/%04d.png
```

Primary start.dat extraction excluded the already-delivered Enter/Exit/sparkle assets. No audio was exported. Sprite 25 video-placeholder renders for opening frames 1–24 were rejected; original encoded video was decoded independently. Nominal logo sequence slots were linked to preceding encoded-picture timestamps where the SWF contains no new VideoFrame tag. The raw 18 logo and 24 opening pictures are included separately.

An independent tag walker validated the declared decompressed FWS byte length, tag boundaries and nested sprite frame numbers, and extracted every DoAction/DoInitAction byte range. The raw AVM1 reader covers every byte in each action range and recurses through original function bodies. JPEXS p-code bytes were compared against the original action ranges; offsets were attached only to exact matches. Eight normalized p-code exports are secondary and explicitly flagged.

The full original SWFs remain the authority for replay. FFDec XML decimals were recovered to their exact 16.16 scale/skew coefficients by nearest-integer multiplication by 65536. Translations remain exact integer twips. JPEXS timeline render rectangles were compared with bounded-symbol rectangles across all 124 movies; no mismatch was found. The PNG index distinguishes authored bounds from integer raster canvas sizes. Actual device-font rasterization and live ActiveX event ordering were not validated.

Official tool source and CLI reference:
- https://github.com/jindrapetrik/jpexs-decompiler/releases/tag/version26.3.0
- https://github.com/jindrapetrik/jpexs-decompiler/wiki/Commandline-arguments
