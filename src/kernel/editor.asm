; ======================================
; EDITOR FYDEL v2.1 — Estilo Nano
; De Salvador • Bahia 🇧🇷
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

extern clear_screen, print_string, print_char, print_newline
extern get_key, move_cursor

global do_fydel

section .data
msg_teste_fydel db 'Editor carregado com sucesso! Pressione Ctrl+X para sair.', 0

section .text

; ======================================
; ENTRY: do_fydel
; ======================================
do_fydel:
    push    rbx
    push    rsi
    push    rdi

    call    clear_screen
    lea     rsi, [rel msg_teste_fydel]
    call    print_string
    call    print_newline

.loop_teste:
    call    get_key
    cmp     al, 24          ; Ctrl+X para sair
    je      .sair_teste
    
    ; Echo seguro da tecla premida
    test    al, al
    jz      .loop_teste
    call    print_char
    jmp     .loop_teste

.sair_teste:
    call    clear_screen
    pop     rdi
    pop     rsi
    pop     rbx
    ret
