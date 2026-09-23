# ==========================================
# FYDELIS TECH OS — FydelTerm Kernel Makefile
# Final: Completo + cpu.asm + editor.asm
# Localização: src/kernel/Makefile
# De Salvador • Bahia 🇧🇷
# ==========================================

# ⚙️ FERRAMENTAS
ASM       = nasm
ASFLAGS   = -f elf64 -I ../boot/inc/ -I ../kernel/ -I ../drivers/ -Wall
LD        = ld
LDFLAGS   = -T ../boot/linker.ld --oformat binary

# ==========================================
# 📦 ARQUIVOS OBJETO — ORDEM DE CARGA VITAL!
# ==========================================
OBJS = \
    # 🚀 NÚCLEO — PONTO DE ENTRADA (NÃO MOVER!)
    kernel.o              \
    pmm.o                 \
    paging.o              \
    heap.o                \
    context.o             \
    scheduler.o           \
    exceptions.o          \
    fs.o                  \
    \
    # 🖥️ INTERFACE E UTILIDADES
    video.o               \
    buffer.o              \
    commands.o            \
    editor.o              \
    memmap.o              \
    reset_buffer.o        \
    \
    # ⚡ SISTEMA DE PROTEÇÃO + DETECÇÃO CPU
    ../boot/gdt.o         \
    ../boot/idt.o         \
    ../boot/pci.o         \
    ../boot/interrupts.o  \
    ../boot/cpu.o         \  # ✅ DETECÇÃO DE CPU — Faltava!
    \
    # 🔧 DRIVERS — HARDWARE
    ../drivers/timer.o    \
    ../drivers/apic.o     \
    ../drivers/ata.o      \
    ../drivers/usb_xhci.o \
    ../drivers/keyboard.o \
    ../drivers/audio.o    \
    ../drivers/rede.o

# ==========================================
# 🎯 ALVO PRINCIPAL
# ==========================================
all: fydelterm.img

# ==========================================
# 🔧 REGRAS DE COMPILAÇÃO
# ==========================================
%.o: %.asm
	@echo "  AS      KERNEL   $<"
	$(ASM) $(ASFLAGS) $< -o $@

../boot/%.o: ../boot/%.asm
	@echo "  AS      BOOT     $<"
	$(ASM) $(ASFLAGS) $< -o $@

../drivers/%.o: ../drivers/%.asm
	@echo "  AS      DRIVER   $<"
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
	@echo "  LD      Kernel — $(words $(OBJS)) módulos"
	$(LD) $(LDFLAGS) $(OBJS) -o kernel.bin

# ==========================================
# 💿 IMAGEM DE DISCO
# ==========================================
fydelterm.img: boot.bin kernel.bin
	@echo "  IMG     $@"
	cat boot.bin kernel.bin > fydelterm.img

# ==========================================
# 🌐 ISO
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
# ▶️ EXECUTAR
# ==========================================
run: fydelterm.img
	@echo "🚀 Iniciando FydelisTech OS..."
	qemu-system-x86_64 \
		-drive format=raw,file=fydelterm.img \
		-m 512M \
		-smp 2 \
		-name "FydelisTech OS" \
		-display gtk \
		-serial stdio

# ==========================================
# 🧹 LIMPAR
# ==========================================
clean:
	@echo "🧹 Limpando..."
	rm -f *.o ../boot/*.o ../drivers/*.o *.bin fydelterm.img fydelterm.iso
	@echo "✅ Limpo!"