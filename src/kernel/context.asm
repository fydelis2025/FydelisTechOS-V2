; ==========================================
; CONTEXT.ASM — Troca de Contexto
; Salvar e Restaurar Registradores
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; ==========================================
; OFFSETS DA STRUCT PCB (em bytes)
; DEVEM bater com a struct pcb_t definida em C!
; Ex.: typedef struct pcb { uint64_t rsp; ... }
; Se 'rsp' não for o primeiro campo, ajuste aqui.
; ==========================================
PCB_RSP equ 0

section .text
global contexto_salvar
global contexto_restaurar
global trocar_contexto

; ==========================================
; SALVAR CONTEXTO NA PILHA DO PROCESSO
; Entrada: rdi → ponteiro para área de salvamento
; Empilha: rflags + 16 registradores (17 quadwords)
; ==========================================
contexto_salvar:
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
; Entrada: rdi → ponteiro para área de salvamento
; ==========================================
contexto_restaurar:
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
; rdi = PCB do processo atual
; rsi = PCB do próximo processo
; Obs.: contexto_salvar/contexto_restaurar NÃO devem
; ser chamados junto com trocar_contexto no mesmo PCB
; (a pilha do PCB guarda apenas o que trocar_contexto empilha).
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

    mov [rdi + PCB_RSP], rsp    ; Salvar pilha atual no PCB

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

    ; rsi aqui contém o valor restaurado do processo anterior,
    ; NÃO o PCB do próximo. Retornamos o próximo PCB em rax.
    mov rax, [rsp - 8]          ; não faça isso — veja nota abaixo
    ret
