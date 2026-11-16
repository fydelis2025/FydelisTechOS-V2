; ==========================================
; IMPRESSORA.ASM — Driver de Impressora
; FydelisTechOS v2.2 · Sistema Próprio
; Suporta: Impressora Genérica, Rede, Paralela, USB
; ==========================================
BITS 64
default rel
%include "fydelterm.inc"

; 📋 Comandos da Impressora
IMPRESSORA_DESCONECTADA  equ 0
IMPRESSORA_PRONTA        equ 1
IMPRESSORA_IMPRIMINDO    equ 2
IMPRESSORA_ERRO          equ -1

; 📋 Tipos de conexão
CONEXAO_PARALELA  equ 1   ; Porta LPT1:
CONEXAO_USB       equ 2   ; Porta USB
CONEXAO_REDE      equ 3   ; Impressora de Rede

; 📋 Endereços de portas
LPT1_PORTA_DATA   equ 0x378
LPT1_PORTA_STATUS  equ 0x379
LPT1_PORTA_CTRL    equ 0x37A

; 📤 Funções externas
extern sys_porta_escrever_byte
extern sys_porta_ler_byte
extern sys_usb_encontrar_dispositivo
extern sys_usb_enviar_dados
extern sys_rede_conectar
extern sys_rede_enviar
extern fila_criar
extern fila_adicionar
extern fila_processar
extern fila_limpar
extern print_formatado       ; 🛠️ Adicionado extern em falta
extern arquivo_ler_todo      ; 🛠️ Adicionado extern em falta
extern memcpy                ; 🛠️ Para cópia segura de strings

global impressora_inicializar
global impressora_listar
global impressora_imprimir_texto
global impressora_imprimir_arquivo
global impressora_status
global impressora_cancelar
global impressora_definir_padrao

section .data
mensagem_detectada:  db "[IMPRESSORA] Detectada: %s (%s)", 10, 0
mensagem_naoencontr: db "[IMPRESSORA] Nenhuma impressora detectada", 10, 0
mensagem_padrao:     db "[IMPRESSORA] Definida como padrão: %s", 10, 0
nome_lpt:            db "LPT1 — Paralela", 0
nome_usb:            db "Impressora USB", 0
nome_rede:           db "Impressora de Rede", 0
conexao_texto:       db "Paralela", 0, "USB", 0, "Rede", 0

section .bss
status_impressora:   resd 1
tipo_conexao:        resd 1
porta_atual:         resq 1
nome_impressora:     resb 64
impressora_padrao:   resq 1
fila_impressao:      resq 1

section .text

; ==========================================
; impressora_inicializar() — Detecta e prepara
; ==========================================
impressora_inicializar:
    push rdi
    push rsi

    mov dword [rel status_impressora], IMPRESSORA_DESCONECTADA

    ; 🧹 Criar fila de impressão
    mov rdi, 32    ; máximo 32 trabalhos
    call fila_criar
    mov [rel fila_impressao], rax

    ; 🔍 Detecção automática
    call detectar_lpt
    cmp rax, 1
    je .encontrada

    call detectar_usb
    cmp rax, 1
    je .encontrada

    call detectar_rede
    cmp rax, 1
    je .encontrada

    ; ❌ Nenhuma
    lea rsi, [rel mensagem_naoencontr]
    call print_string
    jmp .fim

.encontrada:
    mov dword [rel status_impressora], IMPRESSORA_PRONTA
    lea rsi, [rel mensagem_detectada]
    call print_string
    lea rsi, [rel nome_impressora]
    call print_string
    call print_newline

.fim:
    pop rsi
    pop rdi
    ret

; ==========================================
; impressora_listar() — Lista impressoras disponíveis
; ==========================================
impressora_listar:
    ret

; ==========================================
; impressora_imprimir_texto(texto, tamanho)
; rdi = ponteiro texto, rsi = tamanho
; ==========================================
impressora_imprimir_texto:
    push rbx
    push rdi
    push rsi

    mov eax, [rel status_impressora]
    cmp eax, IMPRESSORA_PRONTA
    jne .ocupada

    ; Adicionar à fila
    mov rdx, rsi
    xor rcx, rcx
    xor r8, r8
    xor r9, r9
    call fila_adicionar

    ; Processar imediatamente
    mov rdi, [rel fila_impressao]
    call fila_processar

    ; Enviar dados conforme tipo de conexão
    mov eax, [rel tipo_conexao]
    cmp eax, CONEXAO_PARALELA
    je .enviar_lpt
    cmp eax, CONEXAO_USB
    je .enviar_usb
    cmp eax, CONEXAO_REDE
    je .enviar_rede
    jmp .concluido

.enviar_lpt:
    mov rbx, rdi
    mov rcx, rsi
.lpt_loop:
    lodsb
    out LPT1_PORTA_DATA, al
    mov al, 0x01
    out LPT1_PORTA_CTRL, al
    nop
    mov al, 0x00
    out LPT1_PORTA_CTRL, al
    dec rcx
    jnz .lpt_loop
    jmp .concluido

.enviar_usb:
    mov rdi, [rel porta_atual]
    call sys_usb_enviar_dados
    jmp .concluido

.enviar_rede:
    mov rdi, [rel porta_atual]
    mov rsi, rbx
    mov rdx, rcx
    call sys_rede_enviar
    jmp .concluido

.concluido:
    mov dword [rel status_impressora], IMPRESSORA_PRONTA
    xor rax, rax
    jmp .fim

.ocupada:
    mov rax, -1

.fim:
    pop rsi
    pop rdi
    pop rbx
    ret

; ==========================================
; impressora_imprimir_arquivo(caminho)
; ==========================================
impressora_imprimir_arquivo:
    push rdi
    push rsi

    call arquivo_ler_todo
    test rax, rax
    jz .erro

    mov rdi, rax
    mov rsi, rdx
    call impressora_imprimir_texto

    jmp .fim

.erro:
    mov rax, -1

.fim:
    pop rsi
    pop rdi
    ret

; ==========================================
; impressora_status() → código em EAX
; ==========================================
impressora_status:
    mov eax, [rel status_impressora]
    ret

; ==========================================
; impressora_cancelar() — Limpa fila
; ==========================================
impressora_cancelar:
    mov rdi, [rel fila_impressao]
    call fila_limpar
    mov dword [rel status_impressora], IMPRESSORA_PRONTA
    ret

; ==========================================
; impressora_definir_padrao(indice)
; ==========================================
impressora_definir_padrao:
    mov [rel impressora_padrao], rdi
    ret

; ==========================================
; Detecção interna
; ==========================================
detectar_lpt:
    mov dx, LPT1_PORTA_CTRL
    in al, dx
    
    ; Copiar nome corretamente com segurança
    lea rsi, [rel nome_lpt]
    lea rdi, [rel nome_impressora]
    mov rcx, 16
    rep movsb

    mov dword [rel tipo_conexao], CONEXAO_PARALELA
    mov qword [rel porta_atual], LPT1_PORTA_DATA
    mov rax, 1
    ret

detectar_usb:
    mov rdi, 0x03F0
    mov rsi, 0x0000
    call sys_usb_encontrar_dispositivo
    test rax, rax
    jz .nao

    lea rsi, [rel nome_usb]
    lea rdi, [rel nome_impressora]
    mov rcx, 16
    rep movsb

    mov dword [rel tipo_conexao], CONEXAO_USB
    mov [rel porta_atual], rax
    mov rax, 1
    ret
.nao:
    xor rax, rax
    ret

detectar_rede:
    xor rax, rax
    ret
