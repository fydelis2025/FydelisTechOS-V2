; ==========================================
; EXCEPTIONS.ASM — Tratadores Específicos
; #PF Falha de Página, #GP Proteção Geral, #DE Divisão por Zero
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64
default rel

section .text
global isr_pf_handler
global isr_gp_handler
global isr_de_handler
global isr_comum
global fydelis_panic_excecao
global qt_main_entry

fydelis_panic_excecao:
    cli
    hlt
    jmp fydelis_panic_excecao

qt_main_entry:
    ret
    
isr_comum:
    ; Frame: [error_code?] [rip] [cs] [rflags] [rsp] [ss]
    ; (só os vetores 8/10–14/17 têm error_code)
    mov rdi, [rsp]               ; error_code (ou rip se não houver)
    call fydelis_panic_excecao   ; panic não retorna — para aqui
.hang:
    cli
    hlt
    jmp .hang

; ==========================================
; #PF — FALHA DE PÁGINA (Vetor 14)
; Lê CR2 para saber qual endereço causou a falha
; Pilha na entrada: [error_code] [rip] [cs] [rflags] [rsp] [ss]
; ==========================================
isr_pf_handler:
    push rax
    push rdi

    mov rax, cr2                 ; endereço que causou a falha
    mov rdi, rsp
    add rdi, 16                  ; aponta para o error_code do frame da CPU
    mov [rdi], rax               ; sobrescreve o slot p/ o panic ler CR2

    pop rdi
    pop rax
    jmp isr_comum

; ==========================================
; #GP — PROTEÇÃO GERAL (Vetor 13)
; Pilha na entrada: [error_code] [rip] [cs] [rflags] [rsp] [ss]
; ==========================================
isr_gp_handler:
    jmp isr_comum

; ==========================================
; #DE — DIVISÃO POR ZERO (Vetor 0)
; Pilha na entrada: SEM error_code → [rip] [cs] [rflags] [rsp] [ss]
; ==========================================
isr_de_handler:
    push 0                       ; error_code fake (CPU não empilha p/ #DE)
    jmp isr_comum
