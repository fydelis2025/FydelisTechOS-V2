; ======================================
; INTERPRETADOR DE COMANDOS — FYDELTERM v2.2 (PARTE 1)
; Núcleo + Disco/Partições + Rede + WiFi
; Letras A:-Z: · MBR/GPT Auto · FydelisTech OS
; Salvador • Bahia 🇧🇷
; ======================================
BITS 64
default rel

%include "fydelterm.inc"

; ========== EXTERNAIS GERAIS ==========
extern clear_screen, print_string, print_newline, print_char, get_key, set_color
extern strcmpi, int_para_str
extern listar_unidades, criar_unidade, remover_unidade, formatar_unidade
extern obter_tamanho_disco, inicializar_disco
extern sys_bt_scan, sys_bt_conectar, sys_bt_desconectar
extern usb_listar_dispositivos
extern do_fydel, do_pentest
extern fydlog_ler_todos
extern fydlog_escrever
extern kernel_exec_bin
extern construir_estrutura_sistema
extern listar_estrutura

extern wifi_scan_lista
extern WifiRede_size
%define WifiRede.ssid 0
%define WifiRede.seguranca 8

extern fb_inicializar
extern gpu_inicializar_todos
extern ws_inicializar

extern do_desligar
extern do_reiniciar
extern do_sair

; ========== EXTERNAIS — SISTEMA DE ARQUIVOS ==========
extern fs_inicializar
extern fs_listar_dir, fs_criar_pasta, fs_remover, fs_copiar

; ========== EXTERNAIS — REDE & WIFI & DHCP ==========
extern rede_exec_ping
extern rede_exec_traceroute
extern rede_ler_iface_nome
extern rede_ler_mac
extern rede_ler_ip
extern rede_ler_mascara
extern rede_ler_gateway
extern rede_ler_dns
extern rede_ler_status_link
extern rede_ler_bytes_rx, rede_ler_bytes_tx
extern rede_ler_tabela_arp
extern rx_bytes_total, tx_bytes_total
extern dhcp_exec
extern dhcp_cliente_iniciar
extern dhcp_ip_atual
extern dhcp_servidor_iniciar
extern dhcp_servidor_status
extern dhcp_servidor_ativo
extern ip_para_string
extern print_num
extern wifi_detectar_placa
extern wifi_inicializar
extern sys_wifi_scan
extern sys_wifi_conectar
extern sys_wifi_desconectar
extern wifi_ler_status

; ========== EXTERNAIS — DADOS DO SHELL ==========
extern mapa_unidades, argc, argv

; ========== EXPORTAÇÕES GLOBAIS ==========
global interpret_command
global do_cls, do_echo, do_help, do_ver, do_exit, do_reboot
global do_login, do_criar_pasta, do_remover, do_copiar, do_listar
global do_mkpart, do_rmpart, do_format, do_fstype
global do_bootmode, do_blkid, do_df, do_fsinfo
global do_bt, do_usb
global cmd_ping, cmd_traceroute, cmd_dhcp, cmd_status_rede, cmd_arp
global cmd_wifi, cmd_limpar_rede, cmd_dhcp_servidor, cmd_fydlog

; ========== MENSAGENS E TEXTOS (.rodata) ==========
section .rodata
msg_ping_uso:       db 'Uso: ping <ip>',0
msg_ping_ok:        db 'Resposta recebida!',0
msg_ping_fail:      db 'Sem resposta.',0
msg_dhcp_aguarde:   db 'Solicitando IP via DHCP...',0
msg_dhcp_ok:        db 'IP obtido com sucesso! ',0
msg_dhcp_fail:      db 'Falha no DHCP.',0
msg_rede_titulo:    db '=== Status da Rede ===',0
msg_rede_iface:     db 'Interface: ',0
msg_rede_mac:       db 'MAC: ',0
msg_rede_ip:        db 'IP: ',0
msg_rede_mask:      db 'Mascara: ',0
msg_rede_gw:        db 'Gateway: ',0
msg_rede_dns:       db 'DNS: ',0
msg_rede_link_up:   db 'Link: Ativo',0
msg_rede_link_down: db 'Link: Desconectado',0
msg_rede_rx:        db 'RX: ',0
msg_rede_tx:        db 'TX: ',0
msg_arp_vazio:      db 'Tabela ARP vazia.',0
msg_limpo:          db 'Buffers de rede limpos.',0
msg_bytes:          db ' bytes',0
msg_sep:            db ' / ',0

str_cls:        db 'cls',0
str_clear:      db 'limpar',0
str_echo:       db 'dizer',0
str_help:       db 'ajuda',0
str_ver:        db 'versao',0
str_exit:       db 'sair',0
str_reboot:     db 'reiniciar',0
str_poweroff:   db 'desligar',0
str_login:      db 'login',0
str_mkpart:     db 'mkpart',0
str_rmpart:     db 'rmpart',0
str_format:     db 'format',0
str_fstype:     db 'fstype',0
str_bootmode:   db 'bootmode',0
str_blkid:      db 'blkid',0
str_df:         db 'df',0
str_fsinfo:     db 'fsinfo',0
str_bt:         db 'bt',0
str_usb:        db 'usb',0
str_fydel:      db 'fydel',0
str_pentest:    db 'pentest',0
str_criar_pasta:db 'criar_pasta',0
str_remover:    db 'remover',0
str_copiar:     db 'copiar',0
str_listar:     db 'listar',0
str_ping_cmd:   db 'ping',0
str_trac_cmd:   db 'traceroute',0
str_dhcp_cmd:   db 'dhcp',0
str_status_cmd: db 'status_rede',0
str_arp_cmd:    db 'arp',0
str_wifi_cmd:   db 'wifi',0
str_limpar_cmd: db 'limpar_rede',0
str_dhcp_serv:  db 'dhcp_servidor',0

str_scan:       db 'scan',0
str_conectar:   db 'conectar',0
str_desconectar:db 'desconectar',0

str_fydlog      db 'fydlog', 0

ajuda_cls:      db 'cls / limpar - Limpa a tela do terminal',0
ajuda_echo:     db 'dizer <texto> - Exibe texto na tela',0
ajuda_help:     db 'ajuda - Lista todos os comandos disponiveis',0
ajuda_ver:      db 'versao - Exibe versao do sistema',0
ajuda_exit:     db 'sair - Encerra sessao do terminal',0
ajuda_reboot:   db 'reiniciar - Reinicia o sistema',0
ajuda_poweroff: db 'desligar - Desliga o sistema',0
ajuda_login:    db 'login USUARIO SENHA - Autenticacao',0
ajuda_mkpart:   db 'mkpart LETRA: TAMANHO - Ex: mkpart C: 50G',0
ajuda_rmpart:   db 'rmpart LETRA: - Remove unidade. Ex: rmpart D:',0
ajuda_format:   db 'format LETRA: SISTEMA - Ex: format E: exFAT',0
ajuda_fstype:   db 'fstype LETRA: - Mostra sistema de arquivos',0
ajuda_bootmode: db 'bootmode - Mostra MBR ou GPT',0
ajuda_blkid:    db 'blkid - Lista unidades e discos',0
ajuda_df:       db 'df - Espaco total/livre nas unidades',0
ajuda_fsinfo:   db 'fsinfo - Informacoes detalhadas do disco',0
ajuda_bt:       db 'bt scan/conectar/desconectar - Gerencia Bluetooth',0
ajuda_usb:      db 'usb - Lista dispositivos USB',0
ajuda_fydel:    db 'fydel [arquivo] - Editor de texto',0
ajuda_pentest:  db 'pentest - Suite de Seguranca FydelisTech',0
ajuda_criar_pasta:db 'criar_pasta <nome> - Cria diretorio',0
ajuda_remover:  db 'remover <arquivo> - Apaga arquivo/pasta',0
ajuda_copiar:   db 'copiar <origem> <destino> - Copia arquivos',0
ajuda_listar:   db 'listar - Lista arquivos do diretorio',0
ajuda_wifi:     db 'wifi <lista|conectar|desconectar|status> - Gerencia WiFi',0
ajuda_dhcp_serv:db 'dhcp_servidor <iniciar|parar|status> - Servidor DHCP local',0
ajuda_fydlog    db 'fydlog - Exibir log', 0

msg_unknown:    db 'Comando nao reconhecido. Digite "ajuda".',10,0
msg_disco_gpt   db "=== Unidade com Tabela GPT Ativa ===", 0
msg_ver:        db 'FydelTerm OS v2.2 · Salvador-BA · x86_64 · MBR/GPT Auto',10,0
msg_bye:        db 'Sessao encerrada.',10,0
msg_help_head:  db '=== COMANDOS DO FYDELTERM ===',10,0
msg_pausa:      db '-- Pressione qualquer tecla para ver mais --',0
msg_part_ok:    db 'Unidade criada: ',0
msg_part_del:   db 'Unidade removida: ',0
msg_fmt_ok:     db 'Sistema aplicado: ',0
msg_letra_inv:  db 'Letra invalida! Use: A: B: C: ... Z:',10,0
msg_erro_op:    db 'Erro na operacao.',10,0
msg_fs_leg:     db 'Modo de Boot: MBR (Legacy BIOS)',10,0
msg_fs_gpt:     db 'Modo de Boot: GPT (UEFI)',10,0
msg_fat32:      db 'FAT32',0
msg_exfat:      db 'exFAT',0
msg_fydfs:      db 'FydelisFS',0
msg_disco_tb:   db 'Disco maior que 2 TB -> usando GPT automaticamente',10,0
msg_disco_mbr:  db 'Disco <= 2 TB -> usando MBR',10,0
msg_login_ok:   db 'Sessao iniciada com sucesso!',10,0
msg_aguarde:    db 'Iniciando o modo Grafico do FydeliTechOS!',10,0
msg_login_erro: db 'Usuario ou senha invalidos.',10,0
msg_bt_uso:     db 'Uso: bt scan | bt conectar <id> | bt desconectar <id>',10,0
df_cab:         db 'UNIDADE    TOTAL    LIVRE    SISTEMA',10, \
                '-----------------------------------',10,0

; ========== BUFFERS (.bss) ==========
section .bss
align 16
ip_buf:         resb 16
mac_buf:        resb 18
buffer_conv:    resb 32
diretorio_atual:resb 256

; ========== CONSTANTES ==========
MBR_TIPO_FAT32       equ 0x0B
MBR_TIPO_FAT32_LBA   equ 0x0C
MBR_TIPO_EXFAT       equ 0x07
MBR_TIPO_EFI         equ 0xEF
LIMIAR_GPT_SETORES   equ 4000000000
MAX_REDES            equ 32

; ========== TABELA DE COMANDOS ==========
section .data
align 16
cmd_table:
    dq str_cls,         do_cls,         ajuda_cls
    dq str_clear,       do_cls,         ajuda_cls
    dq str_echo,        do_echo,        ajuda_echo
    dq str_help,        do_help,        ajuda_help
    dq str_ver,         do_ver,         ajuda_ver
    dq str_exit,        do_exit,        ajuda_exit
    dq str_reboot,      do_reboot,      ajuda_reboot
    dq str_poweroff,    do_poweroff,    ajuda_poweroff
    dq str_login,       do_login,       ajuda_login
    dq str_mkpart,      do_mkpart,      ajuda_mkpart
    dq str_rmpart,      do_rmpart,      ajuda_rmpart
    dq str_format,      do_format,      ajuda_format
    dq str_fstype,      do_fstype,      ajuda_fstype
    dq str_bootmode,    do_bootmode,    ajuda_bootmode
    dq str_blkid,       do_blkid,       ajuda_blkid
    dq str_df,          do_df,          ajuda_df
    dq str_fsinfo,      do_fsinfo,      ajuda_fsinfo
    dq str_bt,          do_bt,          ajuda_bt
    dq str_usb,         do_usb,         ajuda_usb
    dq str_fydel,       do_fydel,       ajuda_fydel
    dq str_pentest,     do_pentest,     ajuda_pentest
    dq str_criar_pasta, do_criar_pasta, ajuda_criar_pasta
    dq str_remover,     do_remover,     ajuda_remover
    dq str_copiar,      do_copiar,      ajuda_copiar
    dq str_listar,      do_listar,      ajuda_listar
    dq str_ping_cmd,    cmd_ping,       msg_ping_uso
    dq str_trac_cmd,    cmd_traceroute, msg_ping_uso
    dq str_dhcp_cmd,    cmd_dhcp,       msg_ping_uso
    dq str_status_cmd,  cmd_status_rede,msg_rede_titulo
    dq str_arp_cmd,     cmd_arp,        msg_arp_vazio
    dq str_wifi_cmd,    cmd_wifi,       ajuda_wifi
    dq str_limpar_cmd,  cmd_limpar_rede,msg_limpo
    dq str_dhcp_serv,   cmd_dhcp_servidor, ajuda_dhcp_serv
    dq str_fydlog,      cmd_fydlog,     ajuda_fydlog
    dq 0,               0,              0

; ========== INTERPRETADOR PRINCIPAL (.text) ==========
section .text
interpret_command:
    push rbx
    push rsi
    push rdi

    mov rax, [argc]
    cmp rax, 0
    jle .fim

    mov rdi, [argv]
    mov rsi, str_fydel
    call strcmpi
    test rax, rax
    jz .chama_fydel

    mov rbx, cmd_table
.busca:
    mov rsi, [rbx]
    test rsi, rsi
    jz .nao_encontrado
    mov rdi, [argv]
    call strcmpi
    test rax, rax
    jz .encontrado
    add rbx, 24
    jmp .busca

.encontrado:
    mov rax, [rbx + 8]
    test rax, rax
    jz .fim
    call rax
    jmp .fim

.chama_fydel:
    call do_fydel
    jmp .fim

.nao_encontrado:
    mov rsi, [argv]
    call print_string
    call print_newline
    lea rsi, [rel msg_unknown]
    call print_warning
    call print_newline

.fim:
    pop rdi
    pop rsi
    pop rbx
    ret

; ========== AJUDA ==========
do_help:
    push rbx
    push rsi
    push rdi

    mov rdi, 0x0E
    call set_color

    xor rcx, rcx
    lea rsi, [rel msg_help_head]
    call print_string
    call print_newline
    lea rbx, [rel cmd_table]
.loop:
    mov rsi, [rbx]
    test rsi, rsi
    jz .fim
    inc rcx
    cmp rcx, 20
    jl .imp
    lea rsi, [rel msg_pausa]
    call print_string
    call get_key
    call print_newline
    xor rcx, rcx
.imp:
    mov al, ' '
    call print_char
    mov al, ' '
    call print_char
    mov rsi, [rbx]
    call print_string
    mov al, ' '
    call print_char
    mov al, '-'
    call print_char
    mov al, ' '
    call print_char
    mov rsi, [rbx + 16]
    call print_string
    call print_newline
    add rbx, 24
    jmp .loop
.fim:
    mov rdi, DEF_ATTR
    call set_color

    pop rdi
    pop rsi
    pop rbx
    ret

; ========== COMANDOS BÁSICOS ==========
do_cls:
    call clear_screen
    ret

do_echo:
    mov rax, [argc]
    cmp rax, 2
    jl .fim
    mov rsi, [argv + 8]
    call print_string
    call print_newline
.fim:
    ret

do_ver:
    lea rsi, [rel msg_ver]
    call print_success
    ret

do_exit:
    lea rsi, [rel msg_bye]
    call print_success
    call print_newline
    cli
.halt:
    hlt
    jmp .halt

do_reboot:
    push rax
    push rdx

    lea rsi, [rel msg_rebooting]
    call print_string
    call print_newline

    mov dx, 0x64
.esp1:
    in al, dx
    test al, 2
    jnz .esp1
    mov al, 0xFE
    out dx, al

    cli
.reboot_espera:
    hlt
    jmp .reboot_espera

section .rodata
msg_rebooting: db "🔄 Reiniciando o sistema...",0

; ==========================================
; 🔌 DESLIGAR SISTEMA
; ==========================================
do_poweroff:
    push rax
    push rdx

    lea rsi, [rel msg_power_off]
    call print_string
    call print_newline

    mov dx, 0x604
    xor eax, eax
    out dx, eax

    mov dx, 0x64
    mov al, 0xD1
    out dx, al
    mov dx, 0x60
    mov al, 0
    out dx, al

    cli
.parar:
    hlt
    jmp .parar

section .rodata
msg_power_off: db "🔌 Desligando o sistema...",0

; ==========================================
; 📋 COMANDO: listar
; ==========================================
do_listar:
    call fs_listar_dir
    ret

; ==========================================
; LOGIN — Autenticação e inicialização gráfica
; ==========================================
do_login:
    mov rax, [argc]
    cmp rax, 3
    jl .modo_interativo

    mov rsi, [argv + 8]
    lea rdi, [rel login_usuario_padrao]
    call strcmpi
    jne .erro

    mov rsi, [argv + 16]
    lea rdi, [rel login_senha_padrao]
    call strcmpi
    jne .erro
    jmp .sucesso

.modo_interativo:
    lea rsi, [rel ajuda_login]
    call print_warning
    call print_newline
    ret

.sucesso:
    lea rsi, [rel msg_login_ok]
    call print_success
    call print_newline

    lea rsi, [rel msg_aguarde]
    call print_aguarde
    call print_newline

    lea rsi, [rel dbg_fb]
    call print_string
    call debug_marca
    call fb_inicializar
    lea rsi, [rel dbg_ok]
    call print_success
    call print_newline
    call debug_marca

    lea rsi, [rel dbg_gpu]
    call print_string
    call debug_marca
    call gpu_inicializar_todos
    lea rsi, [rel dbg_ok]
    call print_success
    call print_newline
    call debug_marca

    lea rsi, [rel dbg_ws]
    call print_string
    call debug_marca
    call ws_inicializar
    lea rsi, [rel dbg_ok]
    call print_success
    call print_newline
    call debug_marca

    lea rsi, [rel dbg_chamando_exec]
    call print_string
    call debug_marca
    call print_newline

    mov rax, rsp
    and rax, 15
    test rax, rax
    jz .pilha_alinhada
    sub rsp, 8
.pilha_alinhada:

    lea rdi, [rel caminho_fyd_desktop]
    call kernel_exec_bin

.loop_grafico:
    cli
    hlt
    jmp .loop_grafico

.erro:
    lea rsi, [rel msg_login_erro]
    call print_error
    call print_newline
    xor rax, rax
    ret

debug_marca:
    push rax
    push rdi
    movzx eax, byte [rel debug_contador]
    add al, 'A'
    mov rdi, 0xB8000 + (0*80 + 74)*2
    mov [rdi], al
    mov byte [rdi + 1], 0x4F
    inc byte [rel debug_contador]
    pop rdi
    pop rax
    ret

section .data
login_usuario_padrao: db 'admin', 0
login_senha_padrao:   db 'fydelis2026', 0
.dica:                db ' (padrao: admin fydelis2026)', 10, 0
caminho_fyd_desktop:  db 'interface/sistema/bin/fyd_desktop', 0
msg_erro_exec_falha:  db 'Erro: Falha ao carregar ou executar o fyd_desktop!', 0
dbg_fb:               db '[DEBUG] A inicializar Framebuffer...', 0
dbg_gpu:              db '[DEBUG] A inicializar GPUs...', 0
dbg_ws:               db '[DEBUG] A inicializar Window Server...', 0
dbg_chamando_exec:    db '[DEBUG] A invocar kernel_exec_bin em C...', 0
dbg_ok:               db ' [OK]', 0
debug_contador:       db 0

; ======================================
; INTERPRETADOR DE COMANDOS — PARTE 2
; ======================================

letra_para_indice:
    mov al, [rsi]
    cmp al, ':'
    je .tem_dois_pontos
    cmp al, 'A'
    jb  .minuscula
    cmp al, 'Z'
    ja  .minuscula
    sub al, 'A'
    movsx rax, al
    ret
.minuscula:
    cmp al, 'a'
    jb  .invalido
    cmp al, 'z'
    ja  .invalido
    sub al, 'a'
    movsx rax, al
    ret
.tem_dois_pontos:
    mov al, [rsi-1]
    cmp al, 'A'
    jb  .m_baixo
    cmp al, 'Z'
    ja  .m_baixo
    sub al, 'A'
    movsx rax, al
    ret
.m_baixo:
    cmp al, 'a'
    jb  .invalido
    cmp al, 'z'
    ja  .invalido
    sub al, 'a'
    movsx rax, al
    ret
.invalido:
    mov rax, -1
    ret

tamanho_para_setores:
    push rbx
    push rcx
    push rdx
    push rsi
    xor rax, rax
    xor rcx, rcx
.ler_digito:
    mov cl, [rsi]
    cmp cl, '0'
    jb  .fim_numeros
    cmp cl, '9'
    ja  .fim_numeros
    imul rax, 10
    add rax, rcx
    sub rax, '0'
    inc rsi
    jmp .ler_digito
.fim_numeros:
    mov cl, [rsi]
    cmp cl, 'G'
    je .multiplica_g
    cmp cl, 'g'
    je .multiplica_g
    cmp cl, 'T'
    je .multiplica_t
    cmp cl, 't'
    je .multiplica_t
    cmp cl, 'M'
    je .multiplica_m
    cmp cl, 'm'
    je .multiplica_m
    jmp .fim
.multiplica_m:
    mov rbx, 1024 * 1024 / 512
    mul rbx
    jmp .fim
.multiplica_g:
    mov rbx, 1024 * 1024 * 1024 / 512
    mul rbx
    jmp .fim
.multiplica_t:
    mov rbx, 1099511627776 / 512
    mul rbx
.fim:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

do_mkpart:
    mov rax, [argc]
    cmp rax, 3
    jl .uso
    mov rsi, [argv + 8]
    call letra_para_indice
    cmp rax, -1
    je .letra_inv
    mov rdi, rax
    mov rsi, [argv + 16]
    call tamanho_para_setores
    mov rdx, rax
    call criar_unidade
    test rax, rax
    jz .erro
    lea rsi, [rel msg_part_ok]
    call print_string
    mov rsi, [argv + 8]
    call print_string
    call print_newline
    ret
.letra_inv:
    lea rsi, [rel msg_letra_inv]
    call print_string
    ret
.erro:
    lea rsi, [rel msg_erro_op]
    call print_string
    ret
.uso:
    lea rsi, [rel ajuda_mkpart]
    call print_string
    ret

do_rmpart:
    mov rax, [argc]
    cmp rax, 2
    jl .uso
    mov rsi, [argv + 8]
    call letra_para_indice
    cmp rax, -1
    je .letra_inv
    mov rdi, rax
    call remover_unidade
    test rax, rax
    jz .erro
    lea rsi, [rel msg_part_del]
    call print_string
    mov rsi, [argv + 8]
    call print_string
    call print_newline
    ret
.letra_inv:
    lea rsi, [rel msg_letra_inv]
    call print_string
    ret
.erro:
    lea rsi, [rel msg_erro_op]
    call print_string
    ret
.uso:
    lea rsi, [rel ajuda_rmpart]
    call print_string
    ret

do_format:
    mov rax, [argc]
    cmp rax, 3
    jl .uso
    mov rsi, [argv + 8]
    call letra_para_indice
    cmp rax, -1
    je .letra_inv
    mov rdi, rax
    mov rsi, [argv + 16]
    call formatar_unidade
    test rax, rax
    jz .erro
    lea rsi, [rel msg_fmt_ok]
    call print_string
    mov rsi, [argv + 16]
    call print_string
    call print_newline
    ret
.letra_inv:
    lea rsi, [rel msg_letra_inv]
    call print_string
    ret
.erro:
    lea rsi, [rel msg_erro_op]
    call print_string
    ret
.uso:
    lea rsi, [rel ajuda_format]
    call print_string
    ret

do_fstype:
    mov rax, [argc]
    cmp rax, 2
    jl .uso
    mov rsi, [argv + 8]
    call letra_para_indice
    cmp rax, -1
    je .letra_inv
    mov rdi, rax
    shl rdi, 3
    add rdi, rax
    shl rdi, 3
    mov al, [mapa_unidades + rdi + 1]
    cmp al, MBR_TIPO_FAT32
    je .fat32
    cmp al, MBR_TIPO_FAT32_LBA
    je .fat32
    cmp al, MBR_TIPO_EXFAT
    je .exfat
    lea rsi, [rel msg_fydfs]
    jmp .imp
.fat32:
    lea rsi, [rel msg_fat32]
    jmp .imp
.exfat:
    lea rsi, [rel msg_exfat]
.imp:
    mov rdi, [argv + 8]
    call print_string
    mov al, ':'
    call print_char
    mov al, ' '
    call print_char
    call print_string
    call print_newline
    ret
.letra_inv:
    lea rsi, [rel msg_letra_inv]
    call print_string
    ret
.uso:
    lea rsi, [rel ajuda_fstype]
    call print_string
    ret

do_bootmode:
    call fs_inicializar
    call obter_tamanho_disco
    
    mov rax, rax
    mov rbx, LIMIAR_GPT_SETORES      
    cmp rax, rbx
    jae .gpt

    lea rsi, [rel msg_disco_mbr]
    call print_warning
    call print_newline
    lea rsi, [rel msg_fs_leg]
    call print_string
    call print_newline
    ret

.gpt:
    lea rsi, [rel msg_disco_gpt]
    call print_success
    call print_newline
    ret

do_blkid:
    call inicializar_disco
    call listar_unidades
    ret

do_df:
    lea rsi, [rel df_cab]
    call print_string
    call listar_unidades
    ret

do_fsinfo:
    call obter_tamanho_disco
    lea rsi, [rel .msg_tamanho]
    call print_string
    call setores_para_texto
    call print_newline
    ret

section .data
.msg_tamanho: db 'Tamanho total do disco: ',0

setores_para_texto:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    mov rbx, 1000000000000 / 512
    cmp rax, rbx
    jae .tb
    mov rbx, 1000000000 / 512
    cmp rax, rbx
    jae .gb
    mov rbx, 1000000 / 512
    cmp rax, rbx
    jae .mb
    mov rbx, 1024 / 512
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conv]
    call int_para_str
    lea rsi, [rel buffer_conv]
    call print_string
    lea rsi, [rel .msg_kb]
    call print_string
    jmp .fim
.mb:
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conv]
    call int_para_str
    lea rsi, [rel buffer_conv]
    call print_string
    lea rsi, [rel .msg_mb]
    call print_string
    jmp .fim
.gb:
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conv]
    call int_para_str
    lea rsi, [rel buffer_conv]
    call print_string
    lea rsi, [rel .msg_gb]
    call print_string
    jmp .fim
.tb:
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conv]
    call int_para_str
    lea rsi, [rel buffer_conv]
    call print_string
    lea rsi, [rel .msg_tb]
    call print_string
.fim:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

section .data
.msg_kb: db ' KB',0
.msg_mb: db ' MB',0
.msg_gb: db ' GB',0
.msg_tb: db ' TB',0

do_bt:
    mov rax, [argc]
    cmp rax, 2
    jl .uso
    mov rdi, [argv + 8]
    lea rsi, [rel str_scan]
    call strcmpi
    jz .scan
    lea rsi, [rel str_conectar]
    call strcmpi
    jz .conectar_bt
    lea rsi, [rel str_desconectar]
    call strcmpi
    jz .desconectar_bt
    jmp .uso

.scan:
    call sys_bt_scan
    lea rsi, [rel .msg_scan]
    call print_string
    ret
.conectar_bt:
    mov rax, [argc]
    cmp rax, 3
    jl .uso
    mov rdi, [argv + 16]
    call sys_bt_conectar
    lea rsi, [rel .msg_con]
    call print_string
    ret
.desconectar_bt:
    mov rax, [argc]
    cmp rax, 3
    jl .uso
    mov rdi, [argv + 16]
    call sys_bt_desconectar
    lea rsi, [rel .msg_desc]
    call print_string
    ret
.uso:
    lea rsi, [rel msg_bt_uso]
    call print_string
    ret

section .data
.msg_scan: db 'Escaneamento Bluetooth concluido',10,0
.msg_con:  db 'Dispositivo conectado',10,0
.msg_desc: db 'Dispositivo desconectado',10,0

do_usb:
    call usb_listar_dispositivos
    test rax, rax
    jz .vazio
    lea rsi, [rel .msg_ok]
    call print_string
    ret
.vazio:
    lea rsi, [rel .msg_nenhum]
    call print_string
    ret

section .data
.msg_ok:    db 'Dispositivos USB listados',10,0
.msg_nenhum: db 'Nenhum dispositivo USB detectado',10,0

section .data
msg_pasta_criada: db 'Pasta criada: ',0
msg_removido:     db 'Removido: ',0
msg_copiado:      db 'Copiado: ',0

do_criar_pasta:
    mov rax, [argc]
    cmp rax, 2
    jl .uso
    mov rdi, [argv + 8]
    call fs_criar_pasta
    test rax, rax
    jz .erro
    lea rsi, [rel msg_pasta_criada]
    call print_string
    mov rsi, [argv + 8]
    call print_string
    call print_newline
    ret
.erro:
    lea rsi, [rel msg_erro_op]
    call print_error
.uso:
    lea rsi, [rel ajuda_criar_pasta]
    call print_string
    ret

do_remover:
    mov rax, [argc]
    cmp rax, 2
    jl .uso
    mov rdi, [argv + 8]
    call fs_remover
    test rax, rax
    jz .erro
    lea rsi, [rel msg_removido]
    call print_string
    mov rsi, [argv + 8]
    call print_string
    call print_newline
    ret
.erro:
    lea rsi, [rel msg_erro_op]
    call print_error
.uso:
    lea rsi, [rel ajuda_remover]
    call print_string
    ret

do_copiar:
    mov rax, [argc]
    cmp rax, 3
    jl .uso
    mov rdi, [argv + 8]
    mov rsi, [argv + 16]
    call fs_copiar
    test rax, rax
    jz .erro
    lea rsi, [rel msg_copiado]
    call print_string
    mov rsi, [argv + 8]
    call print_string
    mov al, ' '
    call print_char
    mov al, '-'
    call print_char
    mov al, '>'
    call print_char
    mov al, ' '
    call print_char
    mov rsi, [argv + 16]
    call print_string
    call print_newline
    ret
.erro:
    lea rsi, [rel msg_erro_op]
    call print_string
.uso:
    lea rsi, [rel ajuda_copiar]
    call print_string
    ret

cmd_ping:
    mov rax, [argc]
    cmp rax, 2
    jl .uso
    mov rdi, [argv + 8]
    call rede_exec_ping
    test rax, rax
    jz .erro
    lea rsi, [rel msg_ping_ok]
    call print_string
    call print_newline
    mov rax, 1
    ret
.uso:
    lea rsi, [rel msg_ping_uso]
    call print_string
    call print_newline
    xor rax, rax
    ret
.erro:
    lea rsi, [rel msg_ping_fail]
    call print_error
    call print_newline
    xor rax, rax
    ret

cmd_traceroute:
    mov rax, [argc]
    cmp rax, 2
    jl .uso
    mov rdi, [argv + 8]
    call rede_exec_traceroute
    test rax, rax
    jz .erro
    mov rax, 1
    ret
.uso:
    lea rsi, [rel msg_ping_uso]
    call print_string
    call print_newline
    xor rax, rax
    ret
.erro:
    xor rax, rax
    ret

cmd_dhcp:
    lea rsi, [rel msg_dhcp_aguarde]
    call print_string
    call print_newline
    call dhcp_exec
    test rax, rax
    jz .erro
    lea rsi, [rel msg_dhcp_ok]
    call print_string
    call print_newline
    call cmd_status_rede
    mov rax, 1
    ret
.erro:
    lea rsi, [rel msg_dhcp_fail]
    call print_error
    call print_newline
    xor rax, rax
    ret

cmd_status_rede:
    lea rsi, [rel msg_rede_titulo]
    call print_string
    call print_newline

    lea rsi, [rel msg_rede_iface]
    call print_string
    call rede_ler_iface_nome
    mov rsi, rax
    call print_string
    call print_newline

    lea rsi, [rel msg_rede_mac]
    call print_string
    call rede_ler_mac
    mov rdi, rax
    call formatar_mac
    lea rsi, [rel mac_buf]
    call print_string
    call print_newline

    lea rsi, [rel msg_rede_ip]
    call print_string
    call rede_ler_ip
    mov rsi, rax
    call print_string
    call print_newline

    lea rsi, [rel msg_rede_mask]
    call print_string
    call rede_ler_mascara
    mov rsi, rax
    call print_string
    call print_newline

    lea rsi, [rel msg_rede_gw]
    call print_string
    call rede_ler_gateway
    mov rsi, rax
    call print_string
    call print_newline

    lea rsi, [rel msg_rede_dns]
    call print_string
    call rede_ler_dns
    mov rsi, rax
    call print_string
    call print_newline

    call rede_ler_status_link
    test rax, rax
    jz .link_down
    lea rsi, [rel msg_rede_link_up]
    call print_string
    call print_newline
    jmp .cont
.link_down:
    lea rsi, [rel msg_rede_link_down]
    call print_string
    call print_newline
.cont:
    lea rsi, [rel msg_rede_rx]
    call print_string
    call rede_ler_bytes_rx
    mov rdi, rax
    call print_num
    lea rsi, [rel msg_bytes]
    call print_string
    lea rsi, [rel msg_sep]
    call print_string
    call rede_ler_bytes_tx
    mov rdi, rax
    call print_num
    lea rsi, [rel msg_bytes]
    call print_string
    call print_newline
    mov rax, 1
    ret

cmd_arp:
    call rede_ler_tabela_arp
    mov rsi, rax
    call print_string
    call print_newline
    mov rax, 1
    ret

cmd_limpar_rede:
    mov qword [rel rx_bytes_total], 0
    mov qword [rel tx_bytes_total], 0
    lea rsi, [rel msg_limpo]
    call print_string
    call print_newline
    mov rax, 1
    ret

formatar_mac:
    push rcx
    push rdx
    mov rcx, 6
    mov rsi, rdi
    lea rdi, [rel mac_buf]
.loop:
    lodsb
    mov dl, al
    shr al, 4
    call nibble_para_hex
    stosb
    mov al, dl
    and al, 0x0F
    call nibble_para_hex
    stosb
    cmp rcx, 1
    je .fim
    mov al, ':'
    stosb
.fim:
    dec rcx
    jnz .loop
    mov byte [rdi], 0
    pop rdx
    pop rcx
    ret

nibble_para_hex:
    cmp al, 10
    jb .numero
    add al, 'A' - 10
    ret
.numero:
    add al, '0'
    ret

cmd_wifi:
    mov rax, [argc]
    cmp rax, 2
    jl wifi_ajuda

    mov rdi, [argv + 8]
    cmp byte [rdi], 'l'
    je wifi_lista
    cmp byte [rdi], 'c'
    je wifi_conectar
    cmp byte [rdi], 'd'
    je wifi_desconectar
    cmp byte [rdi], 's'
    je wifi_status
    jmp wifi_ajuda

wifi_lista:
    call wifi_detectar_placa
    test rax, rax
    jz wifi_sem_placa
    call wifi_inicializar
    test rax, rax
    jz wifi_falha
    call sys_wifi_scan
    test rax, rax
    jz wifi_nenhuma
    mov rsi, rax
    call exibir_lista_redes
    ret

wifi_conectar:
    mov rax, [argc]
    cmp rax, 3
    jl wifi_uso_conectar
    mov rdi, [argv + 16]
    call sys_wifi_conectar
    test rax, rax
    jz wifi_falha_conn

    lea rsi, [rel msg_dhcp_aguarde]
    call print_string
    call print_newline
    call dhcp_cliente_iniciar

    mov eax, [dhcp_ip_atual]
    test eax, eax
    jz wifi_sem_ip
    lea rsi, [rel msg_dhcp_ok]
    call print_string
    lea rdi, [rel ip_buf]
    call ip_para_string
    lea rsi, [rel ip_buf]
    call print_string
    call print_newline
    ret
wifi_sem_ip:
    lea rsi, [rel msg_dhcp_fail]
    call print_string
    call print_newline
    ret

wifi_desconectar:
    call sys_wifi_desconectar
    lea rsi, [rel wifi_msg_desconec_ok]
    call print_string
    call print_newline
    ret

wifi_status:
    call wifi_ler_status
    mov rdi, rax
    lea rsi, [rel wifi_msg_status_pfx]
    call print_string
    mov al, dil
    and al, 1
    jz wifi_nao_det
    lea rsi, [rel wifi_msg_ativa]
    jmp wifi_imp_st
wifi_nao_det:
    lea rsi, [rel wifi_msg_nao_ativa]
wifi_imp_st:
    call print_string
    call print_newline
    ret

wifi_ajuda:
    push rdi
    mov rdi, 0x0E
    call set_color
    pop rdi

    lea rsi, [rel wifi_msg_ajuda_cab]
    call print_string
    call print_newline
    lea rsi, [rel wifi_msg_ajuda_l1]
    call print_string
    call print_newline
    lea rsi, [rel wifi_msg_ajuda_l2]
    call print_string
    call print_newline
    lea rsi, [rel wifi_msg_ajuda_l3]
    call print_string
    call print_newline
    lea rsi, [rel wifi_msg_ajuda_l4]
    call print_string
    call print_newline

    push rdi
    mov rdi, DEF_ATTR
    call set_color
    pop rdi
    ret

wifi_sem_placa:
    lea rsi, [rel wifi_msg_err_placa]
    call print_string
    call print_newline
    ret
wifi_falha:
    lea rsi, [rel wifi_msg_err_init]
    call print_error
    call print_newline
    ret
wifi_nenhuma:
    lea rsi, [rel wifi_msg_nenhuma_rede]
    call print_string
    call print_newline
    ret
wifi_falha_conn:
    lea rsi, [rel wifi_msg_err_conn]
    call print_string
    call print_newline
    ret
wifi_uso_conectar:
    lea rsi, [rel wifi_msg_uso_conn]
    call print_string
    call print_newline
    ret

exibir_lista_redes:
    push rbx
    push rcx
    push rsi

    lea rsi, [rel wifi_msg_lista_titulo]
    call print_string
    call print_newline

    xor rcx, rcx
.loop:
    cmp rcx, MAX_REDES
    jge .fim

    mov rax, rcx
    imul rax, WifiRede_size
    lea rsi, [rel wifi_scan_lista]
    add rsi, rax

    cmp byte [rsi + WifiRede.ssid], 0
    jz .prox

    push rcx
    push rsi
    mov rdi, rcx
    call print_num
    mov al, ':'
    call print_char
    mov al, ' '
    call print_char

    pop rsi
    push rsi
    lea rsi, [rsi + WifiRede.ssid]
    call print_string

    pop rsi
    mov al, ' '
    call print_char
    mov al, '-'
    call print_char
    mov al, ' '
    call print_char
    cmp byte [rsi + WifiRede.seguranca], 0
    je .aberta
    lea rsi, [rel wifi_msg_wpa2]
    jmp .imp_seg
.aberta:
    lea rsi, [rel wifi_msg_aberta]
.imp_seg:
    call print_string
    call print_newline

.prox:
    inc rcx
    jmp .loop

.fim:
    pop rsi
    pop rcx
    pop rbx
    ret

section .data
wifi_msg_desconec_ok:   db 'Desconectado da rede sem fio.',0
wifi_msg_status_pfx:    db 'Placa WiFi: ',0
wifi_msg_ativa:         db 'Detectada e Ativa',0
wifi_msg_nao_ativa:     db 'Nao detectada',0
wifi_msg_ajuda_cab:     db '=== Comandos WiFi ===',0
wifi_msg_ajuda_l1:      db 'wifi lista                  - Escanear redes sem fio',0
wifi_msg_ajuda_l2:      db 'wifi conectar "SSID"        - Conectar a uma rede',0
wifi_msg_ajuda_l3:      db 'wifi desconectar            - Encerrar conexao',0
wifi_msg_ajuda_l4:      db 'wifi status                 - Exibir status da placa',0
wifi_msg_err_placa:     db 'Placa WiFi nao detectada no barramento PCI',0
wifi_msg_err_init:      db 'Falha ao inicializar o controlador WiFi',0
wifi_msg_nenhuma_rede:  db 'Nenhuma rede sem fio encontrada',0
wifi_msg_err_conn:      db 'Falha na autenticacao ou conexao',0
wifi_msg_uso_conn:      db 'Uso correto: wifi conectar "NomeDaRede"',0
wifi_msg_lista_titulo:  db '📡 Redes Wi-Fi encontradas:',0
wifi_msg_aberta:        db 'Aberta',0
wifi_msg_wpa2:          db 'WPA2',0

cmd_dhcp_servidor:
    mov rax, [argc]
    cmp rax, 2
    jl .status

    mov rdi, [argv + 8]
    cmp byte [rdi], 'i'
    je .iniciar
    cmp byte [rdi], 'p'
    je .parar
    cmp byte [rdi], 's'
    je .status
    jmp .ajuda

.iniciar:
    call dhcp_servidor_iniciar
    ret
.parar:
    mov dword [rel dhcp_servidor_ativo], 0
    lea rsi, [rel .msg_serv_parado]
    call print_string
    call print_newline
    ret
.status:
    call dhcp_servidor_status
    ret

.ajuda:
    lea rsi, [rel .msg_dhcp_cab]
    call print_string
    call print_newline
    lea rsi, [rel .msg_dhcp_l1]
    call print_string
    call print_newline
    lea rsi, [rel .msg_dhcp_l2]
    call print_string
    call print_newline
    lea rsi, [rel .msg_dhcp_l3]
    call print_string
    call print_newline
    ret

section .data
.msg_serv_parado:   db 'DHCP Servidor desativado.',0
.msg_dhcp_cab:      db '=== DHCP Servidor (Rede Local) ===',0
.msg_dhcp_l1:       db 'dhcp_servidor iniciar       - Ativar atribuicao de IPs',0
.msg_dhcp_l2:       db 'dhcp_servidor parar         - Desativar servico',0
.msg_dhcp_l3:       db 'dhcp_servidor status        - Listar clientes conectados',0

print_colored:
    push rdi
    push rsi
    call set_color
    call print_string
    mov rdi, DEF_ATTR
    call set_color
    pop rsi
    pop rdi
    ret

print_error:
    push rdi
    mov rdi, 0x0C
    call print_colored
    pop rdi
    ret

print_warning:
    push rdi
    mov rdi, 0x0E
    call print_colored
    pop rdi
    ret
    
print_aguarde:
    push rdi
    mov rdi, 0x0D
    call print_colored
    pop rdi
    ret

print_success:
    push rdi
    mov rdi, 0x0A
    call print_colored
    pop rdi
    ret
    
cmd_fydlog:
    call fydlog_ler_todos
    call print_newline
    ret
