#!/usr/bin/env python3
"""
FydelisTech OS v4.2 — Conversor TTF -> C Header (Alpha Map 8-bit)
Gera fontes nítidas com anti-aliasing para títulos, relógio e UI freestanding.
"""
import os
import sys
import glob
from PIL import Image, ImageDraw, ImageFont

PASTA_FONTES = "assets/fontes"
ARQUIVO_H    = "src/include/fontes_ui.h"
LARGURA      = 12
ALTURA       = 24
TAM_PT       = 20

FALLBACK_TTF = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

def encontrar_fonte():
    ttfs = sorted(glob.glob(os.path.join(PASTA_FONTES, "*.ttf")))
    if ttfs:
        return ttfs[0]
    if os.path.exists(FALLBACK_TTF):
        return FALLBACK_TTF
    print("Coloque um arquivo .ttf em assets/fontes/ ou instale fonts-dejavu-core.")
    sys.exit(1)

def main():
    caminho_ttf = encontrar_fonte()
    fonte = ImageFont.truetype(caminho_ttf, TAM_PT)
    os.makedirs(os.path.dirname(ARQUIVO_H), exist_ok=True)

    with open(ARQUIVO_H, "w", encoding="utf-8") as f:
        f.write("/* Gerado automaticamente por tools/ttf2c.py — FydelisTech OS */\n")
        f.write("#ifndef FYDELIS_FONTES_UI_H\n#define FYDELIS_FONTES_UI_H\n\n")
        f.write("#include <stdint.h>\n\n")
        f.write(f"#define FONTE_UI_W {LARGURA}\n")
        f.write(f"#define FONTE_UI_H {ALTURA}\n\n")
        f.write(f"static const uint8_t fonte_ui_alpha[95][{LARGURA * ALTURA}] = {{\n")

        for code in range(32, 127):
            ch = chr(code)
            img = Image.new("L", (LARGURA, ALTURA), 0)
            draw = ImageDraw.Draw(img)
            draw.text((1, 2), ch, fill=255, font=fonte)

            dados = list(img.getdata())
            hex_vals = ", ".join(f"0x{v:02X}" for v in dados)
            f.write(f"    {{ {hex_vals} }}, /* '{ch}' ({code}) */\n")

        f.write("};\n\n#endif /* FYDELIS_FONTES_UI_H */\n")

    print(f"[OK] Fonte '{os.path.basename(caminho_ttf)}' ({LARGURA}x{ALTURA}) -> {ARQUIVO_H}")

if __name__ == "__main__":
    main()
