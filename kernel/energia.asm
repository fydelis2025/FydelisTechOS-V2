; ==========================================
; ENERGIA — Desligar / Reiniciar / Sair
; FydelisTech OS v4.2 — Texto & GUI
; ==========================================
BITS 64
default rel

global do_reboot
global do_poweroff
global do_exit
global energia_reiniciar_agora
global energia_desligar_agora

extern print_string
extern print_newline
extern print_success
extern ler_tecla

section .data
msg_bye:        db "[OK] Saindo do FydelTerm...", 0
msg_reboot_ok:  db "[!] Reiniciando FydelisTech OS...", 0
msg_power_off:  db "[!] Desligando o sistema...", 0
msg_confirmar:  db "[?] Confirma? (s/N): ", 0
msg_cancel:     db "[X] Operacao cancelada.", 0

; Strings para despacho de comandos no commands.asm
global str_exit
global str_reboot
global str_poweroff
global ajuda_exit
global ajuda_reboot
global ajuda_poweroff

str_exit:       db "sair", 0
str_reboot:     db "reiniciar", 0
str_poweroff:   db "desligar", 0

ajuda_exit:     db "sair      - Encerra sessao do terminal", 0
ajuda_reboot:   db "reiniciar - Reinicia o sistema", 0
ajuda_poweroff: db "desligar  - Desliga o sistema", 0

section .bss
buf_resp:       resb 8

section .text

; ==========================================
; REINICIAR (Com confirmação para o FydelTerm)
; ==========================================
do_reboot:
    push rax
    push rsi

    lea rsi, [rel msg_confirmar]
    call print_string
    call ler_resposta
    cmp byte [rel buf_resp], 's'
    je .prosseguir
    cmp byte [rel buf_resp], 'S'
    je .prosseguir

    lea rsi, [rel msg_cancel]
    call print_string
    call print_newline
    pop rsi
    pop rax
    ret

.prosseguir:
    lea rsi, [rel msg_reboot_ok]
    call print_string
    call print_newline
    pop rsi
    pop rax
    ; Cai direto na rotina de hardware abaixo

; ==========================================
; REINICIAR DIRETO (Chamado pelo Menu Iniciar / GUI)
; ==========================================
energia_reiniciar_agora:
    cli
    ; Aguarda buffer de entrada do controlador PS/2 esvaziar
.espera_ps2:
    in al, 0x64
    test al, 0x02
    jnz .espera_ps2

    ; Pulso na linha de RESET da CPU via 8042
    mov al, 0xFE
    out 0x64, al

.parar:
    hlt
    jmp .parar

; ==========================================
; DESLIGAR (Com confirmação para o FydelTerm)
; ==========================================
do_poweroff:
    push rax
    push rsi

    lea rsi, [rel msg_confirmar]
    call print_string
    call ler_resposta
    cmp byte [rel buf_resp], 's'
    je .prosseguir
    cmp byte [rel buf_resp], 'S'
    je .prosseguir

    lea rsi, [rel msg_cancel]
    call print_string
    call print_newline
    pop rsi
    pop rax
    ret

.prosseguir:
    lea rsi, [rel msg_power_off]
    call print_string
    call print_newline
    pop rsi
    pop rax
    ; Cai direto na rotina de hardware abaixo

; ==========================================
; DESLIGAR DIRETO (Chamado pelo Menu Iniciar / GUI)
; ==========================================
energia_desligar_agora:
    cli
    ; Desligamento ACPI padrão QEMU moderno
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax

    ; Fallback Bochs / QEMU antigo
    mov dx, 0xB004
    mov ax, 0x2000
    out dx, ax

    ; Fallback VirtualBox
    mov dx, 0x4004
    mov ax, 0x3400
    out dx, ax

.parar:
    hlt
    jmp .parar

; ==========================================
; SAIR DO TERMINAL (Retorna ao menu de boot)
; ==========================================
do_exit:
    push rax
    push rsi

    lea rsi, [rel msg_confirmar]
    call print_string
    call ler_resposta
    cmp byte [rel buf_resp], 's'
    je .prosseguir
    cmp byte [rel buf_resp], 'S'
    je .prosseguir

    lea rsi, [rel msg_cancel]
    call print_string
    call print_newline
    pop rsi
    pop rax
    ret

.prosseguir:
    lea rsi, [rel msg_bye]
    call print_success
    call print_newline
    pop rsi
    pop rax
    ret

; ==========================================
; FUNÇÃO AUXILIAR: LER RESPOSTA (s/N)
; ==========================================
ler_resposta:
    push rdi
    push rax
    push rcx

    lea rdi, [rel buf_resp]
    xor ecx, ecx
.loop:
    call ler_tecla
    cmp al, 10          ; LF
    je .fim
    cmp al, 13          ; CR
    je .fim
    cmp ecx, 6
    jge .loop
    mov [rdi + rcx], al
    inc ecx
    jmp .loop

.fim:
    mov byte [rdi + rcx], 0
    pop rcx
    pop rax
    pop rdi
    ret
