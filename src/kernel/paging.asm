; ==========================================
; PAGING — FYDELIS TECH OS
; Ativação de CR3 — Isola Kernel de Processos
; ==========================================
bits 64

section .bss
align 4096
pml4:   resb 4096
pdpt:   resb 4096
pdt:    resb 4096

section .text
global paging_init
global paging_carregar

paging_init:
    ; Limpar tabelas
    mov rdi, pml4
    mov rcx, 512
    xor rax, rax
    rep stosq

    ; Obter endereço de pdpt em rax para evitar erro de relocação/operando
    mov rax, pdpt
    or rax, 3                   ; Presente + Leitura/Escrita
    mov qword [pml4], rax       ; PML4[0] → aponta para PDPT

    ; PML4[511] → Recursiva aponta para pml4
    mov rax, pml4
    or rax, 3
    mov qword [pml4 + 511*8], rax

    ; Obter endereço de pdt em rax
    mov rax, pdt
    or rax, 3
    mov qword [pdpt], rax       ; PDPT[0] → aponta para PDT

    ; Mapear os primeiros 2GB (identidade)
    mov rcx, 512 * 2
    mov rdi, pdt
    mov rax, 0x83               ; 2MB Page + Presente + RW
.map_loop:
    mov [rdi], rax
    add rax, 0x200000
    add rdi, 8
    dec rcx
    jnz .map_loop

    ; Carregar CR3 usando registrador
    mov rax, pml4
    mov cr3, rax

    ; Ativar paginação em CR0 e CR4
    mov rax, cr4
    or rax, 0x10                ; PAE
    mov cr4, rax

    mov rax, cr0
    or rax, 0x80000000          ; PG
    mov cr0, rax

    ret

paging_carregar:
    mov cr3, rdi
    ret
