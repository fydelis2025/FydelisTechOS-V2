# ==========================================
# FYDELIS TECH OS — FydelTerm Kernel Makefile
# Atualizado: Detecção de Hardware + Memória + USB + Interrupções
# Localização: src/core/kernel/Makefile
# De Salvador • Bahia 🇧🇷
# ==========================================

# ⚙️ FERRAMENTAS
ASM       = nasm
ASFLAGS   = -f elf64 -I ../inc/ -Wall
LD        = ld
LDFLAGS   = -T ../boot/linker.ld --oformat binary

# ==========================================
# 📦 ARQUIVOS OBJETO — ORDEM DE CARGA IMPORTANTE!
# kernel.o SEMPRE primeiro → ponto de entrada em 0x8000
# ==========================================
OBJS = \
    kernel.o              # 🚀 Ponto de entrada (NÃO mover!)
    video.o               # 🖥️ Tela e Modo Gráfico
    keyboard.o            # ⌨️ Entrada do Usuário
    buffer.o              # 📦 Gerenciamento de Buffers
    commands.o            # 💻 Processamento de Comandos
    audio.o               # 🔊 Áudio e Som
    rede.o                # 📡 Rede e Conexões
    \
    # ✅ NOVOS — Detecção Automática de Hardware
    pci.o                 # 🔍 Varredura PCI/PCIe — ENCONTRA TUDO!
    memmap.o              # 🧠 Mapeamento de Memória RAM
    interrupts.o          # ⚡ Tratamento de IRQs — Sistema não trava!
    usb.o                 # 🔌 Barramento USB — Mouse, Pendrive, etc.

# ==========================================
# 🎯 ALVO PRINCIPAL
# ==========================================
all: fydelterm.img

# ==========================================
# 🔧 REGRAS DE COMPILAÇÃO
# ==========================================
%.o: ../boot/%.asm
	@echo "  AS      $<"
	$(ASM) $(ASFLAGS) $< -o $@

%.o: %.asm
	@echo "  AS      $<"
	$(ASM) $(ASFLAGS) $< -o $@

# ==========================================
# 🥾 BOOTLOADER
# ==========================================
boot.bin: ../boot/bootloader.asm
	@echo "  AS      Bootloader"
	nasm -f bin ../boot/bootloader.asm -o boot.bin

# ==========================================
# 🔗 LINK DO KERNEL
# ==========================================
kernel.bin: $(OBJS)
	@echo "  LD      Kernel"
	$(LD) $(LDFLAGS) $(OBJS) -o kernel.bin

# ==========================================
# 💿 GERAR IMAGEM DE DISCO (RAW)
# ==========================================
fydelterm.img: boot.bin kernel.bin
	@echo "  IMG     $@"
	cat boot.bin kernel.bin > fydelterm.img

# ==========================================
# 🌐 GERAR ISO PRONTA PARA INSTALAÇÃO
# ==========================================
iso: fydelterm.img
	@echo "  ISO     FydelisTechOS.iso"
	mkdir -p iso_root
	cp fydelterm.img iso_root/boot.img
	genisoimage -o fydelterm.iso \
		-b boot.img \
		-no-emul-boot \
		-boot-load-size 4 \
		-J -R \
		-V "FYDELIS_TECH_OS" \
		iso_root/
	rm -rf iso_root
	@echo "✅ ISO pronta: fydelterm.iso"

# ==========================================
# ▶️ EXECUTAR NO QEMU
# ==========================================
run: fydelterm.img
	@echo "🚀 Iniciando FydelisTech OS..."
	qemu-system-x86_64 \
		-drive format=raw,file=fydelterm.img \
		-m 256M \
		-smp 2 \
		-name "FydelisTech OS" \
		-display gtk

# ==========================================
# 🧹 LIMPAR ARQUIVOS
# ==========================================
clean:
	@echo "🧹 Limpando..."
	rm -f *.o *.bin fydelterm.img fydelterm.iso
	@echo "✅ Limpo!"

# ==========================================
# 📋 ESTRUTURA DE PASTAS
# ==========================================
# src/
#   ├── boot/
#   │   ├── bootloader.asm
#   │   ├── pci.asm          ✅ NOVO
#   │   ├── memmap.asm       ✅ NOVO
#   │   ├── interrupts.asm   ✅ NOVO
#   │   ├── usb.asm          ✅ NOVO
#   │   ├── linker.ld
#   │   └── inc/
#   └── core/kernel/
#       ├── kernel.asm
#       ├── video.asm
#       ├── keyboard.asm
#       ├── audio.asm
#       ├── rede.asm
#       ├── Makefile          ✅ Este arquivo
#       └── ...