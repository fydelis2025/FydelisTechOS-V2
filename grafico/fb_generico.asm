; ==========================================
; FB_GENÉRICO — Framebuffer por Software (32-bit XRGB8888)
; FydelisTech OS v4.2 · Salvador • Bahia
; ==========================================
BITS 64

extern fb_base
extern fb_largura
extern fb_altura
extern fb_pitch
extern fb_bpp

section .text
global fb_preencher_retangulo

; Entrada: RDI=x1, RSI=y1, RDX=x2, RCX=y2, R8D=cor
fb_preencher_retangulo:
    cmp     qword [rel fb_base], 0
    jz      .fim

    ; Leitura segura de 32 bits
    mov     r9d,  [rel fb_largura]
    mov     r10d, [rel fb_altura]

    ; Clipping de limites — X1
    cmp     rdi, 0
    cmovl   rdi, [rel fb_zero]
    cmp     rdi, r9
    cmovge  rdi, r9

    ; Clipping — Y1
    cmp     rsi, 0
    cmovl   rsi, [rel fb_zero]
    cmp     rsi, r10
    cmovge  rsi, r10

    ; Clipping — X2, Y2
    cmp     rdx, r9
    cmovg   rdx, r9
    cmp     rcx, r10
    cmovg   rcx, r10

    ; Largura e Altura em pixels
    mov     r11, rdx
    sub     r11, rdi
    jle     .fim        ; x2 <= x1 → sem área

    mov     r10, rcx
    sub     r10, rsi
    jle     .fim        ; y2 <= y1 → sem área

    ; Pitch em bytes
    mov     r12d, [rel fb_pitch]
    test    r12d, r12d
    jnz     .pitch_ok
    mov     r12d, [rel fb_largura]
    shl     r12d, 2
.pitch_ok:

    ; Endereço inicial = fb_base + y1*pitch + x1*4
    mov     rax, rsi
    imul    rax, r12
    mov     rdx, [rel fb_base]
    add     rdx, rax
    lea     rdx, [rdx + rdi*4]      ; RDX = ponteiro da primeira linha

    ; Prepara cor replicada em 4x para escrita mais rápida
    mov     eax, r8d
    movq    xmm0, rax
    pshufd  xmm0, xmm0, 0b00000000   ; 4 pixels de uma vez em XMM0

.linha:
    mov     rdi, rdx
    mov     rcx, r11
    
    ; Escreve em blocos de 4 pixels primeiro
    mov     r8, rcx
    shr     r8, 2          ; r8 = largura / 4
    jz      .resto
    
.bloco4:
    movups  [rdi], xmm0
    add     rdi, 16
    dec     r8
    jnz     .bloco4

.resto:
    and     rcx, 3         ; pixels restantes (1-3)
    rep     stosd

.proxima_linha:
    add     rdx, r12
    dec     r10
    jnz     .linha

.fim:
    ret

section .rodata
align 4
fb_zero: dd 0
