; ==========================================
; IDT — FYDELIS TECH OS
; Tabela Completa de 32 Exceções da CPU + IRQ1 (Teclado)
; + Tela de Panic com Dump de Registradores
; De Salvador • Bahia 🇧🇷
; ==========================================
bits 64
default rel

; Número máximo de vetores
IDT_ENTRIES equ 256

; Ponteiro para carregar com lidt
section .rodata
align 8
idt_ptr:
    dw IDT_ENTRIES * 16 - 1    ; Limite
    dq 0                        ; Endereço base (preenchido em tempo de execução)

section .bss
align 16
idt_table:
    resb IDT_ENTRIES * 16

section .text
global idt_init
extern fydelis_panic_excecao   ; Função para a tela de erro
extern keyboard_handler        ; Tratador de interrupção do teclado (IRQ1)

; Stub local para saltar de forma segura para o handler externo sem conflito de colchetes no NASM
keyboard_stub:
    jmp keyboard_handler

; ==========================================
; MACRO — Gerar Stubs de Exceção
; ==========================================
%macro ISR_SEM_ERRO 1
global isr%1
isr%1:
    push qword 0        ; Código de erro fictício
    push qword %1       ; Número do veto
    jmp isr_comum
%endmacro

%macro ISR_COM_ERRO 1
global isr%1
isr%1:
    ; CPU já empurrou o código de erro
    push qword %1       ; Número do vetor
    jmp isr_comum
%endmacro

; ==========================================
; 32 EXCEÇÕES DA CPU — Definição Automática
; ==========================================
ISR_SEM_ERRO 0   ; #DE — Divisão por Zero
ISR_SEM_ERRO 1   ; #DB — Depuração
ISR_SEM_ERRO 2   ; — Interrupção NMI
ISR_SEM_ERRO 3   ; #BP — Ponto de Parada
ISR_SEM_ERRO 4   ; #OF — Estouro
ISR_SEM_ERRO 5   ; #BR — Limite Excedido
ISR_COM_ERRO 6   ; #UD — Instrução Inválida
ISR_SEM_ERRO 7   ; #NM — Coprocessador Indisponível
ISR_COM_ERRO 8   ; #DF — Falha Dupla
ISR_SEM_ERRO 9   ; — Reservado
ISR_COM_ERRO 10  ; #TS — Seletor Inválido
ISR_COM_ERRO 11  ; #NP — Segmento Não Presente
ISR_COM_ERRO 12  ; #SS — Falha de Pilha
ISR_COM_ERRO 13  ; #GP — Proteção Geral ⚠️
ISR_COM_ERRO 14  ; #PF — Falha de Página 📄
ISR_SEM_ERRO 15  ; — Reservado
ISR_SEM_ERRO 16  ; #MF — Erro de Matemática
ISR_COM_ERRO 17  ; #AC — Verificação de Alinhamento
ISR_SEM_ERRO 18  ; #MC — Erro de Máquina
ISR_SEM_ERRO 19  ; #XF — Exceção SIMD
ISR_SEM_ERRO 20  ; — Reservado
ISR_SEM_ERRO 21  ; — Reservado
ISR_SEM_ERRO 22  ; — Reservado
ISR_SEM_ERRO 23  ; — Reservado
ISR_SEM_ERRO 24  ; — Reservado
ISR_SEM_ERRO 25  ; — Reservado
ISR_SEM_ERRO 26  ; — Reservado
ISR_SEM_ERRO 27  ; — Reservado
ISR_SEM_ERRO 28  ; — Reservado
ISR_SEM_ERRO 29  ; — Reservado
ISR_SEM_ERRO 30  ; — Reservado
ISR_SEM_ERRO 31  ; — Reservado

; ==========================================
; TRATADOR COMUM — Salvar tudo e chamar C
; ==========================================
isr_comum:
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rbp
    push rdi
    push rsi
    push rdx
    push rcx
    push rbx
    push rax

    mov rdi, rsp
    call fydelis_panic_excecao

    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rbp
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15

    add rsp, 16   ; Remover vetor + código de erro
    iretq

; ==========================================
; FUNÇÃO DE INICIALIZAÇÃO
; ==========================================
idt_init:
    push rbx
    push rsi
    push r12
    
    xor rcx, rcx
.loop:
    ; Verifica se é o vetor de interrupção do teclado (IRQ1 = Vetor 33)
    cmp rcx, 33
    je .carrega_teclado

    ; Se estiver abaixo de 32, carrega as exceções da CPU
    cmp rcx, 32
    jl .carrega_excecao

    ; Para os demais vetores, zera
    xor rdx, rdx
    jmp .escreve_entrada

.carrega_excecao:
    lea rsi, [rel isr_vetor]
    mov rdx, [rsi + rcx * 8]
    jmp .escreve_entrada

.carrega_teclado:
    ; Usa o stub local para evitar qualquer erro de colchetes com símbolos externos
    mov rdx, keyboard_stub
    jmp .escreve_entrada

.escreve_entrada:
    lea rax, [rel idt_table]
    mov rbx, rcx
    shl rbx, 4                 ; rcx * 16
    add rax, rbx               ; rax aponta para o descritor atual
    
    ; Preenchimento explícito do descritor IDT de 16 bytes (Long Mode)
    mov word [rax], dx         ; Offset [0..15]
    mov word [rax + 2], 0x08   ; Seletor de código do kernel
    mov byte [rax + 4], 0      ; IST / Reservado
    mov byte [rax + 5], 0x8E   ; Flags: Presente, DPL=0, Tipo=Interrupção (0x8E)
    
    shr rdx, 16
    mov word [rax + 6], dx     ; Offset [16..31]
    
    shr rdx, 16
    mov dword [rax + 8], edx   ; Offset [32..63]
    mov dword [rax + 12], 0    ; Reservado

    inc rcx
    cmp rcx, IDT_ENTRIES
    jl .loop

    ; Atualizar ponteiro e carregar
    lea rax, [rel idt_table]
    mov qword [rel idt_ptr + 2], rax
    lidt [rel idt_ptr]
    
    pop r12
    pop rsi
    pop rbx
    ret

; Tabela de endereços dos stubs de exceção
section .rodata
align 8
isr_vetor:
    dq isr0,  isr1,  isr2,  isr3,  isr4,  isr5,  isr6,  isr7
    dq isr8,  isr9,  isr10, isr11, isr12, isr13, isr14, isr15
    dq isr16, isr17, isr18, isr19, isr20, isr21, isr22, isr23
    dq isr24, isr25, isr26, isr27, isr28, isr29, isr30, isr31
