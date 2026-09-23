import os
import zipfile
from PIL import Image, ImageDraw

# ==========================================
# PALETA DE CORES E CONFIGURAÇÕES
# ==========================================
VERDE_NEON = "#00FF88"
AZUL_ELETRICO = "#00AAFF"
ROXO_ESCURO = "#2B0050"
PRETO_PROFUNDO = "#050508"
CINZA_TECH = "#333344"
BRANCO = "#FFFFFF"

# ==========================================
# ESTRUTURA COMPLETA — COM ICONE_PASTA ✅
# ==========================================
ESTRUTURA = {
    "pastas": [
        "pasta_padrao.png",
        "pasta_aberta.png",
        "pasta_usuarios.png",
        "pasta_programas.png",
        "pasta_documentos.png",
        "pasta_downloads.png",
        "pasta_area_trabalho.png",
        "pasta_sistema.png",
        "pasta_rede.png",
    ],
    "sistema": [
        "icone_sistema.png",
        "icone_pasta.png",          # ✅ ADICIONADO AQUI!
        "icone_terminal.png",
        "icone_configuracao.png",
        "icone_pesquisa.png",
        "icone_ajuda.png",
        "icone_sair.png",
    ],
    "hardware": [
        "placa_rede.png",
        "som.png",
        "processador.png",
        "memoria.png",
        "disco.png",
        "monitor.png",
        "bateria.png",
    ],
    "aplicativos": [
        "fydelis_web.png",
        "fydelis_editor.png",
        "fydelis_remote.png",
        "fydelis_paint.png",
        "fydelis_disco.png",
    ],
    "acao": [
        "novo.png",
        "abrir.png",
        "salvar.png",
        "excluir.png",
        "copiar.png",
        "cortar.png",
        "propriedades.png",
    ],
}

def desenhar_hud_base(draw):
    """Desenha uma moldura HUD futurista comum de fundo para os ícones"""
    draw.rounded_rectangle(
        [16, 16, 240, 240], radius=16, outline=AZUL_ELETRICO, width=2
    )
    draw.line([16, 32, 32, 16], fill=VERDE_NEON, width=2)
    draw.line([240, 224, 224, 240], fill=VERDE_NEON, width=2)

def criar_icone(nome):
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 📁 Pastas normais
    if "pasta" in nome and "icone_pasta" not in nome:
        draw.polygon(
            [(32, 80), (100, 80), (120, 110), (224, 110), (224, 200), (32, 200)],
            fill=(43, 0, 80, 220),
            outline=AZUL_ELETRICO,
            width=3,
        )
        draw.rectangle([48, 120, 208, 180], outline=VERDE_NEON, width=2)
        if "aberta" in nome:
            draw.line([48, 110, 208, 110], fill=VERDE_NEON, width=4)
        elif "sistema" in nome:
            draw.rectangle([110, 130, 146, 170], fill=VERDE_NEON)

    # 📁 ICONE PASTA — EXPLORADOR ✅ COM BRILHO NO CENTRO
    elif "icone_pasta" in nome:
        draw.polygon(
            [(32, 80), (100, 80), (120, 110), (224, 110), (224, 200), (32, 200)],
            fill=(43, 0, 80, 220),
            outline=AZUL_ELETRICO,
            width=3,
        )
        draw.rectangle([48, 120, 208, 180], outline=VERDE_NEON, width=2)
        # ✨ Brilho neon no centro
        draw.ellipse([96, 128, 160, 176], fill=(0, 255, 136, 80), outline=VERDE_NEON, width=2)

    # 🛡️ Ícone do Sistema (Escudo)
    elif "icone_sistema" in nome:
        draw.polygon(
            [(128, 30), (210, 60), (210, 140), (128, 220), (46, 140), (46, 60)],
            fill=(43, 0, 80, 240),
            outline=VERDE_NEON,
            width=4,
        )
        draw.rectangle([112, 90, 144, 150], fill=AZUL_ELETRICO)

    # 💻 Terminal
    elif "terminal" in nome:
        draw.rounded_rectangle(
            [24, 48, 232, 208], radius=8, fill=(5, 5, 8, 240), outline=CINZA_TECH, width=3
        )
        draw.rectangle([24, 48, 232, 80], fill=ROXO_ESCURO)
        draw.text((40, 100), "> root@fydelis:~#", fill=VERDE_NEON)
        draw.rectangle([40, 140, 60, 160], fill=VERDE_NEON)

    # 🖥️ Hardware / Chip
    elif "processador" in nome or "disco" in nome:
        draw.rectangle([78, 78, 178, 178], fill=CINZA_TECH, outline=AZUL_ELETRICO, width=3)
        draw.rectangle([104, 104, 152, 152], fill=ROXO_ESCURO, outline=VERDE_NEON, width=2)
        for i in range(94, 160, 18):
            draw.line([i, 60, i, 78], fill=VERDE_NEON, width=2)
            draw.line([i, 178, i, 196], fill=VERDE_NEON, width=2)
            draw.line([60, i, 78, i], fill=VERDE_NEON, width=2)
            draw.line([178, i, 196, i], fill=VERDE_NEON, width=2)

    # ⭐ Ícone Genérico / HUD
    else:
        desenhar_hud_base(draw)
        draw.ellipse([96, 96, 160, 160], outline=VERDE_NEON, width=3)
        draw.line([128, 64, 128, 192], fill=AZUL_ELETRICO, width=2)
        draw.line([64, 128, 192, 128], fill=AZUL_ELETRICO, width=2)

    return img

# ==========================================
# EXECUÇÃO E EMPACOTAMENTO
# ==========================================
base_folder = "icons"
os.makedirs(base_folder, exist_ok=True)
print("[*] Gerando ícones com tema cyberpunk/hacker...")

for categoria, arquivos in ESTRUTURA.items():
    cat_path = os.path.join(base_folder, categoria)
    os.makedirs(cat_path, exist_ok=True)
    for arq in arquivos:
        caminho_arquivo = os.path.join(cat_path, arq)
        img = criar_icone(arq)
        img.save(caminho_arquivo, "PNG")
        print(f"  ✅ {categoria}/{arq}")

zip_name = "fydelis_icons_hacker.zip"
print(f"\n[*] Compactando em '{zip_name}'...")
with zipfile.ZipFile(zip_name, "w", zipfile.ZIP_DEFLATED) as zipf:
    for raiz, dirs, arquivos in os.walk(base_folder):
        for arquivo in arquivos:
            caminho_completo = os.path.join(raiz, arquivo)
            zipf.write(caminho_completo, os.path.relpath(caminho_completo, base_folder))

print(f"\n🎉 SUCESSO! {zip_name} — com TODOS os ícones + icone_pasta.png ✅")