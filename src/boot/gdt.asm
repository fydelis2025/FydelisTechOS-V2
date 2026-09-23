; ==========================================
; GDT — FYDELIS TECH OS
; Ring 0 = Kernel | Ring 3 = Usuário
; ==========================================
bits 64
default rel

section .text
global gdt_init
global gdt_flush

; ==========================================
; INICIALIZAÇÃO DA GDT
; ==========================================
gdt_init:
    lgdt [rel gdt_descriptor]
    ret

gdt_flush:
    ; Recarregar registradores de segmento
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    lea rax, [rel .flush]
    push 0x08               ; Seletor de Código do Kernel (Ring 0)
    push rax
    retf                    ; Far return para atualizar o CS
.flush:
    ret

; ==========================================
; ESTRUTURAS DA GDT (Alinhadas na seção de dados)
; ==========================================
section .data
align 16
gdt:
    dq 0x0000000000000000       ; 0 — Nulo
    dq 0x00AF9A000000FFFF       ; 1 — Kernel Code  (Ring 0)
    dq 0x00CF92000000FFFF       ; 2 — Kernel Data  (Ring 0)
    dq 0x00AFFA000000FFFF       ; 3 — User Code    (Ring 3)
    dq 0x00CFF2000000FFFF       ; 4 — User Data    (Ring 3)
gdt_fim:

align 16
gdt_descriptor:
    dw gdt_fim - gdt - 1        ; Limite da GDT (2 bytes)
    dq gdt                      ; Endereço base de 64 bits (8 bytes)
