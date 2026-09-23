; ==========================================
; SCHEDULER.ASM — Escalonador de Processos
; Preemptivo baseado em Timer
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

%include "pcb.h"

section .bss
align 8
processo_atual:  resq 1         ; Ponteiro para PCB em execução
fila_prontos:    resq 16        ; Fila de processos prontos
contador_prontos: resd 1
quantum_ticks:   resd 1         ; Tempo fatia por processo
ticks_restantes: resd 1

section .text
global scheduler_inicializar
global scheduler_adicionar
global scheduler_trocar
global scheduler_tick
global processo_atual

; ==========================================
; INICIALIZAR ESCALONADOR
; ==========================================
scheduler_inicializar:
    mov dword [contador_prontos], 0
    mov dword [quantum_ticks], 5   ; 5 ticks = fatia de tempo
    mov dword [ticks_restantes], 0
    mov qword [processo_atual], 0
    ret

; ==========================================
; ADICIONAR PROCESSO NA FILA
; rdi = ponteiro para PCB
; ==========================================
scheduler_adicionar:
    mov rax, [contador_prontos]
    cmp rax, 16
    jae .cheio

    mov [fila_prontos + rax * 8], rdi
    inc dword [contador_prontos]

    ; Se é o primeiro → executar agora
    cmp qword [processo_atual], 0
    jnz .fila
    mov [processo_atual], rdi
    mov dword [ticks_restantes], [quantum_ticks]
.fila:
    mov rax, 1
    ret
.cheio:
    xor rax, rax
    ret

; ==========================================
; TICK DO TIMER — Verificar troca
; Chamado a cada interrupção do PIT/APIC Timer
; ==========================================
scheduler_tick:
    dec dword [ticks_restantes]
    jz .trocar_agora
    ret

.trocar_agora:
    ; Salvar contexto e escolher próximo
    mov rdi, [processo_atual]
    call escolher_proximo
    mov rsi, rax
    mov [processo_atual], rsi
    mov dword [ticks_restantes], [quantum_ticks]

    ; Trocar de fato
    jmp trocar_contexto

; ==========================================
; ESCOLHER PRÓXIMO PROCESSO
; ==========================================
escolher_proximo:
    ; rdi = processo atual
    mov rcx, [contador_prontos]
    test rcx, rcx
    jz .mesmo

    ; Procurar próximo na fila (round-robin simples)
    mov rdx, 0
.procurar:
    mov rax, [fila_prontos + rdx * 8]
    cmp rax, rdi
    je .encontrado
    inc rdx
    cmp rdx, rcx
    jb .procurar

    ; Atual é o último → voltar ao primeiro
    mov rdx, 0

.encontrado:
    inc rdx
    cmp rdx, rcx
    jb .retornar
    xor rdx, rdx

.retornar:
    mov rax, [fila_prontos + rdx * 8]
    ret

.mesmo:
    mov rax, rdi
    ret

; ==========================================
; FORÇAR TROCA (chamado quando processo bloqueia)
; ==========================================
scheduler_trocar:
    mov rdi, [processo_atual]
    mov rsi, rdi
    call escolher_proximo
    mov rsi, rax
    mov [processo_atual], rsi
    mov dword [ticks_restantes], [quantum_ticks]
    jmp trocar_contexto