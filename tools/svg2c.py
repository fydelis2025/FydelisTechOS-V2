#!/usr/bin/env python3
import os
import glob
import cairosvg
from PIL import Image
import io

SVG_DIR = "assets/icones"
OUT_H = "include/icones.h"
TAM = 20

os.makedirs(SVG_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT_H), exist_ok=True)

# Garante que o emblema Fydelis "F" exista no kit de icones
fydelis_svg = os.path.join(SVG_DIR, "fydelis_f.svg")
if not os.path.exists(fydelis_svg):
    with open(fydelis_svg, "w", encoding="utf-8") as sf:
        sf.write('''<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20">
  <rect x="1" y="1" width="18" height="18" rx="4" fill="#281352" stroke="#00F5D4" stroke-width="1.6"/>
  <path d="M6 5h8v2.5H8.8v2.2h4.4v2.4H8.8V15H6V5z" fill="#00F5D4"/>
</svg>''')

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
