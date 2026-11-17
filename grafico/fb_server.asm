; ==========================================
; FB_SERVER.ASM — COMPOSITOR NO KERNEL  (VERSÃO CORRIGIDA FINAL)
; Gerenciador de Janelas · Cursor sem Rastro · Desempenho Otimizado
; FydelisTech OS v4.2 · Salvador • Bahia
; ==========================================
BITS 64
default rel

extern fb_base
extern fb_largura
extern fb_altura
extern fb_pitch
extern fb_preencher_retangulo
extern mouse_ler_posicao

MAX_JANELAS      equ 16
TAM_CURSOR       equ 16

struc Janela
    .x:          resd 1
    .y:          resd 1
    .largura:    resd 1
    .altura:     resd 1
    .cor_fundo:  resd 1
    .visivel:    resb 1
    .pad:        resb 3
    .titulo:     resq 1
endstruc

section .rodata
align 8
; Sprite 16x16 do cursor: 0=transparente, 1=borda, 2=preenchimento
cursor_sprite:
    db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,2,2,2,1,0,0,0,0,0,0,0,0,0,0,0
    db 1,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0
    db 1,2,2,2,2,2,1,0,0,0,0,0,0,0,0,0
    db 1,2,2,2,2,2,2,1,0,0,0,0,0,0,0,0
    db 1,2,2,2,2,2,2,2,1,0,0,0,0,0,0,0
    db 1,2,2,2,2,2,1,1,1,1,0,0,0,0,0,0
    db 1,2,2,1,2,2,1,0,0,0,0,0,0,0,0,0
    db 1,2,1,0,1,2,2,1,0,0,0,0,0,0,0,0
    db 1,1,0,0,1,2,2,1,0,0,0,0,0,0,0,0
    db 1,0,0,0,0,1,2,2,1,0,0,0,0,0,0,0
    db 0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

section .bss
align 64
janelas:            resb Janela_size * MAX_JANELAS
janela_ativa:       resd 1
cursor_x:           resd 1
cursor_y:           resd 1
cursor_ant_x:       resd 1
cursor_ant_y:       resd 1
cursor_salvo:       resb 1
cursor_buffer:      resd TAM_CURSOR * TAM_CURSOR
janelas_sujas:      resb 1    ; 1=precisa redesenhar janelas, 0=não

section .text
global ws_inicializar
global ws_criar_janela
global ws_desenhar_janelas
global ws_atualizar_cursor
global ws_verificar_clique
global ws_apresentar
global ws_marcar_janelas_sujas

; ==========================================
; INICIALIZAR SERVIDOR DE JANELAS
; ==========================================
ws_inicializar:
    mov     ecx, MAX_JANELAS * Janela_size
    lea     rdi, [janelas]
    xor     rax, rax
    rep     stosb

    mov     dword [janela_ativa], -1
    mov     dword [cursor_x], 0
    mov     dword [cursor_y], 0
    mov     byte [cursor_salvo], 0
    mov     byte [janelas_sujas], 1    ; Força primeiro desenho
    mov     rax, 1
    ret

; ==========================================
; MARCA QUE JANELAS PRECISAM SER REDESENHADAS
; ==========================================
ws_marcar_janelas_sujas:
    mov     byte [janelas_sujas], 1
    ret

; ==========================================
; CRIAR JANELA
; ==========================================
ws_criar_janela:
    push    rbx
    push    r12

    xor     rbx, rbx
    lea     r12, [janelas]

.procurar:
    cmp     rbx, MAX_JANELAS
    jge     .cheio

    cmp     byte [r12 + Janela.visivel], 0
    je      .encontrada

    add     r12, Janela_size
    inc     rbx
    jmp     .procurar

.encontrada:
    mov     [r12 + Janela.x], edi
    mov     [r12 + Janela.y], esi
    mov     [r12 + Janela.largura], edx
    mov     [r12 + Janela.altura], ecx
    mov     [r12 + Janela.cor_fundo], r8d
    mov     byte [r12 + Janela.visivel], 1
    mov     [janela_ativa], ebx

    mov     byte [janelas_sujas], 1    ; Nova janela = precisa redesenhar
    mov     rax, rbx
    pop     r12
    pop     rbx
    ret

.cheio:
    mov     rax, -1
    pop     r12
    pop     rbx
    ret

; ==========================================
; DESENHAR TODAS AS JANELAS — SÓ QUANDO PRECISAR
; ==========================================
ws_desenhar_janelas:
    cmp     byte [janelas_sujas], 0
    je      .fim    ; Nada mudou — pula o redesenho pesado

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; REMOVIDO: não restaura cursor aqui — janelas desenham primeiro

    xor     rbx, rbx
    lea     r12, [janelas]

.loop:
    cmp     rbx, MAX_JANELAS
    jge     .fim

    cmp     byte [r12 + Janela.visivel], 0
    je      .proxima

    mov     r13d, [r12 + Janela.x]
    mov     r14d, [r12 + Janela.y]
    mov     r15d, [r12 + Janela.largura]
    add     r15d, r13d
    mov     ecx, [r12 + Janela.altura]
    add     ecx, r14d

    ; Borda externa
    mov     edi, r13d
    sub     edi, 2
    mov     esi, r14d
    sub     esi, 2
    mov     edx, r15d
    add     edx, 2
    add     ecx, 2
    mov     r8d, 0xFF9D4EDD
    call    fb_preencher_retangulo

    ; Corpo da janela
    mov     edi, r13d
    mov     esi, r14d
    mov     edx, r15d
    mov     ecx, [r12 + Janela.altura]
    add     ecx, r14d
    mov     r8d, [r12 + Janela.cor_fundo]
    call    fb_preencher_retangulo

    ; Barra de título
    mov     edi, r13d
    mov     esi, r14d
    mov     edx, r15d
    mov     ecx, r14d
    add     ecx, 28
    mov     r8d, 0xFF1E0E3D
    call    fb_preencher_retangulo

.proxima:
    add     r12, Janela_size
    inc     rbx
    jmp     .loop

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx

    mov     byte [janelas_sujas], 0

    ; Depois de redesenhar janelas, restaura e redesenha o cursor por cima
    cmp     byte [cursor_salvo], 1
    jne     .fim
    call    cursor_restaurar_fundo
    call    cursor_desenhar_novo

.fim:
    ret

; --- Restaura fundo sob o cursor ---
cursor_restaurar_fundo:
    cmp     byte [cursor_salvo], 0
    je      .ret
    cmp     qword [fb_base], 0
    je      .ret

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, [cursor_ant_x]
    mov     r13d, [cursor_ant_y]
    mov     r14d, [fb_pitch]
    lea     r15, [cursor_buffer]

    xor     ebx, ebx
.lin:
    mov     eax, r13d
    add     eax, ebx
    cmp     eax, [fb_altura]
    jge     .fim_rest

    imul    rax, r14
    add     rax, [fb_base]
    lea     rdi, [rax + r12*4]

    xor     ecx, ecx
.col:
    mov     edx, r12d
    add     edx, ecx
    cmp     edx, [fb_largura]
    jge     .prox_lin

    mov     r9, rbx
    shl     r9, 6
    lea     r9, [r9 + rcx*4]
    mov     eax, [r15 + r9]
    mov     [rdi + rcx*4], eax

    inc     ecx
    cmp     ecx, TAM_CURSOR
    jl      .col

.prox_lin:
    inc     ebx
    cmp     ebx, TAM_CURSOR
    jl      .lin

.fim_rest:
    mov     byte [cursor_salvo], 0
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.ret:
    ret

; --- Salva fundo e desenha cursor ---
cursor_desenhar_novo:
    cmp     qword [fb_base], 0
    je      .ret

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, [cursor_x]
    mov     r13d, [cursor_y]
    mov     [cursor_ant_x], r12d
    mov     [cursor_ant_y], r13d
    mov     r14d, [fb_pitch]
    lea     r15, [cursor_buffer]
    lea     r8, [cursor_sprite]

    xor     ebx, ebx
.lin:
    mov     eax, r13d
    add     eax, ebx
    cmp     eax, [fb_altura]
    jge     .fim_des

    imul    rax, r14
    add     rax, [fb_base]
    lea     rdi, [rax + r12*4]

    xor     ecx, ecx
.col:
    mov     edx, r12d
    add     edx, ecx
    cmp     edx, [fb_largura]
    jge     .prox_lin

    mov     r9, rbx
    shl     r9, 6
    lea     r9, [r9 + rcx*4]
    mov     eax, [rdi + rcx*4]
    mov     [r15 + r9], eax

    mov     r10, rbx
    shl     r10, 4
    add     r10, rcx
    movzx   edx, byte [r8 + r10]

    test    edx, edx
    jz      .skip_px
    cmp     edx, 1
    je      .cor_borda
    mov     dword [rdi + rcx*4], 0xFF00F5D4
    jmp     .skip_px
.cor_borda:
    mov     dword [rdi + rcx*4], 0xFF0A0414
.skip_px:
    inc     ecx
    cmp     ecx, TAM_CURSOR
    jl      .col

.prox_lin:
    inc     ebx
    cmp     ebx, TAM_CURSOR
    jl      .lin

.fim_des:
    mov     byte [cursor_salvo], 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.ret:
    ret

; ==========================================
; ATUALIZAR CURSOR — só move, só restaura a posição antiga
; ==========================================
ws_atualizar_cursor:
    call    mouse_ler_posicao

    ; Se posição não mudou, não faz nada
    cmp     edi, [cursor_x]
    jne     .mover
    cmp     esi, [cursor_y]
    jne     .mover
    ret

.mover:
    push    rdi
    push    rsi

    ; Restaura o fundo da posição ANTIGA
    call    cursor_restaurar_fundo

    pop     rsi
    pop     rdi

    ; Atualiza para nova posição
    mov     [cursor_x], edi
    mov     [cursor_y], esi

    ; Desenha na NOVA posição
    call    cursor_desenhar_novo

    ret

; ==========================================
; VERIFICAR CLIQUE EM JANELA
; ==========================================
ws_verificar_clique:
    call    mouse_ler_posicao
    test    eax, 0x01
    jz      .nenhum

    xor     rcx, rcx
    lea     rdx, [janelas]
.loop:
    cmp     rcx, MAX_JANELAS
    jge     .nenhum

    cmp     byte [rdx + Janela.visivel], 0
    je      .prox

    mov     r8d, [rdx + Janela.x]
    cmp     edi, r8d
    jl      .prox
    add     r8d, [rdx + Janela.largura]
    cmp     edi, r8d
    jge     .prox

    mov     r9d, [rdx + Janela.y]
    cmp     esi, r9d
    jl      .prox
    add     r9d, [rdx + Janela.altura]
    cmp     esi, r9d
    jge     .prox

    mov     [janela_ativa], ecx
    mov     rax, rcx
    ret

.prox:
    add     rdx, Janela_size
    inc     rcx
    jmp     .loop

.nenhum:
    mov     rax, -1
    ret

; ==========================================
; APRESENTAR — Chamar a cada quadro no loop principal
; ==========================================
ws_apresentar:
    ; Ordem correta: janelas primeiro, cursor por cima
    call    ws_desenhar_janelas
    call    ws_atualizar_cursor
    ret
