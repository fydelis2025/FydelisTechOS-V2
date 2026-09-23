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
    kernel.o \
    pmm.o \
    paging.o \
    heap.o \
    context.o \
    scheduler.o \
    exceptions.o \
    fs.o \
    buffer.o \
    editor.o \
    commands.o \
    memmap.o \
    ../boot/gdt.o \
    ../boot/idt.o \
    ../boot/pci.o \
    ../boot/interrupts.o \
    ../boot/cpu.o \
    ../drivers/timer.o \
    ../drivers/apic.o \
    ../drivers/ata.o \
    ../drivers/keyboard.o \
    ../drivers/audio.o \
    ../drivers/video.o \
    ../drivers/rede.o

# ==========================================
# 🎯 ALVO PRINCIPAL
# ==========================================
all: fydelterm.img

# ==========================================
# 🔧 REGRAS DE COMPILAÇÃO
# ==========================================
%.o: %.asm
	@echo "  AS       KERNEL   $<"
	$(ASM) $(ASFLAGS) $< -o $@

../boot/%.o: ../boot/%.asm
	@echo "  AS       BOOT     $<"
	$(ASM) $(ASFLAGS) $< -o $@

../drivers/%.o: ../drivers/%.asm
	@echo "  AS       DRIVER   $<"
	$(ASM) $(ASFLAGS) $< -o $@

# ==========================================
# 🥾 BOOTLOADER E EFI STUB
# ==========================================
boot.bin: ../boot/bootloader.asm
	@echo "  AS       Bootloader"
	$(ASM) -f bin ../boot/bootloader.asm -o boot.bin
	# Garante estritamente que o boot.bin tenha 512 bytes
	truncate -s 512 boot.bin
	
BOOTX64.EFI: ../boot/efi_stub.asm
	@echo "  AS       EFI Stub (BOOTX64.EFI)"
	nasm -f bin ../boot/efi_stub.asm -o BOOTX64.EFI

# ==========================================
# 🔗 LINK DO KERNEL
# ==========================================
kernel.bin: $(OBJS)
	@echo "  LD       Kernel — $(words $(OBJS)) módulos"
	$(LD) $(LDFLAGS) $(OBJS) -o kernel.bin

# ==========================================
# 💿 IMAGEM DE DISCO
# ==========================================
fydelterm.img: boot.bin kernel.bin
	@echo "  IMG      $@"
	# Cria uma imagem limpa e posiciona o boot no setor 0 e o kernel no LBA correto (ex: offset 2MB ou logo após o setor 1)
	dd if=/dev/zero of=fydelterm.img bs=1M count=10
	dd if=boot.bin of=fydelterm.img conv=notrunc bs=512 count=1
	dd if=kernel.bin of=fydelterm.img conv=notrunc bs=512 seek=4096

# ==========================================
# 🌐 ISO
# ==========================================
iso: fydelterm.img
	@echo "  ISO      FydelisTechOS.iso"
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
	rm -f *.o ../boot/*.o ../drivers/*.o *.bin *.EFI fydelterm.img fydelterm.iso
	@echo "✅ Limpo!"
