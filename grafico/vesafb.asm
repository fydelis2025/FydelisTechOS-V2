; ==========================================
; 🖥️ VESAFB.ASM — COMPLETO E FUNCIONAL
; FydelisTech OS v4.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
%include "fydelterm.inc"
%include "graphics.inc"

; ========== DADOS ESTENDIDOS ==========
section .bss
align 4096

global fb_base
global fb_largura
global fb_altura
global fb_bpp
global fb_linhasize
global fb_pitch

fb_base:          resq 1   ; Ponteiro para o framebuffer
fb_endereco:      resq 1
fb_largura:       resd 1   ; Largura em pixels (32-bit)
fb_altura:        resd 1   ; Altura em pixels (32-bit)
fb_pitch:         resd 1   ; Bytes por linha (32-bit)
fb_bpp:           resd 1   ; Bits por pixel (32-bit)
fb_tamanho:       resd 1
fb_linhasize:     resd 1   ; Largura em bytes

; Geometria do modo texto sobre framebuffer
fonte_largura:    resd 1
fonte_altura:     resd 1
colunas:          resd 1
linhas:           resd 1
buffer_texto:     resq 1
buffer_tamanho:   resd 1

fonte_padrao_l:   equ 8
fonte_padrao_a:   equ 16

section .text
global fb_inicializar
global fb_redimensionar
global fb_recalcular_geometria
global fb_ajustar_fonte
global fb_limpar
global fb_get_geometria
global fb_desenhar_pixel
global fb_preencher_tela

; ==========================================
; ✅ INICIALIZAÇÃO — chamar APÓS preencher fb_base e resolução
; ==========================================
fb_inicializar:
    cmp     qword [rel fb_base], 0
    je      .sem_fb

    mov     dword [rel fonte_largura], fonte_padrao_l
    mov     dword [rel fonte_altura], fonte_padrao_a

    cmp     dword [rel fb_bpp], 0
    jne     .bpp_ok
    mov     dword [rel fb_bpp], 32
.bpp_ok:

    ; Calcula linhasize = largura * (bpp/8)
    mov     eax, [rel fb_largura]
    mov     ecx, [rel fb_bpp]
    shr     ecx, 3
    mul     ecx
    mov     [rel fb_linhasize], eax

    cmp     dword [rel fb_pitch], 0
    jne     .pitch_ok
    mov     [rel fb_pitch], eax
.pitch_ok:

    call    fb_recalcular_geometria
    mov     rax, 1
    ret

.sem_fb:
    xor     rax, rax
    ret

; ==========================================
; 🧹 LIMPAR TELA com cor sólida
; Entrada: rdi = cor (0xAARRGGBB)
; ==========================================
fb_limpar:
    cmp     qword [rel fb_base], 0
    je      .fim

    push    rbx
    mov     rbx, [rel fb_base]
    mov     r8d, [rel fb_pitch]       ; Leitura 32-bit zera os 32 bits superiores
    mov     edx, [rel fb_altura]
    mov     eax, edi                  ; Cor 32-bit para stosd
    mov     r9, r8
    shr     r9, 2                     ; Quantidade de pixels (dwords) por linha

.linha_loop:
    mov     rcx, r9
    mov     rdi, rbx
    rep     stosd

    add     rbx, r8
    dec     edx
    jnz     .linha_loop

    pop     rbx
.fim:
    ret

; ==========================================
; 🎨 DESENHAR PIXEL — x, y, cor
; rdi = x, rsi = y, rdx = cor (0xAARRGGBB)
; ==========================================
fb_desenhar_pixel:
    mov     eax, [rel fb_largura]
    cmp     rdi, rax
    jge     .fora
    mov     eax, [rel fb_altura]
    cmp     rsi, rax
    jge     .fora

    mov     r9, rdx                   ; Salva cor antes do mul

    ; offset = y * pitch + x * (bpp / 8)
    mov     eax, [rel fb_pitch]
    mul     rsi                       ; rax = y * pitch
    mov     r10, rax

    mov     eax, [rel fb_bpp]
    shr     eax, 3                    ; bytes por pixel
    mul     rdi                       ; rax = x * bytes_por_pixel
    add     rax, r10

    add     rax, [rel fb_base]
    mov     [rax], r9d

.fora:
    ret

; ==========================================
; 🖥️ PREENCHER TELA
; Entrada: rdi = cor (0xAARRGGBB)
; ==========================================
fb_preencher_tela:
    cmp     qword [rel fb_base], 0
    je      .fim

    mov     eax, edi                  ; Carrega a cor 32-bit em EAX para stosd
    mov     r10d, [rel fb_altura]     ; Leitura 32-bit (evita ler fb_pitch junto)
    mov     r11d, [rel fb_largura]    ; Leitura 32-bit (evita ler fb_altura junto)
    mov     r8d, [rel fb_pitch]       ; Leitura 32-bit (evita ler fb_bpp junto)
    mov     r9, [rel fb_base]

.linha:
    mov     rcx, r11                  ; Largura completa em pixels
    mov     rdi, r9
    rep     stosd

    add     r9, r8
    dec     r10d
    jnz     .linha

.fim:
    ret

; ==========================================
; 📐 RECALCULAR COLUNAS × LINHAS
; ==========================================
fb_recalcular_geometria:
    mov     eax, [rel fb_largura]
    xor     edx, edx
    div     dword [rel fonte_largura]
    mov     [rel colunas], eax

    mov     eax, [rel fb_altura]
    xor     edx, edx
    div     dword [rel fonte_altura]
    mov     [rel linhas], eax

    mov     eax, [rel colunas]
    mul     dword [rel linhas]
    shl     eax, 1
    mov     [rel buffer_tamanho], eax
    ret

; ==========================================
; ♻️ REDIMENSIONAR
; ==========================================
fb_redimensionar:
    cmp     edi, 640
    jl      .param_invalido
    cmp     esi, 480
    jl      .param_invalido

    push    rbx
    movsxd  rbx, dword [rel colunas]
    push    rbx
    movsxd  rbx, dword [rel linhas]
    push    rbx

    mov     dword [rel fb_largura], edi
    mov     dword [rel fb_altura], esi

    call    fb_ajustar_fonte
    call    fb_recalcular_geometria

    add     rsp, 24
    mov     rax, 1
    pop     rbx
    ret

.param_invalido:
    xor     rax, rax
    ret

; ==========================================
; 🔤 AJUSTAR FONTE
; ==========================================
fb_ajustar_fonte:
    mov     eax, [rel fb_largura]
    mov     edx, 100
    mul     edx
    mov     ecx, 1024
    xor     edx, edx
    div     ecx

    cmp     eax, 70
    jge     .escala_min_ok
    mov     eax, 70
.escala_min_ok:
    cmp     eax, 150
    jle     .escala_max_ok
    mov     eax, 150
.escala_max_ok:

    mov     ecx, eax
    mov     eax, fonte_padrao_l
    mul     ecx
    mov     edx, 0
    mov     r8d, 100
    div     r8d
    mov     [rel fonte_largura], eax

    mov     eax, fonte_padrao_a
    mul     ecx
    mov     edx, 0
    div     r8d
    mov     [rel fonte_altura], eax

    cmp     dword [rel fonte_largura], 6
    jge     .l_ok
    mov     dword [rel fonte_largura], 6
.l_ok:
    cmp     dword [rel fonte_altura], 12
    jge     .a_ok
    mov     dword [rel fonte_altura], 12
.a_ok:
    ret

; ==========================================
; 📤 RETORNAR GEOMETRIA PARA C
; ==========================================
fb_get_geometria:
    mov     eax, [rel colunas]
    mov     [rdi], eax
    mov     eax, [rel linhas]
    mov     [rdi+4], eax
    mov     eax, [rel fonte_largura]
    mov     [rdi+8], eax
    mov     eax, [rel fonte_altura]
    mov     [rdi+12], eax
    ret

; ==========================================
; 🔄 ALIASES DE COMPATIBILIDADE GLOBAL
; ==========================================
global gpu_preencher_tela
gpu_preencher_tela:
    jmp     fb_preencher_tela
