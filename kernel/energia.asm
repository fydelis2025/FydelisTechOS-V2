; ==========================================
; ENERGIA — Desligar / Reiniciar / Sair
; Compatível com o que já existe no commands.asm
; ==========================================

; Mensagens (adicione na seção .data)
msg_bye:         db "👋 Saindo do FydelTerm...",0
msg_reboot_ok:   db "🔄 Reiniciando...",0
msg_power_off:   db "🔌 Desligando sistema...",0
msg_confirmar:   db "⚠️  Confirma? (s/N): ",0
msg_cancel:      db "❌ Cancelado.",0

; Comandos que você JÁ tem — mantém:
str_exit:       db 'sair',0
str_reboot:     db 'reiniciar',0
str_poweroff:   db 'desligar',0   ; ← novo comando

ajuda_exit:     db 'sair - Encerra sessão do terminal',0
ajuda_reboot:   db 'reiniciar - Reinicia o sistema',0
ajuda_poweroff: db 'desligar - Desliga o sistema',0   ; ← novo

; ==========================================
; 🔄 REINICIAR — Melhorado
; ==========================================
do_reboot:
    push rax
    push rsi

    lea rsi, [rel msg_confirmar]
    call print_string
    call ler_resposta
    cmp byte [buf_resp], 's'
    je .prosseguir
    cmp byte [buf_resp], 'S'
    je .prosseguir

    lea rsi, [rel msg_cancel]
    call print_string
    jmp .fim

.prosseguir:
    lea rsi, [rel msg_reboot_ok]
    call print_string
    call print_newline

    ; Método confiável — controlador de teclado
    mov al, 0xFE
    out 0x64, al

    ; Se chegou aqui → tentativa alternativa
    mov dx, 0x64
    in al, dx
    test al, 2
    jnz $-4
    mov al, 0xD1
    out dx, al
    mov dx, 0x60
    mov al, 0
    out dx, al

    cli
.parar:
    hlt
    jmp .parar

.fim:
    pop rsi
    pop rax
    ret

; ==========================================
; 🔌 DESLIGAR — Novo comando
; ==========================================
do_poweroff:
    push rax
    push rsi
    push rdx

    lea rsi, [rel msg_confirmar]
    call print_string
    call ler_resposta
    cmp byte [buf_resp], 's'
    je .prosseguir
    cmp byte [buf_resp], 'S'
    je .prosseguir

    lea rsi, [rel msg_cancel]
    call print_string
    jmp .fim

.prosseguir:
    lea rsi, [rel msg_power_off]
    call print_string
    call print_newline

    ; Tenta desligar via porta QEMU/ACPI
    mov dx, 0x604
    xor eax, eax
    out dx, eax

    ; Fallback: se não desligar, avisa
    cli
.parar:
    hlt
    jmp .parar

.fim:
    pop rdx
    pop rsi
    pop rax
    ret

; ==========================================
; 🚪 SAIR — Mantido e melhorado
; ==========================================
do_exit:
    push rsi

    lea rsi, [rel msg_confirmar]
    call print_string
    call ler_resposta
    cmp byte [buf_resp], 's'
    je .prosseguir
    cmp byte [buf_resp], 'S'
    je .prosseguir

    lea rsi, [rel msg_cancel]
    call print_string
    jmp .fim

.prosseguir:
    lea rsi, [rel msg_bye]
    call print_success
    call print_newline

    ; Retorna ao bootloader — ajuste o endereço se precisar
    jmp 0x7C00   ; ← endereço padrão do bootloader MBR

.fim:
    pop rsi
    ret

; ==========================================
; 📝 Função auxiliar: ler resposta do usuário
; ==========================================
ler_resposta:
    push rdi
    push rax

    lea rdi, [buf_resp]
    mov rcx, 1
.loop:
    call ler_tecla       ; ← sua função do fydelterm
    cmp al, 10          ; Enter
    je .fim
    cmp al, 13          ; CR
    je .fim
    stosb
    jmp .loop

.fim:
    mov byte [rdi], 0
    pop rax
    pop rdi
    ret

; Buffer temporário
section .bss
buf_resp: resb 8
extern ler_tecla        ; ← confirme o nome da sua função
extern print_success
