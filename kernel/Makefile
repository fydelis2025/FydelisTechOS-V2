# ==========================================
# FYDELIS TECH OS — FydelTerm Kernel Makefile
# v2.4: integracao com tools/ e assets graficos
# Padrao de inclusao: src/include/syscalls
# De Salvador • Bahia
# ==========================================

# FERRAMENTAS
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

PYTHON    = python3
ROOT_DIR  = ..
TOOLS_DIR = $(ROOT_DIR)/tools
ASSETS_DIR= $(ROOT_DIR)/assets
INC_DIR   = ../include
BUILD_DIR ?= build

# ==========================================
# ASSETS GRAFICOS GERADOS VIA tools/
# ==========================================
HEADERS_ASSETS = \
    $(INC_DIR)/icones.h \
    $(INC_DIR)/fontes_ui.h \
    $(INC_DIR)/wallpaper.h

# ==========================================
# ARQUIVOS OBJETO — ORDEM DE CARGA VITAL!
# kernel.o SEMPRE primeiro -> ponto de entrada em 0x8000
# ==========================================
OBJS = \
    kernel.o \
    exec.o \
    boot_config.o \
    pmm.o \
    paging.o \
    apic.o \
    idt.o \
    gdt.o \
    heap.o \
    context.o \
    scheduler.o \
    pcb.o \
    exceptions.o \
    fs.o \
    buffer.o \
    editor.o \
    commands.o \
    memmap.o \
    syscall_handler.o \
    stubs_kernel.o \
    fyd_formatos.o \
    panic.o \
    estrutura.o \
    energia.o \
    cve_guard.o \
    ../pentest/pentest.o \
    ../drivers/pci.o \
    ../drivers/particao.o \
    ../drivers/disco.o \
    ../drivers/timer.o \
    ../drivers/ata.o \
    ../drivers/keyboard.o \
    ../drivers/audio.o \
    ../drivers/video.o \
    ../drivers/rede.o \
    ../drivers/rede_bridge.o \
    ../drivers/wifi.o \
    ../drivers/bluetooth.o \
    ../drivers/cpu.o \
    ../drivers/impressora.o \
    ../drivers/dhcp_servidor.o \
    ../drivers/usb.o \
    ../drivers/mouse.o \
    ../drivers/texto.o \
    ../virtual/virt_detect.o \
    ../virtual/plataforma_detect.o \
    ../virtual/vmx_init.o \
    ../virtual/svm_init.o \
    ../virtual/vm_core.o \
    ../virtual/vmexit_handler.o \
    ../virtual/svm_exit_handler.o \
    ../virtual/vm_execucao_loop.o \
    ../virtual/ept_npt.o \
    ../virtual/ept_integracao.o \
    ../virtual/vm_integracao.o \
    ../virtual/vm_disco_interface.o \
    ../virtual/convidado_com_disco.o \
    ../virtual/memvirt.o \
    ../user/entry.o \
    ../user/syscall_stub.o \
    ../user/vm_client.o \
    ../user/fs_client.o \
    ../user/net_client.o \
    ../user/security_client.o \
    ../user/terminal.o \
    ../user/init.o \
    ../grafico/amd_gpu.o \
    ../grafico/fb_server.o \
    ../grafico/fb_generico.o \
    ../grafico/gop.o \
    ../grafico/gpu_dispatch.o \
    ../grafico/intel_gpu.o \
    ../grafico/pci_gpu.o \
    ../grafico/vesafb.o \
    ../grafico/virtio_gpu.o \
    ../system/hosts_mgr.o \
    ../system/compat_stubs.o \
    ../system/fydlog.o \
    ../idioma/en_us.o \
    ../idioma/idioma.o \
    ../idioma/pt_br.o \
    ../apps/acessorios/calculadora.o \
    ../apps/acessorios/fydnotes.o \
    ../apps/sistema/visualizador_logs.o \
    ../apps/sistema/explorer.o \
    ../apps/web/browser.o \
    ../modulos/net/http.o \
    ../modulos/net/tcp.o

# Dependencias de header geradas pelo GCC (-MMD)
-include $(OBJS:.o=.d)

# ==========================================
# ALVO PRINCIPAL
# ==========================================
all: assets fydelterm.img iso $(BUILD_DIR)/fyd_boot.cfg
	@echo "Build do kernel, ISO e configuracao concluido com sucesso!"

$(BUILD_DIR)/fyd_boot.cfg: ../boot/fyd_boot.cfg
	@mkdir -p $(BUILD_DIR)
	cp ../boot/fyd_boot.cfg $@
	@echo "[+] Copiado fyd_boot.cfg para $(BUILD_DIR)"

# ==========================================
# Aplicativos (apps/)
# ==========================================
../apps/acessorios/calculadora.o: ../apps/acessorios/calculadora.c ../apps/apps.h
	@echo "  CC       $<"
	$(CC) $(CFLAGS) -c $< -o $@

../apps/sistema/visualizador_logs.o: ../apps/sistema/visualizador_logs.c ../apps/apps.h
	@echo "  CC       $<"
	$(CC) $(CFLAGS) -c $< -o $@

# ==========================================
# PIPELINE PYTHON (tools/ -> src/include/)
# ==========================================
$(ASSETS_DIR)/icones/ethernet.svg: $(TOOLS_DIR)/gerar_kit_icones.py
	@echo "  PY       Gerando kit base de icones SVG"
	cd $(ROOT_DIR) && $(PYTHON) tools/gerar_kit_icones.py

$(INC_DIR)/icones.h: $(ASSETS_DIR)/icones/ethernet.svg $(wildcard $(ASSETS_DIR)/icones/*.svg) $(TOOLS_DIR)/svg2c.py
	@echo "  PY       Convertendo SVGs -> icones.h"
	cd $(ROOT_DIR) && $(PYTHON) tools/svg2c.py

$(INC_DIR)/fontes_ui.h: $(wildcard $(ASSETS_DIR)/fontes/*.ttf) $(TOOLS_DIR)/ttf2c.py
	@echo "  PY       Gerando fontes UI -> fontes_ui.h"
	cd $(ROOT_DIR) && $(PYTHON) tools/ttf2c.py

$(INC_DIR)/wallpaper.h: $(wildcard $(ASSETS_DIR)/wallpapers/*) $(TOOLS_DIR)/img2fb.py
	@echo "  PY       Gerando wallpaper -> wallpaper.h"
	cd $(ROOT_DIR) && $(PYTHON) tools/img2fb.py

assets: $(HEADERS_ASSETS)

# ==========================================
# REGRAS DE COMPILACAO
# ==========================================
exec.o: exec.c $(HEADERS_ASSETS)
	@echo "  CC       $< (com assets graficos)"
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.asm
	@echo "  AS       $<"
	$(ASM) $(ASFLAGS) $< -o $@

%.o: %.c
	@echo "  CC       $<"
	$(CC) $(CFLAGS) -c $< -o $@

# ==========================================
# BOOTLOADER E EFI STUB
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
# LINK DO KERNEL
# ==========================================
kernel.bin: $(OBJS)
	@echo "  LD       Kernel — $(words $(OBJS)) modulos"
	$(LD) $(LDFLAGS) $(OBJS) -o $@

# ==========================================
# IMAGEM DE DISCO
# LBA 4096 (offset 2 MiB) = kernel.bin
# LBA 8192 / 10752 / 13312 = Wallpapers (640x512 RGBA)
# ==========================================
WALLPAPERS_PNG = \
    $(ASSETS_DIR)/images/splash.png \
    $(ASSETS_DIR)/images/login.png \
    $(ASSETS_DIR)/images/desktop.png

fydelterm.img: boot.bin kernel.bin $(TOOLS_DIR)/gravar_wallpapers_disco.py $(WALLPAPERS_PNG)
	@echo "  IMG      $@"
	dd if=/dev/zero of=$@ bs=1M count=8 status=none
	dd if=boot.bin   of=$@ conv=notrunc bs=512 count=1 status=none
	dd if=kernel.bin of=$@ conv=notrunc bs=512 seek=4096 status=none
	@echo "  PY       Gravando wallpapers nos LBAs 8192, 10752 e 13312"
	$(PYTHON) $(TOOLS_DIR)/gravar_wallpapers_disco.py $@ $(ASSETS_DIR)/images

# ==========================================
# ISO
# ==========================================
boot_flp.img: boot.bin kernel.bin
	@echo "  FLP      $@"
	dd if=/dev/zero of=$@ bs=1M count=8 status=none
	dd if=boot.bin   of=$@ conv=notrunc bs=512 count=1 status=none
	dd if=kernel.bin of=$@ conv=notrunc bs=512 seek=4096 status=none

iso: boot_flp.img fydelterm.img
	@echo "  ISO      fydelterm.iso"
	rm -rf iso_root
	mkdir -p iso_root/boot
	cp boot_flp.img  iso_root/boot/boot.img
	cp fydelterm.img iso_root/boot/fydelterm.img
	cp kernel.bin    iso_root/boot/kernel.bin
	cp ../boot/fyd_boot.cfg iso_root/boot/fyd_boot.cfg 2>/dev/null || true
	genisoimage -o fydelterm.iso \
		-b boot/boot.img \
		-no-emul-boot \
		-boot-load-size 4 \
		-J -R -l \
		-V "FYDELIS_TECH_OS" \
		iso_root/
	rm -rf iso_root
	@echo "ISO pronta: fydelterm.iso"
# ==========================================
# EXECUTAR
# ==========================================
run: fydelterm.img
	@echo "Iniciando FydelisTech OS via Disco Rigido..."
	qemu-system-x86_64 \
		-drive format=raw,file=fydelterm.img,if=ide,index=0,media=disk \
		-boot c \
		-nic none \
		-no-reboot \
		-no-shutdown \
		-m 512M \
		-smp 2 \
		-display gtk \
		-serial stdio

debug: fydelterm.img
	qemu-system-x86_64 \
		-drive format=raw,file=fydelterm.img \
		-m 512M -smp 2 -serial stdio \
		-s -S

# ==========================================
# LIMPAR
# ==========================================
clean:
	@echo "Limpando..."
	rm -f *.o *.d
	rm -f ../boot/*.o ../boot/*.d
	rm -f ../drivers/*.o ../drivers/*.d
	rm -f ../pentest/*.o ../pentest/*.d
	rm -f ../grafico/*.o ../grafico/*.d
	rm -f ../user/*.o ../user/*.d
	rm -f ../virtual/*.o ../virtual/*.d
	rm -f ../system/*.o ../system/*.d
	rm -f ../idioma/*.o ../idioma/*.d
	rm -f ../apps/acessorios/*.o ../apps/acessorios/*.d
	rm -f ../apps/sistema/*.o ../apps/sistema/*.d
	rm -f *.bin *.EFI fydelterm.img boot_flp.img fydelterm.iso
	@echo "Limpo!"

distclean: clean
	rm -f $(HEADERS_ASSETS)

.PHONY: all assets iso run debug clean distclean
