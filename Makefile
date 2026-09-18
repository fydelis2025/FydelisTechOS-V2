# ==========================================
# FYDELIS TECH OS v2.0 — MAKEFILE UNIFICADO
# Compila: Kernel ASM + FydelisWin + FydelisShell + Interface Qt
# De Salvador • Bahia 🇧🇷
# ✅ ESTRUTURA ATUALIZADA: src/boot | src/inc | src/kernel
# ==========================================

# ⚙️ FERRAMENTAS
ASM       = nasm
ASFLAGS   = -f elf64 -I src/inc/          # ✅ src/inc como pediu
CC        = gcc
CFLAGS    = -Wall -Wextra -std=c17 -O2 -I src/inc -I src/shell  # ✅ atualizado
CXX       = g++
CXXFLAGS  = -Wall -Wextra -std=c++20 -O2 $(shell pkg-config --cflags Qt6Core Qt6Gui Qt6Widgets)
LDFLAGS   = 
QT_LIBS   = $(shell pkg-config --libs Qt6Core Qt6Gui Qt6Widgets)
LD        = ld
LDFLAGS_KERNEL = -T src/boot/linker.ld --oformat binary  # ✅ src/boot/linker.ld

# 📦 PASTAS DE SAÍDA
BUILDDIR  = build
BINDIR    = bin
ISODIR    = iso_root

# 🧩 KERNEL — ASM → src/kernel/ ✅
KERNEL_ASM = $(BUILDDIR)/kernel/start.o \
             $(BUILDDIR)/kernel/video.o \
             $(BUILDDIR)/kernel/keyboard.o \
             $(BUILDDIR)/kernel/editor.o \
             $(BUILDDIR)/kernel/buffer.o \
             $(BUILDDIR)/kernel/commands.o

KERNEL_BIN = $(BUILDDIR)/kernel.bin

# 🪟 FYDELISWIN — Camada de Compatibilidade Win32
FYDELISWIN_SRC = src/system/fydeliswin/fydeliswin.c \
                 src/system/fydeliswin/kernel32.c \
                 src/system/fydeliswin/user32.c \
                 src/system/fydeliswin/loader/pe_parser.c \
                 src/system/fydeliswin/loader/pe_loader.c
FYDELISWIN_OBJ = $(patsubst src/%.c,$(BUILDDIR)/%.o,$(FYDELISWIN_SRC))
FYDELISWIN_LIB = $(BINDIR)/libfydeliswin.so

# ⚡ FYDELISHELL — PowerShell Nativo
SHELL_SRC = src/shell/powershell/fydelishell.c \
            src/shell/launcher.c
SHELL_OBJ = $(patsubst src/%.c,$(BUILDDIR)/%.o,$(SHELL_SRC))
SHELL_BIN = $(BINDIR)/fydelishell

# 🖥️ INTERFACE QT — Splash + Login + Desktop
UI_SRC = src/core/main.cpp \
         src/ui/splash/splashscreen.cpp \
         src/ui/login/loginscreen.cpp \
         src/ui/desktop/desktop.cpp
UI_OBJ = $(patsubst src/%.cpp,$(BUILDDIR)/%.o,$(UI_SRC))
UI_APP = $(BINDIR)/FydelisTechOS

# 📜 BOOTLOADER → src/boot/ ✅
BOOTLOADER = $(BUILDDIR)/boot.bin

# 🎯 ALVO PRINCIPAL
all: estrutura kernel fydeliswin shell ui
	@echo ""
	@echo "✅ ==================================================="
	@echo "✅   FYDELIS TECH OS v2.0 — COMPILADO COM SUCESSO!"
	@echo "✅   Kernel + FydelisWin + FydelisShell + Interface"
	@echo "✅   Salvador • Bahia 🇧🇷"
	@echo "✅ ==================================================="
	@echo ""
	@echo "▶️  Para executar:"
	@echo "   Modo nativo:   $(UI_APP)"
	@echo "   Modo shell:    $(SHELL_BIN)"
	@echo "   Emulador:      qemu-system-x86_64 -cdrom $(BINDIR)/FydelisTechOS-v2.iso"
	@echo ""

# 📁 CRIAR PASTAS
estrutura:
	@mkdir -p $(BUILDDIR)/kernel $(BUILDDIR)/system/fydeliswin/loader $(BUILDDIR)/shell/powershell $(BINDIR) $(ISODIR)

# 🧩 COMPILAR KERNEL ASM → src/kernel/ ✅
$(BUILDDIR)/kernel/%.o: src/kernel/%.asm
	@echo "🔧 ASM  $<"
	@$(ASM) $(ASFLAGS) $< -o $@

$(KERNEL_BIN): $(KERNEL_ASM)
	@echo "🔗 Linkando kernel..."
	@$(LD) $(LDFLAGS_KERNEL) $(KERNEL_ASM) -o $@
	@echo "✅ Kernel compilado: $@"

# 🪃 BOOTLOADER → src/boot/ ✅
boot: estrutura
	@echo "🔧 Bootloader..."
	@$(ASM) -f bin src/boot/bootloader.asm -o $(BOOTLOADER)

kernel: estrutura $(KERNEL_BIN) boot

# 🪟 COMPILAR FYDELISWIN
$(BUILDDIR)/system/fydeliswin/%.o: src/system/fydeliswin/%.c
	@echo "🔧 C    $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -fPIC -c $< -o $@

$(BUILDDIR)/system/fydeliswin/loader/%.o: src/system/fydeliswin/loader/%.c
	@echo "🔧 C    $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -fPIC -c $< -o $@

fydeliswin: estrutura $(FYDELISWIN_OBJ)
	@echo "📦 Criando biblioteca FydelisWin..."
	@$(CC) $(CFLAGS) -shared -o $(FYDELISWIN_LIB) $(FYDELISWIN_OBJ)
	@echo "✅ FydelisWin pronta: $(FYDELISWIN_LIB)"

# ⚡ COMPILAR FYDELISHELL
$(BUILDDIR)/shell/powershell/%.o: src/shell/powershell/%.c
	@echo "🔧 C    $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILDDIR)/shell/%.o: src/shell/%.c
	@echo "🔧 C    $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@

shell: estrutura fydeliswin $(SHELL_OBJ)
	@echo "⚡ Compilando FydelisShell (PowerShell Nativo)..."
	@$(CC) $(CFLAGS) -o $(SHELL_BIN) $(SHELL_OBJ) -L$(BINDIR) -lfydeliswin -Wl,-rpath,'$$ORIGIN'
	@echo "✅ FydelisShell pronto: $(SHELL_BIN)"

# 🖥️ COMPILAR INTERFACE QT
$(BUILDDIR)/core/%.o: src/core/%.cpp
	@echo "🔧 C++  $<"
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILDDIR)/ui/splash/%.o: src/ui/splash/%.cpp
	@echo "🔧 C++  $<"
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILDDIR)/ui/login/%.o: src/ui/login/%.cpp
	@echo "🔧 C++  $<"
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILDDIR)/ui/desktop/%.o: src/ui/desktop/%.cpp
	@echo "🔧 C++  $<"
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

ui: estrutura fydeliswin $(UI_OBJ)
	@echo "🖥️ Compilando Interface Qt..."
	@$(CXX) $(CXXFLAGS) -o $(UI_APP) $(UI_OBJ) $(QT_LIBS) -L$(BINDIR) -lfydeliswin -Wl,-rpath,'$$ORIGIN'
	@echo "✅ Interface pronta: $(UI_APP)"

# 💿 GERAR IMAGEM ISO
iso: all
	@echo "💿 Gerando ISO..."
	@cp $(BOOTLOADER) $(ISODIR)/boot.bin
	@cp $(KERNEL_BIN) $(ISODIR)/kernel.bin
	@cp -r $(BINDIR)/* $(ISODIR)/ 2>/dev/null || true
	@genisoimage -o $(BINDIR)/FydelisTechOS-v2.iso -b boot.bin -no-emul-boot \
		-boot-load-seg 0x07C0 -boot-load-size 4 -input-charset utf-8 \
		$(ISODIR)/
	@echo "✅ ISO pronta: $(BINDIR)/FydelisTechOS-v2.iso"

# 🧹 LIMPAR
clean:
	@echo "🧹 Limpando..."
	@rm -rf $(BUILDDIR) $(BINDIR) $(ISODIR)
	@echo "✅ Limpo!"

# 🔄 RECONSTRUIR TUDO
rebuild: clean all

.PHONY: all estrutura kernel boot fydeliswin shell ui iso clean rebuild