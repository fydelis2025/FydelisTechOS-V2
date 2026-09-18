; ======================================
; FydelTerm OS · Constantes Globais
; Arquitetura: x86_64 Long Mode
; Padrão: System V AMD64 / NASM
; ======================================
%ifndef FYDELTERM_INC
%define FYDELTERM_INC

; --- Localização na Memória ---
KERNEL_BASE     equ 0x7E00          ; Kernel carregado aqui
VIDEO_TEXT_BASE equ 0xB8000         ; Memória vídeo texto
STACK_TOP       equ 0x7C000         ; Topo da pilha (alinhado 16B)

; --- Buffer e Argumentos ---
BUFFER_SIZE     equ 128
MAX_ARGS        equ 8

; --- Códigos de Teclas ASCII ---
KEY_NULL        equ 0x00
KEY_BACKSPACE   equ 0x08
KEY_TAB         equ 0x09
KEY_NEWLINE     equ 0x0A
KEY_ENTER       equ 0x0D
KEY_SPACE       equ 0x20

; --- Atributos de Cor (Texto) ---
COL_BLACK       equ 0x00
COL_BLUE        equ 0x01
COL_GREEN       equ 0x02
COL_CYAN        equ 0x03
COL_RED         equ 0x04
COL_MAGENTA     equ 0x05
COL_BROWN       equ 0x06
COL_LGRAY       equ 0x07
COL_DGRAY       equ 0x08
COL_LBLUE       equ 0x09
COL_LGREEN      equ 0x0A
COL_LCYAN       equ 0x0B
COL_LRED        equ 0x0C
COL_LMAGENTA    equ 0x0D
COL_YELLOW      equ 0x0E
COL_WHITE       equ 0x0F
DEF_ATTR        equ (COL_BLACK << 4) | COL_LGREEN  ; Fundo preto com letras verde neon brilhante

; --- Variáveis Compartilhadas (declaradas no kernel) ---
extern argc, argv, cursor_pos
extern buf_head, buf_tail, buffer

%endif
