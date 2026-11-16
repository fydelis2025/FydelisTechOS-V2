; ==========================================
; 🔄 GPU_DISPATCH — Seletor Automático
; FydelisTech OS v4.2 · VESA + Fallback Genérico
; Salvador • Bahia 🇧🇷
; ==========================================
BITS 64

; Framebuffer compartilhado com VESA/GOP
extern fb_base
extern fb_largura
extern fb_altura
extern fb_pitch
extern fb_bpp

; Drivers de aceleração (defina como externos se implementados)
; extern intel_detectar
; extern intel_inicializar
; extern intel_preencher_retangulo
; extern virtio_detectar
; extern virtio_inicializar
; extern virtio_preencher_retangulo
; extern amd_detectar
; extern amd_inicializar
; extern amd_preencher_retangulo

; Driver genérico
extern fb_preencher_retangulo

section .data
align 8
gpu_desenhar:   dq 0
gpu_tipo:       dd 0   ; 0=genérico, 1=Intel, 2=Virtio, 3=AMD

section .text
global gpu_inicializar
global gpu_preencher_retangulo
global gpu_obter_tipo

; ==========================================
; ✅ INICIALIZAR — Chamar no início do kernel
; ==========================================
gpu_inicializar:
    ; Verifica se framebuffer está disponível
    cmp     qword [rel fb_base], 0
    jz      .sem_fb

    ; === Tenta drivers de aceleração aqui ===
    ; Descomente quando implementar:
    ;
    ; call  intel_detectar
    ; test  rax, rax
    ; jnz   .intel
    ;
    ; call  virtio_detectar
    ; test  rax, rax
    ; jnz   .virtio
    ;
    ; call  amd_detectar
    ; test  rax, rax
    ; jnz   .amd

    ; === Fallback: Framebuffer Genérico ===
    mov     rax, fb_preencher_retangulo
    mov     [rel gpu_desenhar], rax
    mov     dword [rel gpu_tipo], 0
    mov     rax, 1   ; Sucesso
    ret

.sem_fb:
    xor     rax, rax
    ret

; .intel:
;     call  intel_inicializar
;     mov   rax, intel_preencher_retangulo
;     mov   [rel gpu_desenhar], rax
;     mov   dword [rel gpu_tipo], 1
;     mov   rax, 1
;     ret
;
; .virtio:
;     call  virtio_inicializar
;     mov   rax, virtio_preencher_retangulo
;     mov   [rel gpu_desenhar], rax
;     mov   dword [rel gpu_tipo], 2
;     mov   rax, 1
;     ret
;
; .amd:
;     call  amd_inicializar
;     mov   rax, amd_preencher_retangulo
;     mov   [rel gpu_desenhar], rax
;     mov   dword [rel gpu_tipo], 3
;     mov   rax, 1
;     ret

; ==========================================
; 🎨 DESENHAR RETÂNGULO
; Entrada: rdi=x1, rsi=y1, rdx=x2, rcx=y2, r8d=cor (0xAARRGGBB)
; ==========================================
gpu_preencher_retangulo:
    cmp     qword [rel gpu_desenhar], 0
    jz      .fim
    jmp     [rel gpu_desenhar]

.fim:
    ret

; ==========================================
; 📤 RETORNAR TIPO DE DRIVER ATIVO
; Saída: rax = 0=genérico, 1=Intel, 2=Virtio, 3=AMD
; ==========================================
gpu_obter_tipo:
    mov     eax, [rel gpu_tipo]
    ret
    
; ==========================================
; 🔄 ALIAS COMPATIBILIDADE LOGIN/TERMINAL
; ==========================================
global gpu_inicializar_todos
gpu_inicializar_todos:
    call gpu_inicializar
    ret
