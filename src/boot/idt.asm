; ==========================================
; IDT — FYDELIS TECH OS
; Tabela Completa de 32 Exceções da CPU
; + Tela de Panic com Dump de Registradores
; De Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; Número máximo de vetores
IDT_ENTRIES equ 256

; Ponteiro para carregar com lidt
section .rodata
align 8
idt_ptr:
    dw IDT_ENTRIES * 16 - 1    ; Limite
    dq 0                        ; Endereço base (preenchido em tempo de execução)

; Estrutura de um descritor IDT:
; 0..15  : Offset baixo
; 16..31 : Seletor de Segmento
; 32..39 : Reservado
; 40..47 : Flags
; 48..63 : Offset alto

section .bss
align 16
idt_table:
    resb IDT_ENTRIES * 16

; Estrutura de Contexto para passar ao tratador C
struc Regs
    .rax    resq 1
    .rbx    resq 1
    .rcx    resq 1
    .rdx    resq 1
    .rsi    resq 1
    .rdi    resq 1
    .rbp    resq 1
    .rsp    resq 1
    .r8     resq 1
    .r9     resq 1
    .r10    resq 1
    .r11    resq 1
    .r12    resq 1
    .r13    resq 1
    .r14    resq 1
    .r15    resq 1
    .rip    resq 1
    .rflags resq 1
    .error_code resq 1
    .vector resq 1
endstruc

section .text
global idt_init
extern fydelis_panic_excecao   ; Função em C/C++ para a tela de erro

; ==========================================
; MACRO — Gerar Stubs de Exceção
; ==========================================
%macro ISR_SEM_ERRO 1
global isr%1
isr%1:
    push qword 0        ; Código de erro fictício
    push qword %1       ; Número do vetor
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
    ; Salvar registradores gerais
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

    ; Passar ponteiro da pilha como argumento
    mov rdi, rsp
    call fydelis_panic_excecao

    ; Se voltar (não recomendado), restaurar e sair
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
    ; Preencher tabela com os 32 stubs
    mov rcx, 0
    .loop:
        mov rdx, [isr_vetor + rcx * 8]
        lea rax, [idt_table + rcx * 16]
        
        ; Offset [0..15]
        mov word [rax], dx
        ; Seletor de código do kernel
        mov word [rax + 2], 0x08
        ; Flags: Presente, DPL=0, Tipo=Interrupção (0x8E)
        mov byte [rax + 4], 0
        mov byte [rax + 5], 0x8E
        ; Offset [32..63]
        shr rdx, 16
        mov word [rax + 6], dx
        shr rdx, 16
        mov dword [rax + 8], edx
        mov dword [rax + 12], 0

        inc rcx
        cmp rcx, 32
        jl .loop

    ; Atualizar ponteiro e carregar
    mov qword [idt_ptr + 2], idt_table
    lidt [idt_ptr]
    ret

; Tabela de endereços dos stubs
section .rodata
align 8
isr_vetor:
    dq isr0,  isr1,  isr2,  isr3,  isr4,  isr5,  isr6,  isr7
    dq isr8,  isr9,  isr10, isr11, isr12, isr13, isr14, isr15
    dq isr16, isr17, isr18, isr19, isr20, isr21, isr22, isr23
    dq isr24, isr25, isr26, isr27, isr28, isr29, isr30, isr31