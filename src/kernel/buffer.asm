; ======================================
; Buffer de Comandos
; Circular · Protegido · Parsing
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

section .bss
buffer:     resb BUFFER_SIZE
buf_head:   resq 1
buf_tail:   resq 1
argc:       resq 1
argv:       resq MAX_ARGS

section .text
global add_char, read_command, reset_buffer, parse_line
global argc, argv, buffer, buf_head, buf_tail

; --- Adiciona AL ao Buffer ---
add_char:
    push    rax
    push    rbx
    push    rcx

    mov     rbx, [buf_head]
    mov     rcx, [buf_tail]

    cmp     al, KEY_BACKSPACE
    je      .faz_backspace

    mov     rdx, rbx
    inc     rdx
    cmp     rdx, BUFFER_SIZE
    jb      .ok_wrap
    xor     rdx, rdx
.ok_wrap:
    cmp     rdx, rcx
    je      .fim            ; buffer cheio

    mov     [buffer + rbx], al
    mov     [buf_head], rdx
    jmp     .fim

.faz_backspace:
    cmp     rbx, rcx
    je      .fim
    dec     rbx
    jns     .atualiza
    mov     rbx, BUFFER_SIZE - 1
.atualiza:
    mov     byte [buffer + rbx], 0
    mov     [buf_head], rbx
.fim:
    pop     rcx
    pop     rbx
    pop     rax
    ret

; --- Extrai Linha até ENTER ---
read_command:
    push    rax
    push    rbx

    mov     rbx, [buf_tail]
.ler:
    cmp     rbx, [buf_head]
    je      .fim
    mov     al, [buffer + rbx]
    cmp     al, KEY_ENTER
    je      .achou
    inc     rbx
    cmp     rbx, BUFFER_SIZE
    jb      .ler
    xor     rbx, rbx
    jmp     .ler

.achou:
    mov     byte [buffer + rbx], 0
    inc     rbx
    cmp     rbx, BUFFER_SIZE
    jb      .atualiza
    xor     rbx, rbx
.atualiza:
    mov     [buf_tail], rbx
.fim:
    pop     rbx
    pop     rax
    ret

; --- Zera Buffer e Argumentos ---
reset_buffer:
    push    rax
    push    rcx
    push    rdi
    mov     rdi, buffer
    mov     rcx, BUFFER_SIZE
    xor     rax, rax
    rep     stosb
    mov     qword [buf_head], 0
    mov     qword [buf_tail], 0
    mov     qword [argc], 0
    mov     rcx, MAX_ARGS
    mov     rdi, argv
    rep     stosq
    pop     rdi
    pop     rcx
    pop     rax
    ret

; --- Parsing → argc/argv ---
parse_line:
    push    rax
    push    rbx
    push    rcx
    push    rsi
    push    rdi

    mov     rsi, buffer
    mov     rdi, argv
    xor     rcx, rcx

    ; Limpa o vetor argv antes de preencher
    push    rcx
    push    rdi
    mov     rcx, MAX_ARGS
    xor     rax, rax
    rep     stosq
    pop     rdi
    pop     rcx

.pula_espacos:
    mov     al, [rsi]
    cmp     al, 0
    je      .fim_parse
    cmp     al, ' '
    je      .avanca_espaco
    cmp     al, 9
    je      .avanca_espaco
    jmp     .salva_arg

.avanca_espaco:
    inc     rsi
    jmp     .pula_espacos

.salva_arg:
    cmp     rcx, MAX_ARGS
    jge     .fim_parse

    mov     [rdi + rcx*8], rsi
    inc     rcx

.proxima_letra:
    mov     al, [rsi]
    cmp     al, 0
    je      .fim_parse
    cmp     al, ' '
    je      .termina_arg
    cmp     al, 9
    je      .termina_arg
    inc     rsi
    jmp     .proxima_letra
.termina_arg:
    mov     byte [rsi], 0
    inc     rsi
    jmp     .pula_espacos      ; ✅ CORRIGIDO: era "sjmp" (não existe em x86)
.fim_parse:
    mov     [argc], rcx

    pop     rdi
    pop     rsi
    pop     rcx
    pop     rbx
    pop     rax
    ret
