; ======================================
; Kernel FydelisTech OS — FydelTerm v2.0
; + Salto para Sistema Gráfico Qt
; De Salvador • Bahia 🇧🇷
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

; ✅ Funções do terminal
extern clear_screen, print_string, print_char, print_newline
extern get_key, reset_buffer, add_char, parse_line
extern interpret_command
extern set_input_base
extern argc, argv, buffer
extern buf_head, buf_tail

; ✅ Ponto de entrada do sistema gráfico Qt
extern qt_main_entry

; --- DADOS ---
section .data
msg_welcome   db 'FydelTerm v2.0 - Autor: Adiel Santos Fontes',10,0
msg_opcoes    db 'Escolha: [1] Terminal | [2] Interface Gráfica (FydelisTech OS)',10,0
msg_prompt    db 'FydelisTech> ',0
msg_entrada   db '🚀 Carregando FydelisTech OS...',10,0

; --- CÓDIGO PRINCIPAL ---
section .text
global start
start:
    ; ✅ Apresentação
    lea   rsi, [rel msg_welcome]
    call  print_string

    ; ✅ Perguntar modo de inicialização
    lea   rsi, [rel msg_opcoes]
    call  print_string

.escolha:
    call  get_key
    cmp   al, '1'
    je    .modo_terminal
    cmp   al, '2'
    je    .modo_grafico
    jmp   .escolha

; ======================================
; 🖥️ MODO GRÁFICO — SALTA PARA QT
; ======================================
.modo_grafico:
    lea   rsi, [rel msg_entrada]
    call  print_string
    
    ; ✅ Salto para o ambiente Qt → Splash → Login → Desktop
    call  qt_main_entry
    
    ; ✅ Se voltou = usuário encerrou → retorna ao terminal
    lea   rsi, [rel msg_welcome]
    call  print_string
    jmp   .modo_terminal

; ======================================
; 💻 MODO TERMINAL — FydelTerm Original
; ======================================
.modo_terminal:
    ; Continua com o loop do terminal exatamente como estava
main_loop:
    lea   rsi, [rel msg_prompt]
    call  print_string
    call  set_input_base
.le_tecla:
    call  get_key
    cmp   al, KEY_ENTER
    je    .executa
    cmp   al, KEY_NULL
    je    .le_tecla
    cmp   al, KEY_BACKSPACE
    je    .trata_bs
    mov   ah, al
    call  add_char
    mov   al, ah
    call  print_char
    jmp   .le_tecla
.trata_bs:
    mov   ah, al
    call  add_char
    mov   al, ah
    call  print_char
    mov   al, KEY_SPACE
    call  print_char
    mov   al, KEY_BACKSPACE
    call  print_char
    jmp   .le_tecla
.executa:
    call  print_newline
    mov   rax, [buf_head]
    mov   byte [buffer + rax], 0
    cmp   qword [buf_head], 0
    je    .sem_comando
    call  parse_line
    call  interpret_command
.sem_comando:
    call  reset_buffer
    jmp   main_loop