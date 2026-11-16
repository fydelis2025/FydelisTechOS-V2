; ==========================================
; ⚡ INTEL_GPU.ASM — ACELERAÇÃO 2D PARA INTEL
; Família GMCH · iGPU · Gen3/4/5/6+
; FydelisTech OS v2.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
%include "fydelterm.inc"
%include "graphics.inc"

; ========== REGISTRADORES — GMCH / PCI BAR0 ==========
INTEL_GMCH_MMIO_BAR        equ 0x18       ; BAR1 = MMIO do controlador
INTEL_GMCH_OFFSET          equ 0x00000000

; Registradores de controle
INTEL_VIDEO_DISPLAY        equ 0x6100     ; Ativação de saída
INTEL_RING_BUFFER_TAIL     equ 0x2000
INTEL_RING_BUFFER_HEAD     equ 0x2004
INTEL_RING_BUFFER_BASE     equ 0x2008
INTEL_RING_BUFFER_CONTROL  equ 0x2030

; Comandos de aceleração 2D
INTEL_CMD_FILL_RECT        equ 0x50000000
INTEL_CMD_COPY_BLIT        equ 0x52000000
INTEL_CMD_PIXEL_WRITE      equ 0x40000000

; Máscaras
RING_BUFFER_ENABLE         equ 0x00000001
RING_BUFFER_SIZE_64KB      equ 0x00000000

section .bss
align 4096
intel_mmio_base:           resq 1
intel_ring_base:           resq 1
intel_ring_tail:           resd 1
intel_ativado:             resb 1
intel_generacao:           resd 1        ; 3=Gen3, 4=Gen4, etc.

section .text
global intel_detectar
global intel_inicializar
global intel_preencher_retangulo
global intel_copiar_blit
global intel_esta_ativo

; ==========================================
; 🔍 DETECTAR — Verificar se é Intel GMCH/iGPU
; ==========================================
intel_detectar:
    ; Verifica se GPU detectada é Intel (VENDOR_ID=0x8086)
    extern pci_gpu_obter_info
    push   rdi
    sub    rsp, 32
    mov    rdi, rsp
    call   pci_gpu_obter_info
    mov    eax, [rsp+4]   ; tipo
    cmp    eax, 1         ; GPU_TIPO_INTEL
    jne    .nao_intel
    add    rsp, 32
    pop    rdi
    mov    rax, 1
    ret
.nao_intel:
    add    rsp, 32
    pop    rdi
    xor    rax, rax
    ret

; ==========================================
; ✅ INICIALIZAR MMIO + RING BUFFER
; ==========================================
intel_inicializar:
    cmp    byte [intel_ativado], 1
    je     .pronto

    ; Obter BAR0 do PCI já mapeado
    extern pci_gpu_obter_info
    sub    rsp, 32
    mov    rdi, rsp
    call   pci_gpu_obter_info
    mov    rax, [rsp+8]   ; bar0_fisico
    add    rsp, 32
    mov    [intel_mmio_base], rax

    ; TODO: Mapear endereço físico → virtual no kernel
    ; Por enquanto: uso direto em endereço físico (bootloader mapeou)

    ; Inicializar Ring Buffer
    mov    rdx, [intel_mmio_base]
    mov    dword [rdx + INTEL_RING_BUFFER_CONTROL], 0  ; Desativa primeiro

    ; Configurar endereço base do ring
    mov    rax, [intel_ring_base]
    mov    [rdx + INTEL_RING_BUFFER_BASE], rax

    ; Tamanho e ativação
    mov    dword [rdx + INTEL_RING_BUFFER_CONTROL], RING_BUFFER_ENABLE | RING_BUFFER_SIZE_64KB
    mov    dword [intel_ring_tail], 0

    ; Detecção de geração (simplificada)
    mov    dword [intel_generacao], 4  ; Padrão Gen4+

    mov    byte [intel_ativado], 1
.pronto:
    mov    rax, 1
    ret

; ==========================================
; 🎨 PREENCHER RETÂNGULO — ACELERADO
; rdi=x1, rsi=y1, rdx=x2, rcx=y2, r8d=cor
; ==========================================
intel_preencher_retangulo:
    cmp    byte [intel_ativado], 0
    je     .fallback

    ; Montar descritor de comando no Ring Buffer
    mov    r9, [intel_ring_tail]
    shl    r9, 2   ; offset em bytes

    mov    r10, [intel_ring_base]
    add    r10, r9

    ; Comando: Preencher retângulo
    mov    dword [r10 + 0], INTEL_CMD_FILL_RECT | (4 << 8)  ; comprimento em DW
    mov    dword [r10 + 4], edi       ; x1/y1 compactado
    mov    dword [r10 + 8], esi
    mov    dword [r10 + 12], edx      ; x2/y2
    mov    dword [r10 + 16], ecx
    mov    dword [r10 + 20], r8d      ; cor

    ; Avançar Tail → executa comando
    add    dword [intel_ring_tail], 8
    mov    rdx, [intel_mmio_base]
    mov    eax, [intel_ring_tail]
    mov    [rdx + INTEL_RING_BUFFER_TAIL], eax

    ; Espera concluído (simplificado)
    mov    rax, 1
    ret

.fallback:
    ; Chama desenho por software (framebuffer linear)
    extern fb_preencher_retangulo
    jmp    fb_preencher_retangulo

; ==========================================
; 📋 RETORNAR STATUS
; ==========================================
intel_esta_ativo:
    movzx  rax, byte [intel_ativado]
    ret
