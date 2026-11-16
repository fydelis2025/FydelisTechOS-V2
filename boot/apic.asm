; ==========================================
; APIC — Controlador de Interrupções Moderno
; Substitui o PIC 8259A obsoleto
; FydelisTech OS · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; Registros MMIO do APIC Local
APIC_ID      equ 0x020
APIC_VERSION equ 0x030
APIC_TPR     equ 0x080
APIC_EOI     equ 0x0B0
APIC_SVR     equ 0x0F0
APIC_ICR_LOW equ 0x300
APIC_ICR_HI  equ 0x310

; Endereço físico base do APIC (fixo na arquitetura x86)
APIC_BASE    equ 0xFEE00000

section .bss
align 4096
apic_mapped: resb 4096

section .text
global apic_detect
global apic_inicializar
global apic_eoi

; ==========================================
; DETECTAR SE APIC EXISTE
; ==========================================
apic_detect:
    ; Ler MSR IA32_APIC_BASE (0x1B)
    mov ecx, 0x1B
    rdmsr
    bt edx, 8           ; Bit 8 = APIC Global Enable
    jc .existe
    xor rax, rax
    ret
.existe:
    mov rax, 1
    ret

; ==========================================
; INICIALIZAR — Desligar PIC, Ligar APIC
; ==========================================
apic_inicializar:
    ; 1 — Desativar PIC herdado
    mov al, 0xFF
    out 0xA1, al
    out 0x21, al

    ; 2 — Confirmar APIC habilitado
    mov ecx, 0x1B
    rdmsr
    bts edx, 8          ; Garantir que está ligado
    wrmsr

    ; 3 — Inicializar Local APIC
    mov dword [apic_mapped + APIC_TPR], 0  ; Aceitar todas IRQs
    mov dword [apic_mapped + APIC_SVR], 0x1000 | 0xFF  ; Ligar vetor 0xFF

    ret

; ==========================================
; FIM DE INTERRUPÇÃO — Avisar APIC
; ==========================================
apic_eoi:
    mov dword [apic_mapped + APIC_EOI], 0
    ret