; ======================================
; Kernel FydelisTech OS — FydelTerm v2.0
; + Salto para Sistema Gráfico Qt
; De Salvador • Bahia 🇧🇷
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

; ✅ Funções do terminal e interrupções
extern clear_screen, print_string, print_char, print_newline
extern get_key, reset_buffer, add_char, parse_line
extern interpret_command
extern set_input_base
extern argc, argv, buffer
extern buf_head, buf_tail
extern idt_init            ; 👈 Adicionado
extern interrupts_init     ; 👈 Adicionado

; ✅ Ponto de entrada do sistema gráfico Qt
extern qt_main_entry

; --- DADOS ---
section .data
msg_welcome   db 'FydelTerm v2.0 - Autor: Adiel Santos Fontes',0
msg_opcoes    db 'Escolha: [1] Terminal | [2] Interface Grafica (FydelisTech OS)',0
msg_prompt    db 'Fydelterm> ',0
msg_entrada   db '🚀 Carregando FydelisTech OS...',0

; --- CÓDIGO PRINCIPAL ---
section .text
global start
start:
    ; ✅ Inicializar IDT e APIC/Interrupções de Hardware
    call    idt_init       ; Configura a tabela de interrupções e o teclado
    call    interrupts_init; Configura o APIC/IOAPIC e executa 'sti'

    ; ✅ Limpar a tela e ir direto para o terminal para testar
    call    clear_screen
    jmp     .modo_terminal

.escolha:
    call    get_key
    cmp     al, '1'
    je      .modo_terminal
    cmp     al, '2'
    je      .modo_grafico
    jmp     .escolha

; ======================================
; 🖥️ MODO GRÁFICO — SALTA PARA QT
; ======================================
.modo_grafico:
    lea     rsi, [rel msg_entrada]
    call    print_string
    call    print_newline
    
    ; ✅ Salto para o ambiente Qt → Splash → Login → Desktop
    call    qt_main_entry
    
    ; ✅ Se voltou = usuário encerrou → retorna ao terminal
    lea     rsi, [rel msg_welcome]
    call    print_string
    call    print_newline
    jmp     .modo_terminal

; ======================================
; 💻 MODO TERMINAL — FydelTerm Original
; ======================================
.modo_terminal:
main_loop:
    call    reset_buffer
    lea     rsi, [rel msg_prompt]
    call    print_string
    call    set_input_base

.le_tecla:
    call    get_key
    cmp     al, KEY_NULL
    je      .le_tecla
    cmp     al, KEY_ENTER
    je      .executa
    cmp     al, KEY_BACKSPACE
    je      .trata_bs

    ; Ignora não imprimíveis e armazena caractere normal
    cmp     al, 0x20
    jb      .le_tecla
    cmp     al, 0x7E
    ja      .le_tecla

    push    rax
    call    add_char
    pop     rax
    call    print_char
    jmp     .le_tecla

.trata_bs:
    cmp     dword [rel buf_head], 0
    je      .le_tecla
    mov     al, KEY_BACKSPACE
    call    print_char
    mov     al, ' '
    call    print_char
    mov     al, KEY_BACKSPACE
    call    print_char
    dec     dword [rel buf_head]
    mov     eax, [rel buf_head]
    mov     byte [buffer + rax], 0
    jmp     .le_tecla

.executa:
    call    print_newline
    mov     eax, [rel buf_head]
    mov     byte [buffer + rax], 0    ; Terminador nulo obrigatório
    cmp     dword [rel buf_head], 0
    je      main_loop
    call    parse_line
    call    interpret_command
    jmp     main_loop
.sem_comando:
    call    reset_buffer
    jmp     main_loop
