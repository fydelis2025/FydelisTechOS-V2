; ==========================================
; 📄 PAGING — FydelisTech OS v4.2
; Mapeamento de Identidade + Recursiva
; Integrado com PMM (Gerenciador de Memória Física)
; Salvador • Bahia 🇧🇷
; ==========================================
BITS 64

PAGE_SIZE       equ 4096
PAGE_2MB        equ 0x200000

FLAG_PRESENT    equ 1 << 0
FLAG_RW         equ 1 << 1
FLAG_USER       equ 1 << 2
FLAG_PS         equ 1 << 7

extern pmm_alocar
extern pmm_liberar

section .bss
align 4096
global pml4
global pdpt
global pdt

pml4:   resb PAGE_SIZE
pdpt:   resb PAGE_SIZE
pdt:    resb PAGE_SIZE

section .text
global paging_init
global paging_carregar
global paging_ativo
global paging_mapear
global paging_desmapear

paging_init:
    push    rbx
    push    rbp

    ; Limpar tabelas
    mov     rdi, pml4
    mov     rcx, 512
    xor     rax, rax
    rep     stosq

    mov     rdi, pdpt
    mov     rcx, 512
    xor     rax, rax
    rep     stosq

    mov     rdi, pdt
    mov     rcx, 512
    xor     rax, rax
    rep     stosq

    ; PML4[0] → PDPT
    lea     rax, [rel pdpt]
    or      rax, FLAG_PRESENT | FLAG_RW
    lea     rbx, [rel pml4]
    mov     qword [rbx], rax

    ; PML4[511] → Entrada recursiva
    lea     rax, [rel pml4]
    or      rax, FLAG_PRESENT | FLAG_RW
    mov     qword [rbx + 511 * 8], rax

    ; PDPT[0] → PDT
    lea     rax, [rel pdt]
    or      rax, FLAG_PRESENT | FLAG_RW
    lea     rbx, [rel pdpt]
    mov     qword [rbx], rax

    ; Mapear 2GB em páginas de 2MB (identidade)
    lea     rdi, [rel pdt]
    mov     rcx, 1024
    mov     rax, FLAG_PRESENT | FLAG_RW | FLAG_PS

.map_2mb:
    mov     qword [rdi], rax
    add     rax, PAGE_2MB
    add     rdi, 8
    dec     rcx
    jnz     .map_2mb

    ; Ativar paginação
    lea     rax, [rel pml4]
    mov     cr3, rax

    mov     rax, cr4
    or      rax, 1 << 5
    mov     cr4, rax

    mov     rax, cr0
    or      rax, 1 << 31
    mov     cr0, rax

    pop     rbp
    pop     rbx
    ret

paging_carregar:
    mov     cr3, rdi
    ret

; ==========================================
; ✅ MAPEAR PÁGINA — Dinâmico (usando PMM)
; Entrada: rdi = endereço virtual
;          rsi = endereço físico
;          rdx = flags
; ==========================================
paging_mapear:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14

    mov     r12, rdi        ; Virt
    mov     r13, rsi        ; Phys
    mov     r14, rdx        ; Flags

    ; Extrair índices
    mov     rax, r12
    shr     rax, 39
    and     rax, 0x1FF
    mov     r8, rax         ; índice PML4

    mov     rax, r12
    shr     rax, 30
    and     rax, 0x1FF
    mov     r9, rax         ; índice PDPT

    mov     rax, r12
    shr     rax, 21
    and     rax, 0x1FF
    mov     r10, rax        ; índice PDT

    mov     rax, r12
    shr     rax, 12
    and     rax, 0x1FF
    mov     r11, rax        ; índice PTE

    ; --- 1. PML4 -> PDPT ---
    lea     rax, [rel pml4]
    mov     rbx, qword [rax + r8 * 8]
    test    rbx, FLAG_PRESENT
    jnz     .tem_pdpt

.criar_pdpt:
    call    pmm_alocar
    test    rax, rax
    jz      .erro
    mov     rbx, rax
    or      rbx, FLAG_PRESENT | FLAG_RW | FLAG_USER
    lea     rdx, [rel pml4]
    mov     qword [rdx + r8 * 8], rbx

.tem_pdpt:
    and     rbx, -4096      ; rbx = endereço físico da tabela PDPT
    mov     rcx, rbx
    mov     rax, r9
    shl     rax, 3
    add     rcx, rax        ; rcx aponta para PDPT[r9]
    mov     rbx, qword [rcx]
    test    rbx, FLAG_PRESENT
    jnz     .tem_pdt

.criar_pdt:
    push    rcx             ; Salva ponteiro da entrada PDPT
    call    pmm_alocar
    pop     rcx
    test    rax, rax
    jz      .erro
    mov     rbx, rax
    or      rbx, FLAG_PRESENT | FLAG_RW | FLAG_USER
    mov     qword [rcx], rbx

.tem_pdt:
    and     rbx, -4096      ; rbx = endereço físico da tabela PDT
    mov     rcx, rbx
    mov     rax, r10
    shl     rax, 3
    add     rcx, rax        ; rcx aponta para PDT[r10]
    mov     rbx, qword [rcx]
    test    rbx, FLAG_PRESENT
    jnz     .tem_pte

.criar_pte:
    push    rcx             ; Salva ponteiro da entrada PDT
    call    pmm_alocar
    pop     rcx
    test    rax, rax
    jz      .erro
    mov     rbx, rax
    or      rbx, FLAG_PRESENT | FLAG_RW | FLAG_USER
    mov     qword [rcx], rbx

.tem_pte:
    and     rbx, -4096      ; rbx = endereço físico da tabela PTE
    mov     rcx, rbx
    mov     rax, r11
    shl     rax, 3
    add     rcx, rax        ; rcx aponta para PTE[r11]
    
    mov     rax, r13
    or      rax, r14
    mov     qword [rcx], rax

    mov     rax, 1          ; Sucesso
    jmp     .fim

.erro:
    xor     rax, rax

.fim:
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

paging_desmapear:
    mov     rax, rdi
    invlpg  [rax]
    ret

paging_ativo:
    mov     rax, cr0
    test    rax, 1 << 31
    jz      .nao
    mov     rax, 1
    ret
.nao:
    xor     rax, rax
    ret
