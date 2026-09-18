; ==========================================
; FYDELIS TECH OS — interrupts.asm
; Controlador de Interrupções (PIC/APIC)
; De Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; Portas do controlador PIC
PIC_MASTER_CMD  equ 0x20
PIC_MASTER_DATA equ 0x21
PIC_SLAVE_CMD   equ 0xA0
PIC_SLAVE_DATA  equ 0xA1

section .text
global idt_init
global pic_remap
global irq_eoi

; ==========================================
; 🔄 REPOSICIONAR IRQs (Evitar conflitos com exceções)
; ==========================================
pic_remap:
    push rax

    ; Salvar máscaras atuais
    in al, PIC_MASTER_DATA
    mov ah, al
    in al, PIC_SLAVE_DATA
    mov bh, al

    ; Enviar comando de reinicialização
    mov al, 0x11
    out PIC_MASTER_CMD, al
    out PIC_SLAVE_CMD, al

    ; Definir vetores: IRQ0 → 32, IRQ8 → 40
    mov al, 32
    out PIC_MASTER_DATA, al
    mov al, 40
    out PIC_SLAVE_DATA, al

    ; Ligação: Slave na porta 2 do Master
    mov al, 4
    out PIC_MASTER_DATA, al
    mov al, 2
    out PIC_SLAVE_DATA, al

    ; Modo 8086
    mov al, 1
    out PIC_MASTER_DATA, al
    out PIC_SLAVE_DATA, al

    ; Restaurar máscaras
    mov al, ah
    out PIC_MASTER_DATA, al
    mov al, bh
    out PIC_SLAVE_DATA, al

    pop rax
    ret

; ==========================================
; ✅ FIM DE INTERRUPÇÃO (Avisar PIC que terminou)
; ==========================================
irq_eoi:
    push rax
    cmp al, 8           ; IRQ 8-15 = mandar EOI para os dois
    jb .master_only
    mov al, 0x20
    out PIC_SLAVE_CMD, al
.master_only:
    mov al, 0x20
    out PIC_MASTER_CMD, al
    pop rax
    ret

; ==========================================
; 📋 INICIALIZAR TABELA DE INTERRUPÇÕES
; ==========================================
idt_init:
    ; Carregar IDT configurada pelo bootloader/kernel
    lidt [idt_ptr]
    sti                 ; Habilitar interrupções
    ret

section .rodata
idt_ptr:
    dw 256 * 16 - 1     ; Limite: 256 descritores × 16 bytes
    dq 0                ; Endereço base (preenchido pelo C ou bootloader); ==========================================
; FYDELIS TECH OS — interrupts.asm
; Controlador de Interrupções (PIC/APIC)
; De Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; Portas do controlador PIC
PIC_MASTER_CMD  equ 0x20
PIC_MASTER_DATA equ 0x21
PIC_SLAVE_CMD   equ 0xA0
PIC_SLAVE_DATA  equ 0xA1

section .text
global idt_init
global pic_remap
global irq_eoi

; ==========================================
; 🔄 REPOSICIONAR IRQs (Evitar conflitos com exceções)
; ==========================================
pic_remap:
    push rax

    ; Salvar máscaras atuais
    in al, PIC_MASTER_DATA
    mov ah, al
    in al, PIC_SLAVE_DATA
    mov bh, al

    ; Enviar comando de reinicialização
    mov al, 0x11
    out PIC_MASTER_CMD, al
    out PIC_SLAVE_CMD, al

    ; Definir vetores: IRQ0 → 32, IRQ8 → 40
    mov al, 32
    out PIC_MASTER_DATA, al
    mov al, 40
    out PIC_SLAVE_DATA, al

    ; Ligação: Slave na porta 2 do Master
    mov al, 4
    out PIC_MASTER_DATA, al
    mov al, 2
    out PIC_SLAVE_DATA, al

    ; Modo 8086
    mov al, 1
    out PIC_MASTER_DATA, al
    out PIC_SLAVE_DATA, al

    ; Restaurar máscaras
    mov al, ah
    out PIC_MASTER_DATA, al
    mov al, bh
    out PIC_SLAVE_DATA, al

    pop rax
    ret

; ==========================================
; ✅ FIM DE INTERRUPÇÃO (Avisar PIC que terminou)
; ==========================================
irq_eoi:
    push rax
    cmp al, 8           ; IRQ 8-15 = mandar EOI para os dois
    jb .master_only
    mov al, 0x20
    out PIC_SLAVE_CMD, al
.master_only:
    mov al, 0x20
    out PIC_MASTER_CMD, al
    pop rax
    ret

; ==========================================
; 📋 INICIALIZAR TABELA DE INTERRUPÇÕES
; ==========================================
idt_init:
    ; Carregar IDT configurada pelo bootloader/kernel
    lidt [idt_ptr]
    sti                 ; Habilitar interrupções
    ret

section .rodata
idt_ptr:
    dw 256 * 16 - 1     ; Limite: 256 descritores × 16 bytes
    dq 0                ; Endereço base (preenchido pelo C ou bootloader)