; ============================================================================
; ESTRUTURA.ASM — Arvore de Diretorios do Sistema (/fyd)
; FydelisTech OS v4.2 — Compartilhada entre FydelTerm & Interface Grafica
; Salvador • Bahia
; ============================================================================
BITS 64
default rel

global construir_estrutura_sistema
global listar_estrutura
global fs_caminho_existe
global fs_criar_diretorio
global fs_obter_lista_pastas
global fs_total_pastas
global diretorio_atual

extern print_string
extern print_newline
extern print_char

%define MAX_DIRETORIOS 64

section .data

; ═══════ RAIZ & RUNTIME ═══════
pasta_raiz:          db "/fyd", 0
pasta_tmp:           db "/fyd/tmp", 0
pasta_dev:           db "/fyd/dev", 0

; ═══════ DISCO E ARMAZENAMENTO ═══════
pasta_disco:         db "/fyd/disco", 0
pasta_disco_f1:      db "/fyd/disco/fyd1", 0
pasta_disco_f2:      db "/fyd/disco/fyd2", 0
pasta_usb:           db "/fyd/usb", 0
pasta_usb_u1:        db "/fyd/usb/fydu1", 0
pasta_usb_u2:        db "/fyd/usb/fydu2", 0
pasta_midia:         db "/fyd/midia", 0
pasta_rede:          db "/fyd/rede", 0

; ═══════ SISTEMA E BINARIOS ═══════
pasta_bin:           db "/fyd/bin", 0
pasta_lib:           db "/fyd/lib", 0
pasta_apps:          db "/fyd/apps", 0
pasta_terminal:      db "/fyd/terminal", 0
pasta_boot:          db "/fyd/boot", 0
pasta_config:        db "/fyd/config", 0

; ═══════ USUARIO ═══════
pasta_home:          db "/fyd/usuario", 0
pasta_documentos:    db "/fyd/usuario/documentos", 0
pasta_imagens:       db "/fyd/usuario/imagens", 0
pasta_musica:        db "/fyd/usuario/musica", 0
pasta_downloads:     db "/fyd/usuario/downloads", 0
pasta_area_trabalho: db "/fyd/usuario/area_trabalho", 0
pasta_projetos:      db "/fyd/usuario/projetos", 0

; ═══════ SEGURANCA E DADOS ═══════
pasta_secure:        db "/fyd/secure", 0
pasta_contas:        db "/fyd/secure/contas", 0
pasta_dados:         db "/fyd/dados", 0
pasta_logs:          db "/fyd/dados/logs", 0
pasta_temas:         db "/fyd/temas", 0
pasta_icons:         db "/fyd/temas/icones", 0
pasta_estilos:       db "/fyd/temas/estilos", 0

; ═══════ REDE E FERRAMENTAS ═══════
pasta_rede_cfg:      db "/fyd/rede/cfg", 0
pasta_pentest:       db "/fyd/pentest", 0
pasta_relatorios:    db "/fyd/pentest/relatorios", 0
pasta_capturas:      db "/fyd/pentest/capturas", 0

; ═══════ LISTA MESTRE DE INICIALIZACAO ═══════
lista_pastas:
    dq pasta_raiz, pasta_tmp, pasta_dev
    dq pasta_disco, pasta_disco_f1, pasta_disco_f2
    dq pasta_usb, pasta_usb_u1, pasta_usb_u2
    dq pasta_midia, pasta_rede
    dq pasta_bin, pasta_lib, pasta_apps, pasta_terminal
    dq pasta_boot, pasta_config
    dq pasta_home, pasta_documentos, pasta_imagens
    dq pasta_musica, pasta_downloads
    dq pasta_area_trabalho, pasta_projetos
    dq pasta_secure, pasta_contas, pasta_dados, pasta_logs
    dq pasta_temas, pasta_icons, pasta_estilos
    dq pasta_rede_cfg, pasta_pentest
    dq pasta_relatorios, pasta_capturas
    dq 0    ; FIM DA LISTA

; Mensagens (ASCII puro compativel com VGA e VESA)
msg_criando:         db "[*] Montando arvore de diretorios /fyd...", 10, 0
msg_ok_prefixo:      db "  [OK] ", 0
msg_ja_existe:       db " (ativo)", 0
msg_erro:            db "  [ERRO] Falha ao registrar: ", 0
msg_concluido:       db "[OK] Estrutura /fyd pronta! CWD inicial: /fyd/usuario", 10, 0
msg_arvore:          db "ESTRUTURA DE DIRETORIOS DO SISTEMA (/fyd)", 10, \
                        "-----------------------------------------", 10, 0

section .bss
tabela_diretorios:   resq MAX_DIRETORIOS   ; Ponteiros para os diretorios ativos
total_diretorios:    resq 1                ; Quantidade total registrada
diretorio_atual:     resb 128              ; Diretorio corrente (CWD) da sessao

section .text

; ============================================================================
; CONSTRUIR ESTRUTURA NO BOOT
; Deve ser chamada pelo kernel antes de exibir o menu [1] / [2]
; ============================================================================
construir_estrutura_sistema:
    push rax
    push rbx
    push rsi
    push rdi

    lea rsi, [rel msg_criando]
    call print_string

    lea rbx, [rel lista_pastas]

.loop_proxima:
    mov rdi, [rbx]
    test rdi, rdi
    jz .concluido

    call fs_caminho_existe
    test rax, rax
    jnz .ja_tem

    call fs_criar_diretorio
    test rax, rax
    jz .falha

    lea rsi, [rel msg_ok_prefixo]
    call print_string
    mov rsi, rdi
    call print_string
    call print_newline
    jmp .avancar

.ja_tem:
    lea rsi, [rel msg_ok_prefixo]
    call print_string
    mov rsi, rdi
    call print_string
    lea rsi, [rel msg_ja_existe]
    call print_string
    call print_newline
    jmp .avancar

.falha:
    lea rsi, [rel msg_erro]
    call print_string
    mov rsi, rdi
    call print_string
    call print_newline

.avancar:
    add rbx, 8
    jmp .loop_proxima

.concluido:
    ; Define o diretorio inicial da sessao como "/fyd/usuario"
    lea rsi, [rel pasta_home]
    lea rdi, [rel diretorio_atual]
.copia_cwd:
    lodsb
    stosb
    test al, al
    jnz .copia_cwd

    lea rsi, [rel msg_concluido]
    call print_string

    pop rdi
    pop rsi
    pop rbx
    pop rax
    ret

; ============================================================================
; FS_CAMINHO_EXISTE: rdi = ponteiro string -> rax = 1 existe, 0 nao
; ============================================================================
fs_caminho_existe:
    push rbx
    push rcx
    push rsi
    push rdi

    mov rcx, [rel total_diretorios]
    test rcx, rcx
    jz .nao_existe

    lea rbx, [rel tabela_diretorios]
.busca:
    mov rsi, [rbx]
    push rdi
    call comparar_strings
    pop rdi
    test rax, rax
    jnz .encontrado

    add rbx, 8
    dec rcx
    jnz .busca

.nao_existe:
    xor rax, rax
    jmp .sair

.encontrado:
    mov rax, 1

.sair:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ============================================================================
; FS_CRIAR_DIRETORIO: rdi = ponteiro string -> rax = 1 sucesso, 0 falha
; ============================================================================
fs_criar_diretorio:
    push rbx
    push rcx

    mov rcx, [rel total_diretorios]
    cmp rcx, MAX_DIRETORIOS
    jge .cheio

    lea rbx, [rel tabela_diretorios]
    mov [rbx + rcx * 8], rdi
    inc qword [rel total_diretorios]

    mov rax, 1
    jmp .sair

.cheio:
    xor rax, rax

.sair:
    pop rcx
    pop rbx
    ret

; ============================================================================
; INTERFACE PARA C (exec.c — Gerenciador de Arquivos Grafico)
; ============================================================================
fs_obter_lista_pastas:
    lea rax, [rel tabela_diretorios]
    ret

fs_total_pastas:
    mov rax, [rel total_diretorios]
    ret

; ============================================================================
; LISTAR ESTRUTURA (Comando "listar" / "arvore" no FydelTerm)
; ============================================================================
listar_estrutura:
    push rax
    push rbx
    push rcx
    push rsi
    push rdi

    call print_newline
    lea rsi, [rel msg_arvore]
    call print_string

    mov rcx, [rel total_diretorios]
    test rcx, rcx
    jz .fim

    lea rbx, [rel tabela_diretorios]

.loop:
    mov rdi, [rbx]
    push rcx

    call contar_barras
    mov rcx, rax
.indent:
    cmp rcx, 1
    jbe .mostra
    mov al, '|'
    call print_char
    mov al, ' '
    call print_char
    dec rcx
    jmp .indent

.mostra:
    mov al, '+'
    call print_char
    mov al, '-'
    call print_char
    mov al, ' '
    call print_char

    mov rsi, rdi
    call print_string
    call print_newline

    pop rcx
    add rbx, 8
    dec rcx
    jnz .loop

.fim:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; UTILITARIOS INTERNOS
; ============================================================================
contar_barras:
    xor rax, rax
    mov rsi, rdi
.conta:
    lodsb
    test al, al
    jz .fim
    cmp al, '/'
    jne .conta
    inc rax
    jmp .conta
.fim:
    ret

comparar_strings:
    push rsi
    push rdi
.cmp_loop:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, ah
    jne .diferente
    test al, al
    jz .igual
    inc rsi
    inc rdi
    jmp .cmp_loop
.diferente:
    xor rax, rax
    jmp .fim
.igual:
    mov rax, 1
.fim:
    pop rdi
    pop rsi
    ret
