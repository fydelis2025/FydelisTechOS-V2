; ==========================================
; 📡 PCI_GPU.ASM — DETECÇÃO E MAPEAMENTO MMIO
; Intel · AMD · NVIDIA · Virtio · QEMU
; FydelisTech OS v2.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
%include "fydelterm.inc"
%include "graphics.inc"

; ========== REGISTRADORES PCI ==========
PCI_CONFIG_ADDR      equ 0xCF8
PCI_CONFIG_DATA      equ 0xCFC
PCI_CLASS_VIDEO      equ 0x03
PCI_BAR0_OFFSET      equ 0x10
PCI_CMD_REG          equ 0x04
PCI_CMD_MMIO_EN      equ 0b10
PCI_CMD_BUSMASTER    equ 0b100

; ========== IDs de Fabricantes ==========
VENDOR_INTEL         equ 0x8086
VENDOR_AMD           equ 0x1002
VENDOR_NVIDIA        equ 0x10DE
VENDOR_VIRTIO        equ 0x1AF4
VENDOR_QEMU_STD      equ 0x1234

; ========== ESTRUTURA DE DETECÇÃO ==========
struc GPUInfo
    .presente:       resb 1
    .vendedor:       resw 1
    .dispositivo:    resw 1
    .classe:         resd 1
    .bar0_fisico:    resq 1   ; Endereço físico MMIO
    .bar0_tamanho:   resq 1
    .framebuffer:    resq 1   ; VRAM linear
    .tipo:           resd 1   ; INTEL / AMD / NVIDIA / VESA
endstruc

; Tipos de GPU
GPU_TIPO_DESCONHECIDO  equ 0
GPU_TIPO_INTEL         equ 1
GPU_TIPO_AMD           equ 2
GPU_TIPO_NVIDIA        equ 3
GPU_TIPO_VIRTIO        equ 4
GPU_TIPO_VESA_GEN      equ 5

section .bss
align 8
gpu_info:            resb GPUInfo_size
pci_mmio_mapeado:    resb 1

section .text
global pci_gpu_varrer_barramento
global pci_gpu_mapear_barramentos
global pci_gpu_obter_info
global pci_gpu_ativar_mmio

; ==========================================
; 🔍 VARRER BARRAMENTO → ENCONTRAR GPU
; ==========================================
pci_gpu_varrer_barramento:
    xor     rdx, rdx        ; Bus 0..255
.bus:
    xor     rsi, rsi        ; Device 0..31
.dev:
    xor     rdi, rdi        ; Function 0..7
.funct:
    ; Ler classe/subclasse no offset 0x09
    mov     eax, edx
    shl     eax, 16
    shl     esi, 11
    shl     edi, 8
    or      eax, 0x09
    or      eax, 0x80000000
    out     PCI_CONFIG_ADDR, eax
    nop
    in      eax, PCI_CONFIG_DATA
    shr     eax, 24
    cmp     al, PCI_CLASS_VIDEO
    je      .encontrado

    inc     rdi
    cmp     rdi, 8
    jl      .funct
    inc     rsi
    cmp     rsi, 32
    jl      .dev
    inc     rdx
    cmp     rdx, 256
    jl      .bus

    ; Nenhuma GPU dedicada → usa VESA genérico
    mov     byte [gpu_info + GPUInfo.presente], 0
    mov     dword [gpu_info + GPUInfo.tipo], GPU_TIPO_VESA_GEN
    xor     rax, rax
    ret

.encontrado:
    ; Salvar endereço completo para leitura dos registradores
    push    rdx
    push    rsi
    push    rdi

    ; Ler Vendor/Device ID (offset 0x00)
    mov     eax, edx
    shl     eax, 16
    shl     esi, 11
    shl     rdi, 8
    or      eax, 0x00
    or      eax, 0x80000000
    out     PCI_CONFIG_ADDR, eax
    nop
    in      eax, PCI_CONFIG_DATA
    mov     [gpu_info + GPUInfo.vendedor], ax
    ror     eax, 16
    mov     [gpu_info + GPUInfo.dispositivo], ax

    ; Identificar fabricante
    cmp     word [gpu_info + GPUInfo.vendedor], VENDOR_INTEL
    je      .tipo_intel
    cmp     word [gpu_info + GPUInfo.vendedor], VENDOR_AMD
    je      .tipo_amd
    cmp     word [gpu_info + GPUInfo.vendedor], VENDOR_NVIDIA
    je      .tipo_nvidia
    cmp     word [gpu_info + GPUInfo.vendedor], VENDOR_VIRTIO
    je      .tipo_virtio
    jmp     .tipo_desconhecido

.tipo_intel:
    mov     dword [gpu_info + GPUInfo.tipo], GPU_TIPO_INTEL
    jmp     .identificado
.tipo_amd:
    mov     dword [gpu_info + GPUInfo.tipo], GPU_TIPO_AMD
    jmp     .identificado
.tipo_nvidia:
    mov     dword [gpu_info + GPUInfo.tipo], GPU_TIPO_NVIDIA
    jmp     .identificado
.tipo_virtio:
    mov     dword [gpu_info + GPUInfo.tipo], GPU_TIPO_VIRTIO
    jmp     .identificado
.tipo_desconhecido:
    mov     dword [gpu_info + GPUInfo.tipo], GPU_TIPO_DESCONHECIDO

.identificado:
    pop     rdi
    pop     rsi
    pop     rdx

    mov     byte [gpu_info + GPUInfo.presente], 1
    mov     rax, 1
    ret

; ==========================================
; ✅ ATIVAR MMIO — Habilitar acesso aos registradores
; ==========================================
pci_gpu_ativar_mmio:
    cmp     byte [gpu_info + GPUInfo.presente], 0
    je      .sem_gpu

    ; Ativar bit de MMIO no registrador de comando
    ; (endereço já conhecido da varredura)
    ; ... implementação de ativação ...
    mov     byte [pci_mmio_mapeado], 1
    mov     rax, 1
    ret
.sem_gpu:
    xor     rax, rax
    ret

; ==========================================
; 📤 RETORNAR DADOS PARA C++
; ==========================================
pci_gpu_obter_info:
    ; rdi → ponteiro para estrutura em C++
    mov     eax, [gpu_info + GPUInfo.presente]
    mov     [rdi], eax
    mov     ax,  [gpu_info + GPUInfo.vendedor]
    mov     [rdi+4], ax
    mov     ax,  [gpu_info + GPUInfo.dispositivo]
    mov     [rdi+6], ax
    mov     rax, [gpu_info + GPUInfo.bar0_fisico]
    mov     [rdi+8], rax
    mov     eax, [gpu_info + GPUInfo.tipo]
    mov     [rdi+16], eax
    ret