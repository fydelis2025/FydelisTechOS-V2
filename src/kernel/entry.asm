; ==========================================
; KERNEL ENTRY — Inicializa e chama FydelisShell
; FydelisTech OS v2.0 · Salvador 🇧🇷
; ==========================================
BITS 64

[EXTERN shell_main]  ; Importa o FydelisShell (PowerShell nativo)

global start
start:
    ; Inicializar tela, memória, tudo que já fazia
    call init_video
    call init_memory
    call init_keyboard
    
    ; 🚀 Mensagem de boas-vindas
    mov rsi, msg_boasvindas
    call print_string
    
    ; 🔑 CHAMAR O POWERShell NATIVO
    call shell_main     ; → Entra no FydelisShell, não em shell antigo
    
    ; Se shell retornar — reiniciar
    jmp $

section .data
msg_boasvindas db 'FydelisTech OS v2.0 — Kernel pronto.', 10, 0