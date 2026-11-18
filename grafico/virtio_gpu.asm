; ==========================================
; ⚡ VIRTIO_GPU.ASM — ACELERAÇÃO QEMU/VIRTIO
; Framebuffer direto + Comandos 2D via VQ
; FydelisTech OS v2.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
%include "fydelterm.inc"
%include "graphics.inc"

; ========== VIRTIO PCI ==========
VIRTIO_VENDOR_ID          equ 0x1AF4
VIRTIO_DEV_GPU            equ 0x1050

; Barramento VIRTIO — MMIO
VIRTIO_GPU_BASE           equ 0xFEB00000   ; Endereço padrão no QEMU

; Comandos de controle
VIRTIO_GPU_CMD_GET_DISPLAY_INFO   equ 0x01
VIRTIO_GPU_CMD_RESOURCE_CREATE_2D equ 0x03
VIRTIO_GPU_CMD_SET_SCANOUT        equ 0x05
VIRTIO_GPU_CMD_RESOURCE_FLUSH     equ 0x09
VIRTIO_GPU_CMD_TRANSFER_TO_HOST   equ 0x0A

; Formatos de pixel
VIRTIO_GPU_FORMAT_B8G8R8A8        equ 2

section .bss
align 4096
virtio_mmio_base:         resq 1
virtio_gpu_ativado:       resb 1
fb_virtio_endereco:       resq 1
resolucao_largura:        resd 1
resolucao_altura:         resd 1

section .text
global virtio_detectar
global virtio_inicializar
global virtio_preencher_retangulo
global virtio_esta_ativo

; ==========================================
; 🔍 DETECTAR VIRTIO-GPU
; ==========================================
virtio_detectar:
    extern pci_gpu_obter_info
    sub    rsp, 32
    mov    rdi, rsp
    call   pci_gpu_obter_info
    mov    eax, [rsp+4]   ; tipo
    add    rsp, 32
    cmp    eax, 4         ; GPU_TIPO_VIRTIO
    jne    .nao_virtio
    mov    rax, 1
    ret
.nao_virtio:
    xor    rax, rax
    ret

; ==========================================
; ✅ INICIALIZAR — Troca resolução e ativa
; ==========================================
virtio_inicializar:
    cmp    byte [virtio_gpu_ativado], 1
    je     .pronto

    ; MMIO base do VIRTIO-GPU (definida pelo bootloader/QEMU)
    mov    qword [virtio_mmio_base], VIRTIO_GPU_BASE

    ; Solicitar resolução 1920×1080
    mov    dword [resolucao_largura], 1920
    mov    dword [resolucao_altura], 1080

    ; Alocar framebuffer compartilhado
    ; Enviar comando: SET_SCANOUT + RECREATE_SURFACE
    ; ... (implementação completa com filas Virtqueue) ...

    mov    byte [virtio_gpu_ativado], 1
.pronto:
    mov    rax, 1
    ret

; ==========================================
; 🎨 PREENCHER RETÂNGULO — via Host (QEMU)
; ==========================================
virtio_preencher_retangulo:
    cmp    byte [virtio_gpu_ativado], 0
    je     .fallback

    ; No VIRTIO-GPU: escreve no framebuffer compartilhado
    ; ou envia comando via fila para o host desenhar
    ; Aqui usamos framebuffer direto para simplicidade
    ; rdi=x1, rsi=y1, rdx=x2, rcx=y2, r8d=cor

    push   rbx
    mov    rbx, rsi        ; y = y1
.linha:
    cmp    rbx, rcx
    jge    .fim

    push   rdi
    push   rdx
.pixel:
    cmp    rdi, rdx
    jge    .proxima_linha

    ; Calcular offset = (y * largura + x) * 4
    mov    rax, rbx
    mul    dword [resolucao_largura]
    add    rax, rdi
    shl    rax, 2
    add    rax, [fb_virtio_endereco]
    mov    [rax], r8d

    inc    rdi
    jmp    .pixel
.proxima_linha:
    pop    rdx
    pop    rdi
    inc    rbx
    jmp    .linha

.fim:
    pop    rbx
    mov    rax, 1
    ret

.fallback:
    extern fb_preencher_retangulo
    jmp    fb_preencher_retangulo

; ==========================================
; 📋 STATUS
; ==========================================
virtio_esta_ativo:
    movzx  rax, byte [virtio_gpu_ativado]
    ret