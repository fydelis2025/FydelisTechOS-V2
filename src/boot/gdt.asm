; ==========================================
; GDT — FYDELIS TECH OS
; Ring 0 = Kernel | Ring 3 = Usuário
; ==========================================
bits 64

section .text
global gdt_init
global gdt_flush

; Descritor: Limite(16) | Base(24) | Flags | Limite(4) | Attr | Base(8)
gdt:
    dq 0x0000000000000000       ; 0 — Nulo
    dq 0x00AF9A000000FFFF       ; 1 — Kernel Code  (Ring 0)
    dq 0x00CF92000000FFFF       ; 2 — Kernel Data  (Ring 0)
    dq 0x00AFFA000000FFFF       ; 3 — User Code    (Ring 3)
    dq 0x00CFF2000000FFFF       ; 4 — User Data    (Ring 3)
gdt_fim:

gdt_ptr:
    dw gdt_fim - gdt - 1        ; Limite
    dq gdt                       ; Endereço

gdt_init:
    lgdt [gdt_ptr]
    ret

gdt_flush:
    ; Recarregar registradores de segmento
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:.flush
.flush:
    ret