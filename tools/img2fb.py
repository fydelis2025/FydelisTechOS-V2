#!/usr/bin/env python3
"""
FydelisTech OS v4.2 — Gerador de Wallpaper -> C Header (XRGB8888)
Converte PNG/JPG de assets/wallpapers/ ou gera fundo cyberpunk procedural.
"""
import os
import glob
from PIL import Image, ImageDraw

PASTA_WALL = "assets/wallpapers"
ARQUIVO_H  = "src/include/wallpaper.h"
WALL_W     = 1280
WALL_H     = 1024

def gerar_cyberpunk_procedural(w, h):
    img = Image.new("RGB", (w, h), (18, 8, 38))
    draw = ImageDraw.Draw(img)

    # Gradiente vertical roxo profundo -> azul noturno
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(14 + 26 * (t ** 1.6))
        g = int(6 + 10 * (t ** 1.8))
        b = int(32 + 48 * (t ** 1.3))
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    # Linha do horizonte em ciano neon suave
    horizonte = int(h * 0.62)
    for offset, alpha in [(-3, 25), (-2, 55), (-1, 110), (0, 190), (1, 110), (2, 55), (3, 25)]:
        y = horizonte + offset
        cor = (int(18 + 0 * alpha / 255), int(8 + 245 * alpha / 255), int(38 + 212 * alpha / 255))
        draw.line([(0, y), (w, y)], fill=cor)

    # Grade de perspectiva abaixo do horizonte
    for i in range(1, 12):
        y = horizonte + int(((i / 12) ** 1.7) * (h - horizonte))
        draw.line([(0, y), (w, y)], fill=(58, 26, 110))

    cx = w // 2
    for step in range(-10, 11):
        x_top = cx + step * 55
        x_bot = cx + step * 165
        draw.line([(x_top, horizonte), (x_bot, h)], fill=(58, 26, 110))

    return img

def main():
    os.makedirs(os.path.dirname(ARQUIVO_H), exist_ok=True)
    imgs = sorted(
        glob.glob(os.path.join(PASTA_WALL, "*.png")) +
        glob.glob(os.path.join(PASTA_WALL, "*.jpg")) +
        glob.glob(os.path.join(PASTA_WALL, "*.jpeg"))
    )

    if imgs:
        origem = os.path.basename(imgs[0])
        img = Image.open(imgs[0]).convert("RGB").resize((WALL_W, WALL_H), Image.Resampling.LANCZOS)
    else:
        origem = "cyberpunk_grid_procedural"
        img = gerar_cyberpunk_procedural(WALL_W, WALL_H)

    pixels = list(img.getdata())

    with open(ARQUIVO_H, "w", encoding="utf-8") as f:
        f.write(f"/* Gerado por tools/img2fb.py ({origem}) — FydelisTech OS */\n")
        f.write("#ifndef FYDELIS_WALLPAPER_H\n#define FYDELIS_WALLPAPER_H\n\n")
        f.write("#include <stdint.h>\n\n")
        f.write(f"#define WALLPAPER_W {WALL_W}\n")
        f.write(f"#define WALLPAPER_H {WALL_H}\n\n")
        f.write(f"static const uint32_t wallpaper_pixels[{WALL_W * WALL_H}] = {{\n    ")

        for idx, (r, g, b) in enumerate(pixels):
            val = 0xFF000000 | (r << 16) | (g << 8) | b
            f.write(f"0x{val:08X}")
            if idx < len(pixels) - 1:
                f.write(", ")
                if (idx + 1) % 10 == 0:
                    f.write("\n    ")

        f.write("\n};\n\n#endif /* FYDELIS_WALLPAPER_H */\n")

    print(f"[OK] Wallpaper '{origem}' ({WALL_W}x{WALL_H}) -> {ARQUIVO_H}")

if __name__ == "__main__":
    main()
