; ==========================================
; PMM — Gerenciador de Memória Física
; Bitmap de páginas livres/ocupadas
; ==========================================
bits 64

section .bss
align 4096
bitmap_base:    resb 1048576   ; 1GB = 32768 entradas
paginas_livres: resd 1

section .text
global pmm_inicializar
global pmm_alocar
global pmm_liberar

pmm_inicializar:
    ; Marcar todas como livres
    mov rdi, bitmap_base
    mov rcx, 1048576 / 8
    mov al, 0xFF
    rep stosb
    mov dword [paginas_livres], 0
    ret

pmm_alocar:
    ; Procurar primeiro bit livre
    mov rcx, 1048576
    mov rdi, bitmap_base
    xor rax, rax
.procurar:
    cmp byte [rdi], 0xFF
    jne .encontrado
    inc rdi
    sub rcx, 8
    jg .procurar
    xor rax, rax
    ret
.encontrado:
    mov rdx, -1
    bsf rdx, [rdi]
    btr [rdi], rdx
    mov rax, rdi
    sub rax, bitmap_base
    shl rax, 3
    add rax, rdx
    shl rax, 12        ; × 4096 bytes
    dec dword [paginas_livres]
    ret

pmm_liberar:
    ; rdi = endereço físico
    mov rax, rdi
    shr rax, 12
    mov rdx, rax
    and rdx, 7
    shr rax, 3
    add rax, bitmap_base
    bts [rax], rdx
    inc dword [paginas_livres]
    ret