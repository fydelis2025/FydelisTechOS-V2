; ======================================
; Kernel FydelisTech OS — FydelTerm v2.0
; De Salvador • Bahia 🇧🇷
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

; ✅ CORRIGIDO: apenas extern — argc/argv/buffer são definidos em buffer.asm
extern clear_screen, print_string, print_char, print_newline
extern get_key, reset_buffer, add_char, parse_line
extern interpret_command
extern set_input_base
extern argc, argv, buffer
extern buf_head, buf_tail

; --- DADOS ---
section .data
msg_welcome db 'FydelTerm v2.0 - Autor: Adiel Santos Fontes',0
prompt      db 'FydelTerm> ',0

; --- CÓDIGO PRINCIPAL ---
section .text
global start
start:
    lea       rsi, [rel msg_welcome]
    call      print_string
    call      print_newline

main_loop:
    lea       rsi, [rel prompt]
    call      print_string
    call      set_input_base

.le_tecla:
    call      get_key
    cmp       al, KEY_ENTER
    je        .executa
    cmp       al, KEY_NULL
    je        .le_tecla
    cmp       al, KEY_BACKSPACE
    je        .trata_bs

    mov       ah, al
    call      add_char
    mov       al, ah
    call      print_char
    jmp       .le_tecla

.trata_bs:
    mov       ah, al
    call      add_char
    mov       al, ah
    call      print_char
    mov       al, KEY_SPACE
    call      print_char
    mov       al, KEY_BACKSPACE
    call      print_char
    jmp       .le_tecla

.executa:
    call      print_newline

    ; Terminador nulo no fim do que foi digitado
    mov       rax, [buf_head]
    mov       byte [buffer + rax], 0

    ; Se buffer vazio, só reinicia
    cmp       qword [buf_head], 0
    je        .sem_comando

    ; ✅ CORRIGIDO: parse_line preenche argc/argv ANTES de interpretar
    call      parse_line
    call      interpret_command

.sem_comando:
    call      reset_buffer
    jmp       main_loop
