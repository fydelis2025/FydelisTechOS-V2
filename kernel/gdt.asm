; ==========================================
; GDT & TSS — FYDELISTECH OS (x86_64 Long Mode)
; Ring 0 = Kernel | Ring 3 = Usuario
; ==========================================
bits 64
default rel

DEFAULT_RSP0 equ 0x90000            ; Pilha padrao de Ring 0 para transicoes Ring 3 -> Ring 0

section .text
global gdt_init
global gdt_flush
global tss_set_rsp0

; ==========================================
; INICIALIZACAO DA GDT + TSS
; ==========================================
gdt_init:
    ; 1. Zera toda a TSS (104 bytes) e define RSP0 inicial e IOPB
    lea rdi, [rel tss64]
    xor eax, eax
    mov ecx, 104 / 4
    rep stosd

    mov qword [rel tss64 + 4], DEFAULT_RSP0     ; RSP0 padrao
    mov word  [rel tss64 + 102], 104            ; Offset I/O Permission Bitmap (sem mapa)

    ; 2. Preenche endereco base da TSS (64 bits) na entrada 5 da GDT (offset 0x28)
    lea rax, [rel tss64]
    lea rdx, [rel gdt_tss]

    mov word [rdx + 2], ax          ; Base [15:0]
    shr rax, 16
    mov byte [rdx + 4], al          ; Base [23:16]
    mov byte [rdx + 5], 0x89        ; Garante tipo 64-bit TSS Available (nao Busy)
    mov byte [rdx + 7], ah          ; Base [31:24]
    shr rax, 16
    mov dword [rdx + 8], eax        ; Base [63:32]
    mov dword [rdx + 12], 0         ; Reservado

    ; 3. Preenche endereco base linear da GDT no descritor (RIP-relative seguro)
    lea rax, [rel gdt]
    mov qword [rel gdt_descriptor + 2], rax

    lgdt [rel gdt_descriptor]
    call gdt_flush

    ; 4. Carrega Task Register (seletor 0x28 = indice 5 * 8)
    mov ax, 0x28
    ltr ax
    ret

gdt_flush:
    mov ax, 0x10                    ; Seletor Kernel Data (indice 2 * 8)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    lea rax, [rel .flush]
    push qword 0x08                 ; Seletor Kernel Code (indice 1 * 8)
    push rax
    retfq                           ; Far return de 64 bits (RETFQ)
.flush:
    ret

; Atualiza pilha de Ring 0 usada quando ocorre IRQ em Ring 3
; RDI = novo RSP0
tss_set_rsp0:
    mov [rel tss64 + 4], rdi
    ret

; ==========================================
; ESTRUTURAS DA GDT E TSS (Alinhadas em 16 bytes)
; ==========================================
section .data
align 16
gdt:
    dq 0x0000000000000000           ; 0x00 (0) — Nulo
    dq 0x00AF9A000000FFFF           ; 0x08 (1) — Kernel Code 64-bit (Ring 0)
    dq 0x00AF92000000FFFF           ; 0x10 (2) — Kernel Data 64-bit (Ring 0)
    dq 0x00AFF2000000FFFF           ; 0x18 (3) — User Data   64-bit (Ring 3)
    dq 0x00AFFA000000FFFF           ; 0x20 (4) — User Code   64-bit (Ring 3)
gdt_tss:                            ; 0x28 (5 e 6) — Descritor TSS 64-bit (16 bytes)
    dw 103                          ; Limite (sizeof(tss64) - 1 = 103)
    dw 0                            ; Base [15:0] (preenchido no gdt_init)
    db 0                            ; Base [23:16]
    db 0x89                         ; Tipo: 64-bit TSS Available (Presente, Ring 0)
    db 0x00                         ; Flags / Limite [19:16]
    db 0                            ; Base [31:24]
    dd 0                            ; Base [63:32]
    dd 0                            ; Reservado
gdt_fim:

align 16
gdt_descriptor:
    dw gdt_fim - gdt - 1            ; Limite da GDT
    dq 0                            ; Base linear 64-bit (preenchida no gdt_init)

section .bss
align 16
tss64:
    resb 104                        ; Estrutura TSS x86_64 padrao (104 bytes)
