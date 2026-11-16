#!/usr/bin/env python3
import os
import glob
import cairosvg
from PIL import Image
import io

SVG_DIR = "assets/icones"
OUT_H = "include/icones.h"
TAM = 20

os.makedirs(os.path.dirname(OUT_H), exist_ok=True)
svgs = sorted(glob.glob(os.path.join(SVG_DIR, "*.svg")))

with open(OUT_H, "w", encoding="utf-8") as f:
    f.write("#ifndef ICONES_H\n#define ICONES_H\n\n#include <stdint.h>\n\n")
    f.write(f"#define ICONE_TAM {TAM}\n\n")

    for caminho in svgs:
        nome = os.path.splitext(os.path.basename(caminho))[0].replace("-", "_")
        png_bytes = cairosvg.svg2png(url=caminho, output_width=TAM, output_height=TAM)
        img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
        pixels = list(img.getdata())

        f.write(f"static const uint32_t icone_{nome}[{TAM * TAM}] = {{\n    ")
        for i, (r, g, b, a) in enumerate(pixels):
            argb = (a << 24) | (r << 16) | (g << 8) | b
            f.write(f"0x{argb:08X}U, ")
            if (i + 1) % 10 == 0 and (i + 1) < len(pixels):
                f.write("\n    ")
        f.write("\n};\n\n")

    f.write("#endif /* ICONES_H */\n")

print(f"[OK] {len(svgs)} icones convertidos para {OUT_H}")
