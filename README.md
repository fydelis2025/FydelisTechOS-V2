⚡ FydelisTech OS v4.2

Sistema Operacional 64-bit (x86_64) construído do zero em Assembly & C Freestanding

A 64-bit (x86_64) Operating System built from scratch in Assembly & Freestanding C

🇧🇷 Português • 🇺🇸 English

🇧🇷 Português

📌 Sobre o Projeto

O FydelisTech OS é um sistema operacional independente (freestanding) de 64 bits (x86_64 Long Mode), desenvolvido do zero sem dependências de bibliotecas padrão (libc) ou sistemas hospedeiros.

Na versão v4.2, o sistema abandonou o modo texto legado 80×25 (0xB8000) e passou a operar integralmente em modo gráfico de alta resolução via Linear Framebuffer VESA 32-bit (XRGB8888), combinando drivers de baixo nível em NASM Assembly com um motor gráfico e gerenciador de desktop interativo em C.

✨ Principais Funcionalidades

Kernel 64-bit Long Mode: Bootloader próprio, configuração de GDT/IDT, paginação, gerenciamento de memória física/heap e interrupções.

Renderização Gráfica Direta (VESA 32-bit): Desenho pixel a pixel no framebuffer linear com fontes bitmap próprias (8×8 e 8×16 ASCII completa) e decodificador UTF-8 integrado no terminal.

Terminal FydelTerm ([1]): Shell interativo em modo gráfico com suporte a comandos do sistema, editor integrado, diagnósticos de hardware (CPUID, memória, discos) e módulo de segurança/rede.

Área de Trabalho Gráfica ([2]):

Tela de carregamento (Splash Screen) animada e responsiva à resolução do monitor.

Tela de autenticação gráfica com suporte a teclado e clique do mouse.

Desktop com Barra de Tarefas, Menu Iniciar interativo, atalhos rápidos e janelas arrastáveis com botão de fechar ([X]).

Drivers de Hardware Nativos:

Mouse PS/2 (Controlador 8042): Máquina de estado de 3 bytes com sincronização de pacotes, clipping de resolução e cursor gráfico sem rastro (background save/restore).

Teclado PS/2: Leitura via scancodes sem conflito com a porta auxiliar do mouse.

Camada de Vídeo & GPU Dispatch: Suporte a VESA Linear FB, detecção de barramento PCI (pci_gpu.asm) e estrutura modular para drivers Intel, AMD, VirtIO e UEFI GOP.

🗂️ Estrutura do Repositório

src/
├── boot/       # Bootloader (512B), GDT, IDT, interrupções e linker script
├── kernel/     # Núcleo 64-bit (kernel.asm), motor gráfico C (exec.c), memória e Makefile
├── drivers/    # Drivers PS/2 (teclado/mouse), vídeo VESA, fonte bitmap, PCI, disco e rede
├── grafico/    # Compositor de janelas (fb_server.asm), GPU dispatch, VESA FB e GOP
├── virtual/    # Detecção e suporte a virtualização (VMX / SVM / EPT)
├── user/       # Espaço de usuário, syscalls e clientes de sistema
└── system/     # Logs, configurações e stubs de compatibilidade


🚀 Como Compilar e Executar (QEMU)

Pré-requisitos (Linux / Debian / Ubuntu)

sudo apt update
sudo apt install build-essential nasm gcc ld qemu-system-x86 genisoimage


Compilando e rodando

cd src/kernel
make clean && make
make run


Credenciais padrão da Tela de Login Gráfica:

Usuário: admin | Senha: fydelis2026 (já preenchidos por padrão — basta pressionar Enter ou clicar em ENTRAR).

🎮 Atalhos e Navegação

Menu de Boot: Pressione 1 para abrir o Terminal FydelTerm ou 2 para iniciar a Área de Trabalho Gráfica.

Na Tela de Login: Use Tab ou clique para alternar entre Usuário e Senha; Enter ou clique no botão para acessar.

No Desktop: Clique e segure na barra de título da janela para arrastá-la; clique em [ Iniciar ] para abrir o menu; pressione ESC para retornar ao terminal.

🇺🇸 English

📌 About the Project

FydelisTech OS is a 64-bit (x86_64 Long Mode) freestanding operating system built from scratch without standard library (libc) dependencies or host OS layers.

In v4.2, the OS transitioned from legacy 80×25 VGA text mode (0xB8000) to a full 32-bit VESA Linear Framebuffer (XRGB8888) graphics pipeline, combining low-level NASM Assembly hardware drivers with a responsive Freestanding C windowing and desktop engine.

✨ Key Features

64-bit Long Mode Kernel: Custom 512-byte bootloader, GDT/IDT setup, paging, physical memory/heap allocator, and interrupt handling.

Direct VESA 32-bit Graphics Rendering: Pixel-level framebuffer rendering with custom bitmap fonts (8×8 and full 8×16 ASCII) and an integrated UTF-8 terminal decoder.

FydelTerm Shell ([1]): Interactive graphical console featuring system commands, built-in text editor, hardware diagnostics (CPUID, RAM, storage), and network/security utilities.

Graphical Desktop Environment ([2]):

Resolution-aware animated splash screen.

Interactive graphical login screen supporting both keyboard and mouse input.

Desktop workspace with Taskbar, Start Menu, quick-launch shortcuts, and draggable windows with close ([X]) controls.

Native Hardware Drivers:

PS/2 Mouse Driver (8042 Controller): 3-byte packet state machine with synchronization, screen boundary clamping, and flicker-free sprite cursor (cursor_buffer background save/restore).

PS/2 Keyboard Driver: Scancode polling isolated from auxiliary mouse packets.

Graphics & GPU Dispatch Layer: VESA Linear Framebuffer, PCI video bus scanner (pci_gpu.asm), and modular driver hooks for Intel, AMD, VirtIO, and UEFI GOP.

🚀 Building and Running (QEMU)

Prerequisites (Linux / Debian / Ubuntu)

sudo apt update
sudo apt install build-essential nasm gcc ld qemu-system-x86 genisoimage


Build & Run

cd src/kernel
make clean && make
make run


Default Graphical Login Credentials:

Username: admin | Password: fydelis2026 (pre-filled by default — press Enter or click ENTRAR to log in).
