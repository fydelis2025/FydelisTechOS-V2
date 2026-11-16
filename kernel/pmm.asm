; ==========================================
; 🧠 PMM — Gerenciador de Memória Física
; Bitmap de páginas · 4 KiB por página
; FydelisTech OS v4.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64

; Configuração
PAGE_SIZE       equ 4096          ; 4 KiB
ENTRADAS_POR_BYTE equ 8           ; bits por byte do bitmap
MAX_PAGINAS     equ 262144        ; 1 GiB = 262.144 páginas de 4K
BITMAP_SIZE     equ MAX_PAGINAS / ENTRADAS_POR_BYTE  ; 32 KB

section .bss
align 4096
bitmap_base:        resb BITMAP_SIZE    ; Bitmap principal
paginas_livres:     resd 1              ; Contador de páginas livres

section .text
global pmm_inicializar
global pmm_alocar
global pmm_liberar
global pmm_contar_livres

; ==========================================
; ✅ INICIALIZAR — Marca todas as páginas como livres
; ==========================================
pmm_inicializar:
    ; Zera o bitmap → todas as páginas LIVRES
    mov     rdi, bitmap_base
    mov     rcx, BITMAP_SIZE
    xor     al, al
    rep     stosb

    ; Inicializa contador
    mov     dword [paginas_livres], MAX_PAGINAS
    ret

; ==========================================
; ✅ ALOCAR PÁGINA FÍSICA
; Saída: rax = endereço físico (alinhado a 4K) ou 0 = sem memória
; ==========================================
pmm_alocar:
    mov     rcx, MAX_PAGINAS / ENTRADAS_POR_BYTE  ; percorre bytes do bitmap
    mov     rdi, bitmap_base

.procurar_byte:
    cmp     rcx, 0
    je      .sem_memoria

    ; Se byte = 0xFF → todos os bits ocupados → pula
    cmp     byte [rdi], 0xFF
    jne     .encontrado

    inc     rdi
    dec     rcx
    jmp     .procurar_byte

.encontrado:
    ; Encontra o primeiro bit = 0 dentro do byte
    movzx   rax, byte [rdi]
    not     rax                 ; inverte: 1 = livre
    bsf     rdx, rax            ; rdx = posição do primeiro bit livre

    ; Marca como ocupado → seta o bit
    bts     [rdi], rdx

    ; Calcula índice da página:
    ;   ( (rdi - bitmap_base) × 8 ) + rdx
    mov     rax, rdi
    sub     rax, bitmap_base
    shl     rax, 3              ; × 8 bits
    add     rax, rdx            ; + bit dentro do byte

    ; Converte índice → endereço físico: × 4096 bytes
    shl     rax, 12             ; × PAGE_SIZE

    ; Decrementa contador
    dec     dword [paginas_livres]
    ret

.sem_memoria:
    xor     rax, rax
    ret

; ==========================================
; ✅ LIBERAR PÁGINA
; Entrada: rdi = endereço físico da página
; ==========================================
pmm_liberar:
    ; Validação: endereço alinhado?
    mov     rax, rdi
    test    rax, PAGE_SIZE - 1
    jnz     .fim_invalido

    ; Converte endereço → índice da página
    shr     rax, 12             ; ÷ PAGE_SIZE

    ; Calcula posição no bitmap
    mov     rdx, rax
    and     rdx, 7              ; bit dentro do byte
    shr     rax, 3              ; ÷ 8 → índice do byte
    add     rax, bitmap_base    ; ponteiro para o byte

    ; Marca como livre
    btr     [rax], rdx

    ; Incrementa contador
    inc     dword [paginas_livres]

.fim_invalido:
    ret

; ==========================================
; ✅ RETORNAR QUANTIDADE DE PÁGINAS LIVRES
; Saída: eax = número de páginas livres
; ==========================================
pmm_contar_livres:
    mov     eax, [paginas_livres]
    ret
    
section .data
global mem_total
global mem_livre
mem_total: dq 0
mem_livre: dq 0
