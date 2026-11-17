; ============================================================================
; EXCEPTIONS.ASM — Tratadores de Excecoes de Hardware x86_64 & Kernel Panic
; #DE (0), #DF (8), #GP (13), #PF (14) e Excecoes Gerais
; FydelisTech OS v4.2 — Integrado ao FydLog & Framebuffer VESA
; Salvador - Bahia
; ============================================================================
bits 64
default rel

section .text
global isr_pf_handler
global isr_gp_handler
global isr_de_handler
global isr_df_handler
global isr_comum
global fydelis_panic_excecao
global qt_main_entry

extern kernel_panic_handler

qt_main_entry:
    ret

; Ponto de parada absoluto (chamado apos exibir a tela de Panic)
fydelis_panic_excecao:
    cli
.halt_loop:
    hlt
    jmp .halt_loop

; ============================================================================
; DISPATCHER COMUM DE EXCECOES
; Pilha esperada na entrada:
;   [rsp + 0]  = vetor_id   (empilhado pelos stubs)
;   [rsp + 8]  = error_code (real da CPU ou 0 fake)
;   [rsp + 16] = rip
;   [rsp + 24] = cs
;   [rsp + 32] = rflags
;   [rsp + 40] = rsp_original
;   [rsp + 48] = ss
; ============================================================================
isr_comum:
    cli

    ; Salva todos os registradores de proposito geral na pilha
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Prepara argumentos System V AMD64 ABI para kernel_panic_handler:
    ;   RDI = vetor_id
    ;   RSI = error_code
    ;   RDX = rip (instrucao que falhou)
    ;   RCX = cr2 (endereco faltante no caso de #PF)
    ;   R8  = rsp_original
    ;   R9  = ponteiro para o dump dos 15 registradores salvos
    mov rdi, [rsp + 15*8 + 0]   ; vetor_id
    mov rsi, [rsp + 15*8 + 8]   ; error_code
    mov rdx, [rsp + 15*8 + 16]  ; rip
    mov rcx, cr2                ; cr2
    mov r8,  [rsp + 15*8 + 40]  ; rsp original
    mov r9,  rsp                ; array de registradores (r15..rax)

    ; Alinha RSP em 16 bytes antes da chamada C
    and rsp, -16
    call kernel_panic_handler

    ; Nunca deve retornar, mas trava com seguranca caso retorne
    jmp fydelis_panic_excecao

; ============================================================================
; #DE — DIVISAO POR ZERO (Vetor 0 — CPU NAO empilha error_code)
; ============================================================================
isr_de_handler:
    push 0                      ; error_code fake = 0
    push 0                      ; vetor_id = 0 (#DE)
    jmp isr_comum

; ============================================================================
; #DF — FALHA DUPLA / DOUBLE FAULT (Vetor 8 — CPU empilha error_code = 0)
; ============================================================================
isr_df_handler:
    push 8                      ; vetor_id = 8 (#DF)
    jmp isr_comum

; ============================================================================
; #GP — PROTECAO GERAL (Vetor 13 — CPU empilha error_code)
; ============================================================================
isr_gp_handler:
    push 13                     ; vetor_id = 13 (#GP)
    jmp isr_comum

; ============================================================================
; #PF — FALHA DE PAGINA (Vetor 14 — CPU empilha error_code e grava CR2)
; ============================================================================
isr_pf_handler:
    push 14                     ; vetor_id = 14 (#PF)
    jmp isr_comum
