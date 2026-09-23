; ==========================================
; EXCEPTIONS.ASM — Tratadores Específicos
; #PF Falha de Página, #GP Proteção Geral, #DE Divisão por Zero
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

extern fydelis_panic_excecao

section .text
global isr_pf_handler
global isr_gp_handler
global isr_de_handler

; ==========================================
; #PF — FALHA DE PÁGINA (Vetor 14)
; Lê CR2 para saber qual endereço causou a falha
; ==========================================
isr_pf_handler:
    ; Pilha: [error_code] [rip] [cs] [rflags] [rsp] [ss]
    push rax
    push rdi

    ; Ler endereço que causou a falha
    mov rax, cr2
    mov rdi, rsp
    add rdi, 16        ; Após nossos pushes → aponta para frame da CPU
    mov [rdi + 8], rax ; Guardar endereço no frame para o panic

    pop rdi
    pop rax
    jmp isr_comum      ; Repassar para o tratador genérico

; ==========================================
; #GP — PROTEÇÃO GERAL (Vetor 13)
; Violação de privilégio, acesso proibido
; ==========================================
isr_gp_handler:
    jmp isr_comum

; ==========================================
; #DE — DIVISÃO POR ZERO (Vetor 0)
; ==========================================
isr_de_handler:
    jmp isr_comum