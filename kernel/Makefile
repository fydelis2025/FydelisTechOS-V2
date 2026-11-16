# ==========================================
# FYDELIS TECH OS — FydelTerm Kernel Makefile
# v2.3: correcoes de build robusto
# Padrao de inclusao: src/include/syscalls
# De Salvador • Bahia 🇧🇷
# ==========================================

# ⚙️ FERRAMENTAS
ASM       = nasm
ASFLAGS   = -f elf64 \
            -I ../include/ \
            -I ../include/syscalls/ \
            -I ../kernel/ \
            -I ../drivers/ \
            -I ../grafico/ \
            -I ../virtual/ \
            -I ../user/ \
            -I ../system/ \
            -I ../idioma/ \
            -I ../ \
            -Wall

LD        = ld
LDFLAGS   = -T ../boot/linker.ld --oformat binary

CC        = gcc
CFLAGS    = -m64 \
            -ffreestanding \
            -fno-pie \
            -fno-pic \
            -fno-stack-protector \
            -fno-builtin \
            -nostdlib \
            -mcmodel=kernel \
            -mno-red-zone \
            -mno-mmx \
            -mno-sse \
            -mno-sse2 \
            -I../include/ \
            -I../include/syscalls/ \
            -I../kernel/ \
            -I../drivers/ \
            -I../grafico/ \
            -I../virtual/ \
            -I../user/ \
            -I../system/ \
            -I../idioma/ \
            -I../ \
            -Wall \
            -MMD -MP

BUILD_DIR ?= build

# ==========================================
# 📦 ARQUIVOS OBJETO — ORDEM DE CARGA VITAL!
# kernel.o SEMPRE primeiro → ponto de entrada em 0x8000
# ==========================================
OBJS = \
    kernel.o                \
    exec.o                  \
    boot_config.o           \
    pmm.o                   \
    paging.o                \
    heap.o                  \
    context.o               \
    scheduler.o             \
    exceptions.o            \
    fs.o                    \
    buffer.o                \
    editor.o                \
    commands.o              \
    memmap.o                \
    syscall_handler.o       \
    stubs_kernel.o          \
    estrutura.o          \
    energia.o          \
    ../pentest/pentest.o    \
    ../boot/gdt.o           \
    ../boot/idt.o           \
    ../boot/interrupts.o    \
    ../boot/cpu.o           \
    ../drivers/pci.o        \
    ../drivers/particao.o   \
    ../drivers/disco.o      \
    ../drivers/timer.o      \
    ../drivers/apic.o       \
    ../drivers/ata.o        \
    ../drivers/keyboard.o   \
    ../drivers/audio.o      \
    ../drivers/video.o      \
    ../drivers/rede.o       \
    ../drivers/rede_bridge.o\
    ../drivers/wifi.o       \
    ../drivers/bluetooth.o  \
    ../drivers/cpu.o        \
    ../drivers/impressora.o \
    ../drivers/dhcp_servidor.o \
    ../drivers/usb.o        \
    ../drivers/mouse.o        \
    ../drivers/texto.o      \
    ../virtual/virt_detect.o \
    ../virtual/plataforma_detect.o \
    ../virtual/vmx_init.o   \
    ../virtual/svm_init.o   \
    ../virtual/vm_core.o    \
    ../virtual/vmexit_handler.o \
    ../virtual/svm_exit_handler.o \
    ../virtual/vm_execucao_loop.o \
    ../virtual/ept_npt.o    \
    ../virtual/ept_integracao.o \
    ../virtual/vm_integracao.o \
    ../virtual/vm_disco_interface.o \
    ../virtual/convidado_com_disco.o \
    ../virtual/memvirt.o    \
    ../user/entry.o         \
    ../user/syscall_stub.o  \
    ../user/vm_client.o     \
    ../user/fs_client.o     \
    ../user/net_client.o    \
    ../user/security_client.o \
    ../user/terminal.o      \
    ../user/init.o          \
    ../grafico/amd_gpu.o    \
    ../grafico/fb_server.o  \
    ../grafico/fb_generico.o \
    ../grafico/gop.o        \
    ../grafico/gpu_dispatch.o \
    ../grafico/intel_gpu.o  \
    ../grafico/pci_gpu.o    \
    ../grafico/vesafb.o     \
    ../grafico/virtio_gpu.o \
    ../system/hosts_mgr.o   \
    ../system/compat_stubs.o \
    ../system/fydlog.o      \
    ../idioma/en_us.o       \
    ../idioma/idioma.o      \
    ../idioma/pt_br.o

# Dependencias de header geradas pelo GCC (-MMD)
-include $(OBJS:.o=.d)

# ==========================================
# 🎯 ALVO PRINCIPAL
# ==========================================
all: fydelterm.img $(BUILD_DIR)/fyd_boot.cfg
	@echo "Build do kernel e configuração concluído com sucesso!"

$(BUILD_DIR)/fyd_boot.cfg: ../boot/fyd_boot.cfg
	@mkdir -p $(BUILD_DIR)
	cp ../boot/fyd_boot.cfg $@
	@echo "[+] Copiado fyd_boot.cfg para $(BUILD_DIR)"

# ==========================================
# 🔧 REGRAS DE COMPILAÇÃO
# (%.o casa com subdiretorios — as regras por
#  pasta eram redundantes e foram unificadas)
# ==========================================
%.o: %.asm
	@echo "  AS       $<"
	$(ASM) $(ASFLAGS) $< -o $@

%.o: %.c
	@echo "  CC       $<"
	$(CC) $(CFLAGS) -c $< -o $@

# ==========================================
# 🥾 BOOTLOADER E EFI STUB
# ==========================================
boot.bin: ../boot/bootloader.asm
	@echo "  AS       Bootloader"
	$(ASM) -f bin -I ../include/ $< -o $@
	@sz=$$(stat -c%s $@); \
	if [ $$sz -gt 512 ]; then \
		echo "ERRO: bootloader cresceu ($$sz bytes > 512). Reduza o codigo!"; \
		rm -f $@; exit 1; \
	fi
	truncate -s 512 $@

BOOTX64.EFI: ../boot/efi_stub.asm
	@echo "  AS       EFI Stub (BOOTX64.EFI)"
	$(ASM) -f bin -I ../include/ $< -o $@

# ==========================================
# 🔗 LINK DO KERNEL
# ==========================================
kernel.bin: $(OBJS)
	@echo "  LD       Kernel — $(words $(OBJS)) módulos"
	$(LD) $(LDFLAGS) $(OBJS) -o $@

# ==========================================
# 💿 IMAGEM DE DISCO
# LBA 4096 (offset 2 MiB) + 128 setores (64 KiB)
# → imagem de 4 MiB dá folga sobrando
# ==========================================
fydelterm.img: boot.bin kernel.bin
	@echo "  IMG      $@"
	dd if=/dev/zero of=$@ bs=1M count=4 status=none
	dd if=boot.bin   of=$@ conv=notrunc bs=512 count=1 status=none
	dd if=kernel.bin of=$@ conv=notrunc bs=512 seek=4096 status=none

# ==========================================
# 🌐 ISO
# El Torito espera imagem de disquete 1.44MB,
# não a imagem de HD — gravamos o bootloader
# num arquivo de floppy padronizado
# ==========================================
boot_flp.img: boot.bin
	@echo "  FLP      $@"
	dd if=/dev/zero of=$@ bs=512 count=2880 status=none
	dd if=boot.bin of=$@ conv=notrunc status=none

iso: fydelterm.img boot_flp.img
	@echo "  ISO      FydelisTechOS.iso"
	mkdir -p iso_root
	cp boot_flp.img iso_root/boot.img
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
		-boot c \
		-nic none \
		-no-reboot \
		-no-shutdown \
		-d int,cpu_reset \
		-m 512M \
		-smp 2 \
		-name "FydelisTech OS" \
		-display gtk \
		-serial stdio

# Depuração com GDB: make debug → conecte com
#   gdb -ex "target remote :1234" kernel.bin
debug: fydelterm.img
	qemu-system-x86_64 \
		-drive format=raw,file=fydelterm.img \
		-m 512M -smp 2 -serial stdio \
		-s -S

# ==========================================
# 🧹 LIMPAR
# ==========================================
clean:
	@echo "🧹 Limpando..."
	rm -f *.o *.d
	rm -f ../boot/*.o ../boot/*.d
	rm -f ../drivers/*.o ../drivers/*.d
	rm -f ../pentest/*.o ../pentest/*.d
	rm -f ../grafico/*.o ../grafico/*.d
	rm -f ../user/*.o ../user/*.d
	rm -f ../virtual/*.o ../virtual/*.d
	rm -f ../system/*.o ../system/*.d
	rm -f ../idioma/*.o ../idioma/*.d
	rm -f ../core/security/*.o ../core/security/*.d
	rm -f *.bin *.EFI fydelterm.img boot_flp.img fydelterm.iso
	@echo "✅ Limpo!"

.PHONY: all iso run debug clean
