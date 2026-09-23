; ==========================================
; INTERRUPTS.ASM — APIC / IOAPIC · VERSÃO LIMPA
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; ==========================================
; REGISTROS DO LOCAL APIC (MMIO)
; ==========================================
APIC_BASE_PHYS  equ 0xFEE00000    ; Endereço fixo na arquitetura x86
APIC_ID         equ 0x020         ; Registrador de ID
APIC_VERSION    equ 0x030         ; Versão
APIC_TPR        equ 0x080         ; Filtro de Prioridade
APIC_EOI        equ 0x0B0         ; Fim de Interrupção
APIC_SVR        equ 0x0F0         ; Vetor de Serviço Spurious
APIC_ICR_LOW    equ 0x300         ; Comando de Interrupção (baixo)
APIC_ICR_HI     equ 0x310         ; Comando de Interrupção (alto)

; ==========================================
; REGISTROS DO IOAPIC (mapeamento de IRQs)
; ==========================================
IOAPIC_BASE_PHYS  equ 0xFEC00000  ; Endereço padrão do IOAPIC
IOAPIC_REG_SELECT equ 0x00
IOAPIC_REG_WINDOW equ 0x10

; Vetores de interrupção (32 a 255 disponíveis)
IRQ_BASE          equ 32          ; IRQ0 → vetor 32, IRQ1 → 33...

section .bss
align 4096
apic_virtual:   resb 4096         ; Endereço virtual do APIC
ioapic_virtual: resb 4096         ; Endereço virtual do IOAPIC
apic_disponivel: resd 1
ioapic_disponivel: resd 1

section .text
global interrupts_init
global apic_eoi
global irq_mascarar
global irq_desmascarar
global apic_is_disponivel
global keyboard_handler

; ==========================================
; 🧪 DETECTAR APIC NA CPU
; ==========================================
apic_is_disponivel:
    mov ecx, 0x1B                    ; MSR: IA32_APIC_BASE
    rdmsr
    bt edx, 8                        ; Bit 8 = APIC Global Enable
    jc .sim
    xor rax, rax
    ret
.sim:
    mov rax, 1
    ret

; ==========================================
; ⚡ INICIALIZAR SISTEMA DE INTERRUPÇÕES
; Desliga PIC → Habilita APIC + IOAPIC
; ==========================================
interrupts_init:
    ; 1️⃣ Desligar COMPLETAMENTE o PIC legado
    mov al, 0xFF
    out 0xA1, al                     ; Mascara todas IRQs Slave
    out 0x21, al                     ; Mascara todas IRQs Master

    ; 2️⃣ Verificar se APIC existe
    call apic_is_disponivel
    test rax, rax
    jz .sem_apic

    mov dword [apic_disponivel], 1

    ; 3️⃣ Habilitar APIC no MSR
    mov ecx, 0x1B
    rdmsr
    bts edx, 8                       ; Garantir APIC Global Enable = 1
    wrmsr

    ; 4️⃣ Mapear e inicializar Local APIC
    mov rax, APIC_BASE_PHYS
    mov [apic_virtual], rax

    ; Reset TPR → aceitar todas interrupções
    mov rdi, [apic_virtual]
    mov dword [rdi + APIC_TPR], 0

    ; Habilitar APIC (SVR = vetor 0xFF + bit 8 ligado)
    mov dword [rdi + APIC_SVR], 0x1000 | 0xFF

    ; 5️⃣ Detectar e inicializar IOAPIC
    mov rax, IOAPIC_BASE_PHYS
    mov [ioapic_virtual], rax
    mov dword [ioapic_disponivel], 1

    ; Redirecionar IRQs 0-15 para vetores 32-47
    mov rcx, 0
.config_irq:
    mov rdi, [ioapic_virtual]
    mov rax, rcx
    add rax, IRQ_BASE                ; Vetor destino

    mov rdx, rax
    and rdx, 0xFF                    ; Apenas o vetor
    mov rsi, rcx
    shl rsi, 1                       ; Cada IRQ tem 2 registradores

    ; Escrever parte baixa
    mov dword [rdi + IOAPIC_REG_SELECT], esi
    mov dword [rdi + IOAPIC_REG_WINDOW], edx

    ; Parte alta = 0 (CPU 0)
    inc esi
    mov dword [rdi + IOAPIC_REG_SELECT], esi
    mov dword [rdi + IOAPIC_REG_WINDOW], 0

    inc rcx
    cmp rcx, 16
    jl .config_irq

    ; ✅ Desmascarar explicitamente a IRQ 1 (Teclado) no IOAPIC
    mov rdi, 1
    call irq_desmascarar

    jmp .concluido

.sem_apic:
    mov dword [apic_disponivel], 0
    mov dword [ioapic_disponivel], 0
    call pic_remap_legacy

.concluido:
    sti                              ; ✅ Habilitar interrupções
    ret

; ==========================================
; ⌨️ TRATADOR DE INTERRUPÇÃO DO TECLADO (Simplificado)
; ==========================================
keyboard_handler:
    push rax
    push rdx

    ; Envia o sinal de Fim de Interrupção ao APIC
    call apic_eoi

    pop rdx
    pop rax
    iretq

; ==========================================
; ✅ FIM DE INTERRUPÇÃO (EOI)
; ==========================================
apic_eoi:
    cmp dword [apic_disponivel], 0
    je .pic_eoi

    mov rdi, [apic_virtual]
    mov dword [rdi + APIC_EOI], 0
    ret

.pic_eoi:
    push rax
    mov al, 0x20
    out 0x20, al
    pop rax
    ret

; ==========================================
; 🔒 MASCARAR IRQ
; ==========================================
irq_mascarar:
    cmp dword [ioapic_disponivel], 0
    je .pic_mask

    mov rsi, rdi
    shl rsi, 1
    add rsi, 1
    mov rdi, [ioapic_virtual]
    mov dword [rdi + IOAPIC_REG_SELECT], esi
    mov eax, [rdi + IOAPIC_REG_WINDOW]
    bts eax, 0
    mov dword [rdi + IOAPIC_REG_WINDOW], eax
    ret

.pic_mask:
    push rax
    mov rcx, rdi
    cmp rcx, 8
    jb .master
    sub rcx, 8
    in al, 0xA1
    bts eax, ecx
    out 0xA1, al
    jmp .fim
.master:
    in al, 0x21
    bts eax, ecx
    out 0x21, al
.fim:
    pop rax
    ret

; ==========================================
; 🔓 DESMASCARAR IRQ
; ==========================================
irq_desmascarar:
    cmp dword [ioapic_disponivel], 0
    je .pic_unmask

    mov rsi, rdi
    shl rsi, 1
    add rsi, 1
    mov rdi, [ioapic_virtual]
    mov dword [rdi + IOAPIC_REG_SELECT], esi
    mov eax, [rdi + IOAPIC_REG_WINDOW]
    btr eax, 0
    mov dword [rdi + IOAPIC_REG_WINDOW], eax
    ret

.pic_unmask:
    push rax
    mov rcx, rdi
    cmp rcx, 8
    jb .master
    sub rcx, 8
    in al, 0xA1
    btr eax, ecx
    out 0xA1, al
    jmp .fim
.master:
    in al, 0x21
    btr eax, ecx
    out 0x21, al
.fim:
    pop rax
    ret

; ==========================================
; ⚠️ FALLBACK — PIC LEGADO
; ==========================================
pic_remap_legacy:
    push rax
    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    mov al, 32
    out 0x21, al
    mov al, 40
    out 0xA1, al

    mov al, 4
    out 0x21, al
    mov al, 2
    out 0xA1, al

    mov al, 1
    out 0x21, al
    out 0xA1, al

    mov al, 0xFF
    out 0xA1, al
    out 0x21, al

    pop rax
    ret
