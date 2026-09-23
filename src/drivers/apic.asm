; ==========================================
; APIC.ASM — Controlador de Interrupções
; Local APIC + IOAPIC
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; Endereços físicos padrão
APIC_BASE_PHYS  equ 0xFEE00000
IOAPIC_BASE_PHYS equ 0xFEC00000

; Registradores do Local APIC
APIC_ID         equ 0x020
APIC_EOI        equ 0x0B0
APIC_SVR        equ 0x0F0
APIC_LVT_TIMER  equ 0x320
APIC_TIMER_INIT equ 0x380
APIC_TIMER_DIV  equ 0x3E0

; Registradores do IOAPIC
IOAPIC_REG_SEL  equ 0x00
IOAPIC_REG_DATA equ 0x10

section .bss
align 4096
apic_ptr:    resq 1
ioapic_ptr:  resq 1
apic_ok:     resd 1

section .text
global apic_detect
global apic_inicializar
global apic_eoi
global ioapic_redirecionar_irq

; ==========================================
; 🔍 DETECTAR SUPORTE AO APIC NA CPU
; ==========================================
apic_detect:
    mov ecx, 1
    cpuid
    test edx, 1 << 9           ; Bit 9 = APIC disponível
    jz .nao_tem
    mov rax, 1
    ret
.nao_tem:
    xor rax, rax
    ret

; ==========================================
; ⚡ HABILITAR APIC
; ==========================================
apic_inicializar:
    ; Desligar PIC legado
    mov al, 0xFF
    out 0xA1, al
    out 0x21, al

    ; Ler MSR de base do APIC
    mov ecx, 0x1B
    rdmsr
    bts edx, 8                  ; Garantir APIC Global Enable
    wrmsr

    mov qword [apic_ptr], APIC_BASE_PHYS
    mov qword [ioapic_ptr], IOAPIC_BASE_PHYS
    mov dword [apic_ok], 1

    ; Habilitar APIC no SVR
    mov rdi, [apic_ptr]
    mov dword [rdi + APIC_SVR], 0x1000 | 0xFF  ; Ligar + vetor spúrio

    ret

; ==========================================
; ✅ FIM DE INTERRUPÇÃO
; ==========================================
apic_eoi:
    cmp dword [apic_ok], 0
    je .pic_eoi
    mov rdi, [apic_ptr]
    mov dword [rdi + APIC_EOI], 0
    ret
.pic_eoi:
    push rax
    mov al, 0x20
    out 0x20, al
    pop rax
    ret

; ==========================================
; 🔄 REDIRECIONAR IRQ PARA VETOR
; irq = rdi, vetor = rsi
; ==========================================
ioapic_redirecionar_irq:
    ; Calcular registrador de entrada
    mov rax, rdi
    shl rax, 1                  ; Cada IRQ = 2 registradores
    mov rdx, rax

    ; Escrever parte baixa
    mov rdi, [ioapic_ptr]
    mov dword [rdi + IOAPIC_REG_SEL], edx
    mov r8, rsi
    and r8, 0xFF
    mov dword [rdi + IOAPIC_REG_DATA], r8d

    ; Parte alta = CPU 0
    inc edx
    mov dword [rdi + IOAPIC_REG_SEL], edx
    mov dword [rdi + IOAPIC_REG_DATA], 0

    ret