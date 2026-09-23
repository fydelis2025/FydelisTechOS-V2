; ==========================================
; CONTEXT.ASM — Troca de Contexto
; Salvar e Restaurar Registradores
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

section .text
global contexto_salvar
global contexto_restaurar
global trocar_contexto

; ==========================================
; SALVAR CONTEXTO NA PILHA DO PROCESSO
; ==========================================
contexto_salvar:
    ; rdi → ponteiro para área de salvamento
    pushfq
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

    ; Salvar ponteiro de pilha atual
    mov [rdi], rsp
    ret

; ==========================================
; RESTAURAR CONTEXTO DA PILHA
; ==========================================
contexto_restaurar:
    ; rdi → ponteiro para área de salvamento
    mov rsp, [rdi]

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    popfq
    ret

; ==========================================
; TROCAR DE UM PROCESSO PARA OUTRO
; rdi = PCB atual, rsi = próximo PCB
; ==========================================
trocar_contexto:
    ; Salvar contexto do processo atual
    pushfq
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

    mov [rdi + PCB_RSP], rsp   ; Salvar pilha atual no PCB

    ; Carregar contexto do próximo processo
    mov rsp, [rsi + PCB_RSP]

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    popfq

    ; Atualizar ponteiro do processo atual
    mov rax, rsi
    ret