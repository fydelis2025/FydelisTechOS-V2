# ==========================================
# FydelisTech OS — FydelTerm Kernel Makefile
# Localização: core/kernel/Makefile
# ==========================================

ASM = nasm
ASFLAGS = -f elf64 -I ../inc/
LD = ld
LDFLAGS = -T ../boot/linker.ld --oformat binary

# kernel.o deve vir estritamente primeiro para a função 'start' ficar em 0x8000
OBJS = kernel.o video.o keyboard.o buffer.o commands.o audio.o rede.o

all: fydelterm.img

%.o: %.asm
	$(ASM) $(ASFLAGS) $< -o $@

# Compila o bootloader simples diretamente da pasta boot/
boot.bin: ../boot/bootloader.asm
	nasm -f bin ../boot/bootloader.asm -o boot.bin

# Compila o kernel em binário puro
kernel.bin: $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o kernel.bin

# Concatena o MBR (512 bytes) + Kernel gerando o disco RAW
fydelterm.img: boot.bin kernel.bin
	cat boot.bin kernel.bin > fydelterm.img

iso: fydelterm.img
	mkdir -p iso_root
	cp fydelterm.img iso_root/boot.img
	genisoimage -o fydelterm.iso \
		-b boot.img \
		-no-emul-boot \
		-boot-load-size 4 \
		iso_root/
	rm -rf iso_root
	@echo "ISO gerada com sucesso: fydelterm.iso"
	
run: fydelterm.img
	qemu-system-x86_64 -drive format=raw,file=fydelterm.img -m 64M

clean:
	rm -f *.o *.bin fydelterm.img
