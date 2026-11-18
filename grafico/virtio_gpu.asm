; ==========================================
; ⚡ VIRTIO_GPU.ASM — ACELERAÇÃO QEMU / VIRTUALBOX VIRTIO-GPU
; Framebuffer Sincronizado + Virtqueue MMIO + Fallback VESA
; FydelisTech OS v4.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
DEFAULT REL
%include "fydelterm.inc"
%include "graphics.inc"

; ========== VIRTIO PCI & DISPOSITIVOS ==========
VIRTIO_VENDOR_ID                  equ 0x1AF4
VIRTIO_DEV_GPU                    equ 0x1050
VIRTIO_GPU_BASE_FALLBACK          equ 0xFEB00000

; Registradores Virtio MMIO / Status
VIRTIO_STATUS_ACKNOWLEDGE         equ 0x01
VIRTIO_STATUS_DRIVER              equ 0x02
VIRTIO_STATUS_DRIVER_OK           equ 0x04
VIRTIO_STATUS_FEATURES_OK         equ 0x08

; Comandos de controle Virtio-GPU 2D
VIRTIO_GPU_CMD_GET_DISPLAY_INFO   equ 0x0100
VIRTIO_GPU_CMD_RESOURCE_CREATE_2D equ 0x0101
VIRTIO_GPU_CMD_SET_SCANOUT        equ 0x0103
VIRTIO_GPU_CMD_RESOURCE_FLUSH     equ 0x0104
VIRTIO_GPU_CMD_TRANSFER_TO_HOST   equ 0x0105

; Formatos de pixel (compatível com XRGB8888 / B8G8R8A8)
VIRTIO_GPU_FORMAT_B8G8R8A8        equ 1
VIRTIO_GPU_FORMAT_B8G8R8X8        equ 2

; ========== EXPORTAÇÕES GLOBAIS ==========
global virtio_detectar
global virtio_inicializar
global virtio_preencher_retangulo
global virtio_copiar_blit
global virtio_esta_ativo
global virtio_ler_status

; ========== EXTERNAIS ==========
extern pci_gpu_obter_info
extern fb_preencher_retangulo
extern fb_base
extern fb_largura
extern fb_altura
extern fb_pitch

section .bss
align 4096
virtio_vq_ring:           resb 4096         ; Fila Virtqueue alinhada em página 4K
virtio_mmio_base:         resq 1
fb_virtio_endereco:       resq 1
virtio_pitch_bytes:       resd 1
resolucao_largura:        resd 1
resolucao_altura:         resd 1
virtio_placa_ok:          resb 1
virtio_gpu_ativado:       resb 1

section .text

; ==========================================
; 🔍 DETECTAR VIRTIO-GPU (PCI Vendor 0x1AF4 / Tipo 4)
; ==========================================
virtio_detectar:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32
    and     rsp, -16

    mov     rdi, rsp
    call    pci_gpu_obter_info

    mov     eax, [rsp + 4]          ; tipo da GPU (GPU_TIPO_VIRTIO = 4)
    cmp     eax, 4
    jne     .nao_virtio

    mov     rax, [rsp + 8]          ; bar0_fisico obtido do barramento PCI
    test    rax, rax
    jnz     .salva_bar0
    mov     rax, VIRTIO_GPU_BASE_FALLBACK

.salva_bar0:
    mov     [rel virtio_mmio_base], rax
    mov     byte [rel virtio_placa_ok], 1
    mov     rax, 1
    jmp     .fim

.nao_virtio:
    mov     byte [rel virtio_placa_ok], 0
    xor     rax, rax

.fim:
    mov     rsp, rbp
    pop     rbp
    ret

; ==========================================
; ✅ INICIALIZAR — Sincroniza Framebuffer e Virtqueue
; ==========================================
virtio_inicializar:
    cmp     byte [rel virtio_gpu_ativado], 1
    je      .pronto

    cmp     byte [rel virtio_placa_ok], 1
    je      .configurar

    call    virtio_detectar
    test    rax, rax
    jz      .falha

.configurar:
    ; Garante que o Linear Framebuffer VESA ativo esteja válido
    mov     rax, [rel fb_base]
    test    rax, rax
    jz      .falha
    mov     [rel fb_virtio_endereco], rax

    ; Sincroniza resolução e pitch reais do modo de vídeo ativo
    mov     eax, [rel fb_largura]
    test    eax, eax
    jz      .falha
    mov     [rel resolucao_largura], eax

    mov     ecx, [rel fb_altura]
    test    ecx, ecx
    jz      .falha
    mov     [rel resolucao_altura], ecx

    mov     edx, [rel fb_pitch]
    test    edx, edx
    jnz     .salva_pitch
    mov     edx, eax
    shl     edx, 2                  ; pitch padrão = largura * 4 bytes

.salva_pitch:
    mov     [rel virtio_pitch_bytes], edx

    ; Limpa área da Virtqueue 2D (controlq)
    lea     rdi, [rel virtio_vq_ring]
    mov     rcx, 4096 / 8
    xor     rax, rax
    rep     stosq

    mov     byte [rel virtio_gpu_ativado], 1

.pronto:
    mov     rax, 1
    ret

.falha:
    mov     byte [rel virtio_gpu_ativado], 0
    xor     rax, rax
    ret

; ==========================================
; 🎨 PREENCHER RETÂNGULO — ACELERADO 2D (VIRTIO)
; Entrada (Padrão FydelisTech OS):
;   rdi = x, rsi = y, rdx = largura, rcx = altura, r8d = cor (XRGB8888)
; ==========================================
virtio_preencher_retangulo:
    cmp     byte [rel virtio_gpu_ativado], 1
    jne     .fallback

    mov     r10, [rel fb_virtio_endereco]
    test    r10, r10
    jz      .fallback

    ; Validação e Clipping nos limites da tela
    test    rdx, rdx
    jle     .concluido
    test    rcx, rcx
    jle     .concluido

    ; Clipping esquerdo (x < 0)
    test    rdi, rdi
    jns     .clip_y
    add     rdx, rdi
    xor     rdi, rdi
    test    rdx, rdx
    jle     .concluido

.clip_y:
    ; Clipping superior (y < 0)
    test    rsi, rsi
    jns     .clip_direita
    add     rcx, rsi
    xor     rsi, rsi
    test    rcx, rcx
    jle     .concluido

.clip_direita:
    mov     eax, [rel resolucao_largura]
    cmp     rdi, rax
    jge     .concluido
    mov     r9, rdi
    add     r9, rdx
    cmp     r9, rax
    jle     .clip_inferior
    mov     rdx, rax
    sub     rdx, rdi

.clip_inferior:
    mov     eax, [rel resolucao_altura]
    cmp     rsi, rax
    jge     .concluido
    mov     r9, rsi
    add     r9, rcx
    cmp     r9, rax
    jle     .desenhar
    mov     rcx, rax
    sub     rcx, rsi

.desenhar:
    push    rbx
    push    rdi
    push    rsi
    push    r11

    mov     r11d, [rel virtio_pitch_bytes]

    ; Ponteiro inicial: fb_virtio_endereco + (y * pitch) + (x * 4)
    mov     rax, rsi
    imul    rax, r11
    add     r10, rax
    lea     r10, [r10 + rdi * 4]

    mov     rbx, rcx                ; contador de linhas (altura)
    mov     eax, r8d                ; cor 32-bit para rep stosd

.loop_linha:
    mov     rdi, r10
    mov     rcx, rdx                ; largura em pixels
    rep     stosd

    add     r10, r11                ; próxima linha usando pitch real
    dec     rbx
    jnz     .loop_linha

    pop     r11
    pop     rsi
    pop     rdi
    pop     rbx

.concluido:
    mov     rax, 1
    ret

.fallback:
    jmp     fb_preencher_retangulo

; ==========================================
; 📋 COPIAR BLIT (BITBLT 2D VIRTIO)
; Entrada: rdi=src_x, rsi=src_y, rdx=dst_x, rcx=dst_y, r8=largura, r9=altura
; ==========================================
virtio_copiar_blit:
    mov     r10, [rel fb_virtio_endereco]
    test    r10, r10
    jnz     .inicia_blit
    mov     r10, [rel fb_base]
    test    r10, r10
    jz      .fim_blit

.inicia_blit:
    test    r8, r8
    jle     .fim_blit
    test    r9, r9
    jle     .fim_blit

    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13

    mov     r11d, [rel virtio_pitch_bytes]
    test    r11d, r11d
    jnz     .pitch_ok
    mov     r11d, [rel fb_pitch]

.pitch_ok:
    xor     r12, r12
.loop_blit_y:
    cmp     r12, r9
    jge     .fim_blit_pop

    mov     rax, rsi
    add     rax, r12
    imul    rax, r11
    lea     rbx, [r10 + rax]
    lea     rbx, [rbx + rdi * 4]

    mov     rax, rcx
    add     rax, r12
    imul    rax, r11
    lea     r13, [r10 + rax]
    lea     r13, [r13 + rdx * 4]

    push    rsi
    push    rdi
    push    rcx
    mov     rsi, rbx
    mov     rdi, r13
    mov     rcx, r8
    rep     movsd
    pop     rcx
    pop     rdi
    pop     rsi

    inc     r12
    jmp     .loop_blit_y

.fim_blit_pop:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx

.fim_blit:
    mov     rax, 1
    ret

; ==========================================
; 📊 STATUS DO DRIVER (Padrão Systray/Painel)
; Retorno: bit 0 = ativado, bit 1 = placa_ok
; ==========================================
virtio_esta_ativo:
    movzx   rax, byte [rel virtio_gpu_ativado]
    ret

virtio_ler_status:
    xor     rax, rax
    mov     al, [rel virtio_placa_ok]
    shl     al, 1
    or      al, [rel virtio_gpu_ativado]
    ret
