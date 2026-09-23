; ==========================================
; SCHEDULER.ASM — Escalonador de Processos
; Preemptivo baseado em Timer
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64
default rel

; ==========================================
; OFFSETS DA STRUCT PCB — DEVEM bater com pcb.h em C!
; PCB_RSP já definido em context.asm (equ 0)
; ==========================================
%define PCB_RSP 0

extern trocar_contexto

section .bss
align 8
processo_atual:   resq 1         ; Ponteiro para PCB em execução
fila_prontos:     resq 16        ; Fila de processos prontos
contador_prontos: resd 1
quantum_ticks:    resd 1         ; Tempo fatia por processo
ticks_restantes:  resd 1

section .text
global scheduler_inicializar
global scheduler_adicionar
global scheduler_trocar
global scheduler_tick

; ==========================================
; INICIALIZAR ESCALONADOR
; ==========================================
scheduler_inicializar:
    mov dword [contador_prontos], 0
    mov dword [quantum_ticks], 5    ; 5 ticks = fatia de tempo
    mov dword [ticks_restantes], 0
    mov qword [processo_atual], 0
    ret

; ==========================================
; ADICIONAR PROCESSO NA FILA
; rdi = ponteiro para PCB
; ==========================================
scheduler_adicionar:
    mov eax, [contador_prontos]
    cmp rax, 16
    jae .cheio

    mov [fila_prontos + rax * 8], rdi
    inc dword [contador_prontos]

    ; Se é o primeiro → executar agora
    cmp qword [processo_atual], 0
    jnz .fila
    mov [processo_atual], rdi
    mov eax, [quantum_ticks]        ; mem→mem não existe: passa por eax
    mov [ticks_restantes], eax
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
    jnz .sem_troca

    ; Salvar contexto e escolher próximo
    mov rdi, [processo_atual]
    call escolher_proximo
    mov rsi, rax
    mov [processo_atual], rsi
    mov eax, [quantum_ticks]
    mov [ticks_restantes], eax

    ; Trocar de fato (NÃO retorna por ret — volta pelo do processo novo)
    jmp trocar_contexto

.sem_troca:
    ret

; ==========================================
; ESCOLHER PRÓXIMO PROCESSO (round-robin)
; Entrada: rdi = processo atual
; Saída:   rax = próximo processo
; ==========================================
escolher_proximo:
    mov ecx, [contador_prontos]
    test rcx, rcx
    jz .mesmo

    xor rdx, rdx
.procurar:
    mov rax, [fila_prontos + rdx * 8]
    cmp rax, rdi
    je .encontrado
    inc rdx
    cmp rdx, rcx
    jb .procurar

    ; Atual não está na fila → começa do primeiro
    xor rdx, rdx
    jmp .retornar

.encontrado:
    inc rdx
    cmp rdx, rcx
    jb .retornar
    xor rdx, rdx                    ; era o último → volta ao primeiro

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
    call escolher_proximo
    mov rsi, rax
    mov [processo_atual], rsi
    mov eax, [quantum_ticks]
    mov [ticks_restantes], eax
    jmp trocar_contexto
