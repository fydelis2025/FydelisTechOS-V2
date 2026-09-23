; ==========================================
; HEAP.ASM — Buddy Allocator
; Alocação Dinâmica de Memória
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; Configuração do Heap
HEAP_INICIO    equ 0xFFFF800000000000   ; Início do espaço de heap
HEAP_TAMANHO   equ 1024 * 1024 * 512     ; 512 MB
HEAP_MIN_BLCOK equ 4096                  ; Mínimo 4KB
HEAP_MAX_ORDER equ 17                    ; 2^17 × 4KB = 512MB

; Estrutura de nó da árvore
BITMAP_TAMANHO equ (1 << (HEAP_MAX_ORDER + 1)) / 8

section .bss
align 8
buddy_bitmap:   resb BITMAP_TAMANHO
heap_livre:     resq 1
heap_inicializado: resb 1

section .text
global heap_inicializar
global heap_alocar
global heap_liberar
global heap_disponivel

; ==========================================
; INICIALIZAR O ALOCADOR
; ==========================================
heap_inicializar:
    cmp byte [heap_inicializado], 1
    je .feito

    ; Marcar todos os blocos como livres
    mov rdi, buddy_bitmap
    mov rcx, BITMAP_TAMANHO
    mov al, 0
    rep stosb

    mov qword [heap_livre], HEAP_TAMANHO
    mov byte [heap_inicializado], 1
.feito:
    ret

; ==========================================
; CALCULAR ORDEM (2^order × blk_size)
; ==========================================
calcular_ordem:
    ; rdi = tamanho solicitado
    mov rax, HEAP_MIN_BLCOK
    mov rcx, 0
.loop:
    cmp rax, rdi
    jae .pronto
    shl rax, 1
    inc rcx
    cmp rcx, HEAP_MAX_ORDER
    jbe .loop
.pronto:
    mov rax, rcx
    ret

; ==========================================
; ENCONTRAR BLOCO LIVRE
; ==========================================
encontrar_bloco:
    ; rdi = ordem
    mov rsi, rdi
    mov rdx, 1
    shl rdx, rsi              ; Número de blocos nesta ordem
    mov rcx, 0
.procurar:
    ; Verificar se bloco está livre
    mov rbx, rcx
    add rbx, (1 << rsi) - 1
    bts [buddy_bitmap], rbx
    jc .ocupado
    ; Encontrado — retornar índice
    mov rax, rcx
    ret
.ocupado:
    inc rcx
    cmp rcx, rdx
    jb .procurar
    ; Não encontrou
    xor rax, rax
    ret

; ==========================================
; ALocar — retorna endereço ou 0 se falhar
; ==========================================
heap_alocar:
    ; rdi = tamanho em bytes
    push rbp
    push rbx
    push r12
    push r13

    ; Ajustar tamanho mínimo
    cmp rdi, HEAP_MIN_BLCOK
    jae .tamanho_ok
    mov rdi, HEAP_MIN_BLCOK
.tamanho_ok:

    ; Calcular ordem necessária
    call calcular_ordem
    mov rbp, rax              ; rbp = ordem

    ; Procurar bloco
    mov rdi, rbp
    call encontrar_bloco
    test rax, rax
    jz .falha

    mov r12, rax              ; r12 = índice do bloco

    ; Calcular endereço físico
    mov rax, 1
    shl rax, rbp
    mov rcx, HEAP_MIN_BLCOK
    mul rcx
    mul r12
    add rax, HEAP_INICIO
    mov r13, rax              ; r13 = endereço

    ; Marcar como ocupado e dividir até a ordem
    mov rdi, r12
    mov rsi, rbp
    call marcar_ocupado

    ; Atualizar contador
    mov rax, 1
    shl rax, rbp
    mul rcx
    sub qword [heap_livre], rax

    mov rax, r13              ; Retornar endereço
    jmp .fim

.falha:
    xor rax, rax

.fim:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ==========================================
; LIBERAR BLOCO
; ==========================================
heap_liberar:
    ; rdi = endereço
    push rbp
    push rbx
    push r12

    ; Verificar endereço válido
    cmp rdi, HEAP_INICIO
    jb .invalido
    cmp rdi, HEAP_INICIO + HEAP_TAMANHO
    jae .invalido

    ; Calcular índice e ordem
    mov rax, rdi
    sub rax, HEAP_INICIO
    xor rdx, rdx
    mov rcx, HEAP_MIN_BLCOK
    div rcx
    mov rbx, rax              ; Índice base

    ; Descobrir ordem real (do menor bloco que contém)
    mov rbp, 0
.ordem_loop:
    mov rcx, 1
    shl rcx, rbp
    and rax, rcx
    jz .achou
    inc rbp
    cmp rbp, HEAP_MAX_ORDER
    jbe .ordem_loop
.achou:

    ; Marcar livre e fundir com o parceiro
    mov rdi, rbx
    mov rsi, rbp
    call marcar_livre_e_fundir

    ; Atualizar contador
    mov rax, 1
    shl rax, rbp
    mov rcx, HEAP_MIN_BLCOK
    mul rcx
    add qword [heap_livre], rax

.invalido:
    pop r12
    pop rbx
    pop rbp
    ret

; ==========================================
; FUNÇÕES AUXILIARES INTERNAS
; ==========================================
marcar_ocupado:
    ; rdi = índice, rsi = ordem
    mov rcx, rsi
    mov rax, rdi
    mov rdx, 1
    shl rdx, rcx
    add rax, rdx
    dec rax
    bts [buddy_bitmap], rax
    ; Propagar para cima se necessário
    ret

marcar_livre_e_fundir:
    ; rdi = índice, rsi = ordem
    mov rcx, rsi
.fundir_loop:
    mov rdx, rdi
    xor rdx, 1                ; Parceiro = índice ^ 1
    mov rax, rdx
    mov r8, 1
    shl r8, rcx
    add rax, r8
    dec rax
    bt [buddy_bitmap], rax
    jc .nao_livre

    ; Ambos livres — fundir
    mov rax, rdi
    and rax, ~1
    mov rdi, rax
    inc rcx
    cmp rcx, HEAP_MAX_ORDER
    jbe .fundir_loop

.nao_livre:
    ret

; ==========================================
; RETORNAR ESPAÇO LIVRE
; ==========================================
heap_disponivel:
    mov rax, [heap_livre]
    ret