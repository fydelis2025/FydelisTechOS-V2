; ==========================================
; HOSTS_MGR.ASM — Tabela Nome ↔ IP
; FydelisTechOS v2.2 · Sistema PRÓPRIO — Letras A:→Z:
; NÃO depende de Linux nem Windows!
; ==========================================
BITS 64
default rel
%include "fydelterm.inc"

; 📂 Arquivo fica na unidade do sistema, pasta Sistema
HOSTS_ARQUIVO  equ "Sistema/hosts.fyd"

; 📦 Estrutura de memória
MAX_ENTRADAS   equ 64
TAM_IP         equ 16
TAM_NOME       equ 64

struc EntradaHost
    .ip:      resb TAM_IP
    .nome:    resb TAM_NOME
    .proximo: resq 1
endstruc

; 📤 Funções externas
extern arquivo_abrir
extern arquivo_ler_linha
extern arquivo_escrever_linha
extern arquivo_fechar
extern arquivo_existe
extern arquivo_criar
extern strcmp
extern strcpy
extern strlen
extern print_string
extern print_newline
extern obter_unidade_sistema   ; Retorna letra ex: 'C'

; 📤 Exportação
global hosts_inicializar
global hosts_listar
global hosts_adicionar
global hosts_remover
global hosts_resolver

section .data
mensagem_cabecalho:  db "=== Tabela de Nomes da Rede ===", 10, 0
mensagem_naoencontr: db "Nao encontrado: ", 0
mensagem_cheio:      db "Tabela de hosts cheia!", 10, 0
mensagem_criado:     db "[OK] Arquivo de hosts criado", 10, 0
cabecalho_arquivo:   db "; Arquivo de Hosts - FydelisTechOS v2.2", 10, 0
espaco_str:          db " ", 0
newline_str:         db 10, 0

; Modelo do caminho: 1º byte é substituído pela letra da unidade
modelo_caminho:      db "X:/Sistema/hosts.fyd", 0

section .bss
buffer_caminho:      resb 64
ponteiro_arquivo:    resq 1
unidade_sistema:     resb 1
entradas_carregadas: resd 1

; ✅ A TABELA DE ENTRADAS (faltava no original!)
entradas:            resb MAX_ENTRADAS * EntradaHost_size

linha_atual:         resb 128

section .text

; ==========================================
; hosts_inicializar() — Carrega ou cria o arquivo
; ==========================================
hosts_inicializar:
    push rbx
    push r12

    ; 📝 Descobrir letra da unidade do sistema
    call obter_unidade_sistema
    mov [unidade_sistema], al

    ; 📝 Montar caminho: "C:/Sistema/hosts.fyd"
    ;    Copiar modelo e substituir o 'X' pela letra real
    mov rsi, modelo_caminho
    mov rdi, buffer_caminho
.copiar_caminho:
    lodsb
    stosb
    test al, al
    jnz .copiar_caminho
    mov al, [unidade_sistema]
    mov [buffer_caminho], al

    ; 📝 Verificar se existe
    mov rdi, buffer_caminho
    call arquivo_existe
    test rax, rax
    jnz .carregar

    ; 🆕 Não existe → criar arquivo padrão
    mov rdi, buffer_caminho
    call arquivo_criar
    mov rsi, mensagem_criado
    call print_string
    call print_newline

.carregar:
    ; ✅ Carregar entradas para memória
    mov rdi, buffer_caminho
    xor rsi, rsi        ; modo leitura
    call arquivo_abrir
    mov [ponteiro_arquivo], rax

    mov dword [entradas_carregadas], 0

.ler_linha:
    mov rdi, [ponteiro_arquivo]
    mov rsi, linha_atual
    mov rdx, 128
    call arquivo_ler_linha
    test rax, rax
    jz .fim_carregamento

    ; Ignorar linhas vazias e comentários
    cmp byte [linha_atual], ';'
    je .ler_linha
    cmp byte [linha_atual], '#'
    je .ler_linha
    cmp byte [linha_atual], 0
    je .ler_linha

    ; Analisar linha: IP + NOME
    mov rdi, linha_atual
    call parsear_linha_hosts
    jmp .ler_linha

.fim_carregamento:
    mov rdi, [ponteiro_arquivo]
    call arquivo_fechar

    pop r12
    pop rbx
    ret

; ==========================================
; hosts_listar() — Exibe todas as entradas
; ==========================================
hosts_listar:
    push rbx
    push rsi

    mov rsi, mensagem_cabecalho
    call print_string

    ; rbx = ponteiro para a entrada atual
    lea rbx, [rel entradas]
.listar_loop:
    lea rax, [rel entradas + MAX_ENTRADAS * EntradaHost_size]
    cmp rbx, rax
    jae .fim

    ; Se entrada usada → exibir
    cmp byte [rbx + EntradaHost.ip], 0
    jz .proximo

    ; Formato: "IP              NOME"
    ; (imprime IP, preenche com espaços até 16 colunas, depois nome)
    lea rsi, [rbx + EntradaHost.ip]
    call print_string
    lea rdi, [rbx + EntradaHost.ip]
    call strlen
    mov rcx, 15
    sub rcx, rax            ; espaços de preenchimento
    jg .preencher
    xor rcx, rcx
.preencher:
    mov rsi, espaco_str
    test rcx, rcx
    jz .nome
    push rcx
    call print_string
    pop rcx
    loop .preencher
.nome:
    lea rsi, [rbx + EntradaHost.nome]
    call print_string
    call print_newline

.proximo:
    add rbx, EntradaHost_size
    jmp .listar_loop

.fim:
    pop rsi
    pop rbx
    ret

; ==========================================
; hosts_adicionar(ip, nome) — Adiciona entrada
; rdi = ponteiro para string IP
; rsi = ponteiro para string nome
; retorna: 0 = OK, -1 = tabela cheia
; ==========================================
hosts_adicionar:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi            ; r12 = IP do usuário
    mov r13, rsi            ; r13 = Nome do usuário

    ; Procurar entrada vazia ou mesmo nome para substituir
    lea rbx, [rel entradas]
    xor r14d, r14d          ; índice
.procurar:
    cmp r14d, MAX_ENTRADAS
    jae .cheio

    cmp byte [rbx + EntradaHost.nome], 0
    jz .encontrado_livre

    ; Já existe esse nome? → comparar
    mov rdi, r13
    lea rsi, [rbx + EntradaHost.nome]
    call strcmp
    test rax, rax
    jz .substituir

    add rbx, EntradaHost_size
    inc r14d
    jmp .procurar

.encontrado_livre:
    inc dword [rel entradas_carregadas]

.substituir:
    ; Copiar IP:  strcpy(dst=rbx+ip, src=r12)
    lea rdi, [rbx + EntradaHost.ip]
    mov rsi, r12
    call strcpy
    ; Copiar Nome: strcpy(dst=rbx+nome, src=r13)
    lea rdi, [rbx + EntradaHost.nome]
    mov rsi, r13
    call strcpy

    ; Salvar no disco
    call salvar_arquivo
    xor eax, eax
    jmp .fim

.cheio:
    mov rsi, mensagem_cheio
    call print_string
    call print_newline
    mov rax, -1

.fim:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ==========================================
; hosts_remover(nome) — Apaga entrada
; rdi = nome; retorna 0 = OK, -1 = não encontrado
; ==========================================
hosts_remover:
    push rbx
    push r12

    mov r12, rdi

    lea rbx, [rel entradas]
    xor ecx, ecx
.procurar:
    cmp ecx, MAX_ENTRADAS
    jae .naoencontrado

    cmp byte [rbx + EntradaHost.nome], 0
    jz .proximo

    mov rdi, r12
    lea rsi, [rbx + EntradaHost.nome]
    call strcmp
    test rax, rax
    jz .apagar

.proximo:
    add rbx, EntradaHost_size
    inc ecx
    jmp .procurar

.apagar:
    ; Zera os primeiros bytes de IP e Nome (marca como livre)
    mov byte [rbx + EntradaHost.ip], 0
    mov byte [rbx + EntradaHost.nome], 0
    dec dword [rel entradas_carregadas]
    call salvar_arquivo
    xor eax, eax
    jmp .fim

.naoencontrado:
    mov rax, -1

.fim:
    pop r12
    pop rbx
    ret

; ==========================================
; hosts_resolver(nome) → ponteiro para IP ou 0
; ==========================================
hosts_resolver:
    push rbx
    push r12

    mov r12, rdi

    lea rbx, [rel entradas]
    xor ecx, ecx
.procurar:
    cmp ecx, MAX_ENTRADAS
    jae .naoencontrado

    cmp byte [rbx + EntradaHost.nome], 0
    jz .proximo

    mov rdi, r12
    lea rsi, [rbx + EntradaHost.nome]
    call strcmp
    test rax, rax
    jz .encontrado

.proximo:
    add rbx, EntradaHost_size
    inc ecx
    jmp .procurar

.encontrado:
    lea rax, [rbx + EntradaHost.ip]
    jmp .fim

.naoencontrado:
    xor eax, eax

.fim:
    pop r12
    pop rbx
    ret

; ==========================================
; salvar_arquivo — Reescreve todo o arquivo
; ==========================================
salvar_arquivo:
    push rbx

    mov rdi, buffer_caminho
    mov rsi, 1              ; modo escrita
    call arquivo_abrir
    mov [ponteiro_arquivo], rax

    ; Cabeçalho
    mov rdi, [ponteiro_arquivo]
    mov rsi, cabecalho_arquivo
    call arquivo_escrever_linha

    ; Entradas
    lea rbx, [rel entradas]
.escrever_loop:
    lea rax, [rel entradas + MAX_ENTRADAS * EntradaHost_size]
    cmp rbx, rax
    jae .fim

    cmp byte [rbx + EntradaHost.ip], 0
    jz .proximo

    ; Linha: "IP NOME"
    mov rdi, [ponteiro_arquivo]
    lea rsi, [rbx + EntradaHost.ip]
    call arquivo_escrever_linha
    mov rdi, [ponteiro_arquivo]
    mov rsi, espaco_str
    call arquivo_escrever_linha
    mov rdi, [ponteiro_arquivo]
    lea rsi, [rbx + EntradaHost.nome]
    call arquivo_escrever_linha
    mov rdi, [ponteiro_arquivo]
    mov rsi, newline_str
    call arquivo_escrever_linha

.proximo:
    add rbx, EntradaHost_size
    jmp .escrever_loop

.fim:
    mov rdi, [ponteiro_arquivo]
    call arquivo_fechar
    pop rbx
    ret

; ==========================================
; parsear_linha_hosts — rdi = linha
; Formato: "IP NOME" → grava na tabela em memória
; ==========================================
parsear_linha_hosts:
    push rbx
    push r12
    push r13

    mov r12, rdi            ; r12 = linha

    ; Achar slot livre
    lea rbx, [rel entradas]
    xor ecx, ecx
.achar_slot:
    cmp ecx, MAX_ENTRADAS
    jae .fim
    cmp byte [rbx + EntradaHost.ip], 0
    jz .slot_achado
    add rbx, EntradaHost_size
    inc ecx
    jmp .achar_slot
.slot_achado:
    inc dword [rel entradas_carregadas]

    ; Extrair IP: copiar até espaço ou fim
    mov rsi, r12
    lea rdi, [rbx + EntradaHost.ip]
    mov rcx, TAM_IP - 1
.copiar_ip:
    mov al, [rsi]
    cmp al, ' '
    je .fim_ip
    cmp al, 0
    je .fim_ip
    mov [rdi], al
    inc rdi
    inc rsi
    loop .copiar_ip
.fim_ip:
    mov byte [rdi], 0

    ; Pular espaços
.pular_espacos:
    cmp byte [rsi], ' '
    jne .copiar_nome
    inc rsi
    jmp .pular_espacos

    ; Extrair Nome: copiar até fim
.copiar_nome:
    lea rdi, [rbx + EntradaHost.nome]
    mov rcx, TAM_NOME - 1
.copiar_nome_loop:
    mov al, [rsi]
    cmp al, 0
    je .fim_nome
    mov [rdi], al
    inc rdi
    inc rsi
    loop .copiar_nome_loop
.fim_nome:
    mov byte [rdi], 0

.fim:
    pop r13
    pop r12
    pop rbx
    ret
