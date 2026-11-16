; ==========================================
; ESTRUTURA.ASM — Árvore de Diretórios do Sistema
; FydelisTech OS v2.2
; Executado no boot → cria todas as pastas raiz
; Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
default rel

; ========== DEPENDÊNCIAS ==========
; Assume que funções de sistema de arquivos estão disponíveis:
; fs_criar_diretório, fs_caminho_existe, fs_mkdir_p
; Se não existirem, usaremos versões simplificadas abaixo

; ========== ESTRUTURA DE PASTAS ==========
; Lista completa — adicione ou remova conforme necessidade
section .data

; ═══════ RAIZ ═══════
pasta_raiz:         db "/fyd",0

; ═══════ DISCO E ARMAZENAMENTO ═══════
pasta_disco:        db "/fyd/disco",0
pasta_disco_f1:     db "/fyd/disco/fyd1",0
pasta_disco_f2:     db "/fyd/disco/fyd2",0
pasta_usb:          db "/fyd/usb",0
pasta_usb_u1:       db "/fyd/usb/fydu1",0
pasta_usb_u2:       db "/fyd/usb/fydu2",0
pasta_midia:        db "/fyd/midia",0
pasta_rede:         db "/fyd/rede",0

; ═══════ SISTEMA E BINÁRIOS ═══════
pasta_bin:          db "/fyd/bin",0
pasta_lib:          db "/fyd/lib",0
pyd_apps:           db "/fyd/apps",0
pasta_terminal:     db "/fyd/terminal",0
pasta_boot:         db "/fyd/boot",0
pasta_config:       db "/fyd/config",0

; ═══════ USUÁRIO ═══════
pasta_home:         db "/fyd/usuario",0
pasta_documentos:   db "/fyd/usuario/documentos",0
pasta_imagens:      db "/fyd/usuario/imagens",0
pasta_musica:       db "/fyd/usuario/musica",0
pasta_downloads:    db "/fyd/usuario/downloads",0
pasta_area_trabalho:db "/fyd/usuario/area_trabalho",0
pasta_projetos:     db "/fyd/usuario/projetos",0

; ═══════ SEGURANÇA E DADOS ═══════
pasta_secure:       db "/fyd/secure",0
pasta_contas:       db "/fyd/secure/contas",0
pasta_dados:        db "/fyd/dados",0
pasta_logs:         db "/fyd/dados/logs",0
pasta_temas:        db "/fyd/temas",0
pasta_icons:        db "/fyd/temas/icones",0
pasta_estilos:      db "/fyd/temas/estilos",0

; ═══════ REDE E FERRAMENTAS ═══════
pasta_rede_cfg:     db "/fyd/rede/cfg",0
pasta_pentest:      db "/fyd/pentest",0
pasta_relatorios:   db "/fyd/pentest/relatorios",0
pasta_capturas:     db "/fyd/pentest/capturas",0

; ═══════ LISTA PARA PERCORRER ═══════
; Termina com ponteiro nulo
lista_pastas:
    dq pasta_raiz
    dq pasta_disco, pasta_disco_f1, pasta_disco_f2
    dq pasta_usb, pasta_usb_u1, pasta_usb_u2
    dq pasta_midia, pasta_rede
    dq pasta_bin, pasta_lib, pyd_apps, pasta_terminal
    dq pasta_boot, pasta_config
    dq pasta_home, pasta_documentos, pasta_imagens
    dq pasta_musica, pasta_downloads
    dq pasta_area_trabalho, pasta_projetos
    dq pasta_secure, pasta_contas, pasta_dados, pasta_logs
    dq pasta_temas, pasta_icons, pasta_estilos
    dq pasta_rede_cfg, pasta_pentest
    dq pasta_relatorios, pasta_capturas
    dq 0   ; FIM DA LISTA

; Mensagens
msg_criando:        db "📂 Criando estrutura de pastas do sistema...",10,0
msg_ja_existe:      db "  ✅ ",0
msg_criado:         db "  ✅ ",0
msg_erro:           db "  ❌ Erro: ",0
msg_concluido:      db "✅ Estrutura do sistema pronta!",10,0

section .bss
buffer_caminho:     resb 128

section .text

; ========== FUNÇÃO PRINCIPAL — CHAMADA NO BOOT ==========
global construir_estrutura_sistema
construir_estrutura_sistema:
    push rax
    push rbx
    push rsi
    push rdi

    ; Mensagem de início
    lea rsi, [rel msg_criando]
    call print_string

    ; Percorre a lista de pastas
    lea rsi, [rel lista_pastas]
.loop_proxima:
    lodsq
    test rax, rax
    jz .concluido        ; lista terminou

    mov rdi, rax         ; caminho = *rsi++

    ; Verifica se já existe
    call fs_caminho_existe
    test rax, rax
    jnz .ja_tem

    ; Não existe → cria
    mov rdi, rdi
    call fs_criar_diretorio
    test rax, rax
    jz .falha

    ; Sucesso
    lea rsi, [rel msg_criado]
    call print_string
    mov rsi, rdi
    call print_string
    call print_newline
    jmp .loop_proxima

.ja_tem:
    ; Já existe → avisa e segue
    lea rsi, [rel msg_ja_existe]
    call print_string
    mov rsi, rdi
    call print_string
    mov rsi, rel msg_espaco
    call print_string
    mov rsi, rel msg_ja_existe+3
    call print_string
    call print_newline
    jmp .loop_proxima

.falha:
    lea rsi, [rel msg_erro]
    call print_string
    mov rsi, rdi
    call print_string
    call print_newline
    jmp .loop_proxima

.concluido:
    lea rsi, [rel msg_concluido]
    call print_string

    pop rdi
    pop rsi
    pop rbx
    pop rax
    ret

; ========== FUNÇÕES AUXILIARES DE ARQUIVO ==========
; Se o seu kernel já tiver essas funções, pode REMOVER daqui e usar as do sistema

; fs_caminho_existe: rdi=caminho → rax=1 existe, 0 não
global fs_caminho_existe
fs_caminho_existe:
    ; ↓ Substitua pela sua implementação real
    xor rax, rax
    ret

; fs_criar_diretorio: rdi=caminho → rax=1 sucesso, 0 falha
global fs_criar_diretorio
fs_criar_diretorio:
    ; ↓ Substitua pela sua implementação real
    xor rax, rax
    inc rax
    ret

; ========== FUNÇÃO DE LISTAGEM — PARA O COMANDO "listar" ==========
global listar_estrutura
listar_estrutura:
    push rax
    push rsi
    push rdi

    ; Cabeçalho
    mov al,10
    call print_char
    lea rsi, [rel msg_arvore]
    call print_string
    mov al,10
    call print_char

    ; Percorre e mostra
    lea rsi, [rel lista_pastas]
.loop:
    lodsq
    test rax, rax
    jz .fim

    ; Indentação visual
    mov rcx, rax
    mov rdi, [rsi-8]
    call contar_barras
    mov rcx, rax
.indent:
    cmp rcx, 1
    jb .mostra
    push rcx
    mov al, '│'
    call print_char
    mov al, ' '
    call print_char
    pop rcx
    dec rcx
    jmp .indent

.mostra:
    mov al, '├'
    call print_char
    mov al, '─'
    call print_char
    mov al, ' '
    call print_char

    mov rsi, rdi
    call print_string
    call print_newline
    jmp .loop

.fim:
    pop rdi
    pop rsi
    pop rax
    ret

; Conta níveis de pasta (quantas '/')
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

section .data
msg_espaco:      db " - já existe",0
msg_arvore:      db "🌳 ESTRUTURA DE DIRETÓRIOS DO SISTEMA",10, \
                   "──────────────────────────────────────",10,0
