;=================================================
; SISTEMA DE LOGS DO FYDELISTECHOS v1.2 (Autônomo)
; Autor: Adiel Santos Fontes
; Construído do zero — Sem dependências externas
; Salvador • Bahia 🇧🇷
;=================================================
BITS 64
default rel

;============= TIPOS DE EVENTOS ===================
%define LOG_INFO     0
%define LOG_AVISO    1
%define LOG_ERRO     2
%define LOG_CRITICO  3

;=============== SEÇÃO DE DADOS ===================
section .data
    msg_inicio:      db "[SISTEMA] Módulo de Logs Autônomo carregado — FydLog v1.2", 0
    nova_linha:      db 0x0A, 0
    
    ; ETIQUETAS VISÍVEIS
    etiqueta_info:    db "[INFO] ", 0
    etiqueta_aviso:   db "[AVISO] ", 0
    etiqueta_erro:    db "[ERRO] ", 0
    etiqueta_critico: db "[CRÍTICO] ", 0

;=============== VARIÁVEIS E BUFFER ===================
section .bss
    inicializado:   resb 1   ; 0 = não, 1 = sim
    lock_log:       resb 1   ; Controle de concorrência (Spinlock)
    buffer_logs:    resb 4096 ; Buffer interno de 4KB para armazenamento na RAM

;=============== CÓDIGO PRINCIPAL ====================
section .text
global fydlog_inicializar
global fydlog_escrever
global fydlog_ler_todos
global fydlog_fechar

; Rotinas básicas internas de impressão (substituem dependências externas)
print_string:
    ; Implementação padrão de terminal do kernel se necessário, 
    ; ou chamada nativa de exibição de caractere/string.
    ret

print_newline:
    mov rdi, nova_linha
    call print_string
    ret

;=============== INICIALIZAR O SISTEMA DE LOG ====================
fydlog_inicializar:
    push    rax
    push    rdi
    push    rsi

    cmp byte [inicializado], 1
    je .ja_inicializado

    ; Inicializa o buffer ou estado interno
    mov byte [inicializado], 1
    mov byte [lock_log], 0

    mov     rdi, msg_inicio
    call    print_string
    call    print_newline

.ja_inicializado:
    pop     rsi
    pop     rdi
    pop     rax
    mov     rax, 1              ; Sucesso
    ret

;=============== ESCREVER NO LOG — AUTÔNOMO ====================
fydlog_escrever:
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi

    cmp byte [inicializado], 1
    je      .tentar_travar
    call    fydlog_inicializar

.tentar_travar:
    mov     al, 1
    xchg    [lock_log], al
    cmp     al, 1
    je      .tentar_travar

    ; --- SEÇÃO CRÍTICA ---
    mov     rbx, rdi            ; Salva tipo
    mov     rdx, rsi            ; Salva mensagem

    ; Seleciona e imprime a etiqueta correspondente
    cmp     rbx, LOG_INFO
    je      .etq_info
    cmp     rbx, LOG_AVISO
    je      .etq_aviso
    cmp     rbx, LOG_ERRO
    je      .etq_erro
    jmp     .etq_critico

.etq_info:
    mov     rdi, etiqueta_info
    jmp     .imprime_etq
.etq_aviso:
    mov     rdi, etiqueta_aviso
    jmp     .imprime_etq
.etq_erro:
    mov     rdi, etiqueta_erro
    jmp     .imprime_etq
.etq_critico:
    mov     rdi, etiqueta_critico

.imprime_etq:
    call    print_string

    ; Imprime a mensagem original passada em rdx
    mov     rdi, rdx
    call    print_string
    call    print_newline

    ; --- FIM DA SEÇÃO CRÍTICA ---
    mov byte [lock_log], 0      ; Libera o lock

.fim_escrever:
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

;=============== LER TODOS OS LOGS ====================
fydlog_ler_todos:
    push    rax
    push    rdi
    push    rsi

    cmp byte [inicializado], 1
    jne     .fim_leitura

    ; Como os logs estão em memória/buffer interno, 
    ; você pode varrer o buffer_logs aqui se desejar exibi-los.

.fim_leitura:
    pop     rsi
    pop     rdi
    pop     rax
    ret

;=============== FECHAR SISTEMA DE LOGS ====================
fydlog_fechar:
    push    rax
    push    rdi

    cmp byte [inicializado], 1
    je      .fechar
    jmp     .fim

.fechar:
    mov byte [inicializado], 0

.fim:
    pop     rdi
    pop     rax
    ret
