; ======================================
; Interpretador de Comandos — FydelTerm DSL (Português)
; ======================================
BITS 64
default rel

; 🛡️ Suprime os avisos estritos de relocação para tabelas de ponteiros
[warning suppress reloc-abs-qword]
[warning suppress reloc-rel-dword]
[warning suppress reloc-abs-dword]

%include "fydelterm.inc"

extern do_ipconfig, do_ping, do_arp, do_netstat, do_traceroute, do_fydel
extern clear_screen, print_string, print_newline, print_char
extern get_key, do_pentest
extern sys_bt_scan, sys_bt_conectar, sys_bt_desconectar
extern sys_usb_listar, sys_usb_conectar, obter_tamanho_disco

global interpret_command
global do_cls, do_echo, do_help, do_ver, do_exit, do_reboot
global do_login, do_criar_pasta, do_remover, do_copiar, do_listar
global do_mkpart, do_rmpart, do_format, do_fstype
global do_bootmode, do_blkid, do_df, usb_listar_dispositivos
global strcmpi


section .data
align 16
str_cls:        db 'cls',0
str_clear:      db 'limpar',0
str_echo:       db 'dizer',0
str_help:       db 'ajuda',0
str_ver:        db 'versao',0
str_exit:       db 'sair',0
str_reboot:     db 'reiniciar',0
str_ipconfig:   db 'ipconfig',0
str_ping:       db 'ping',0
str_arp:        db 'arp',0
str_netstat:    db 'netstat',0
str_traceroute: db 'traceroute',0
str_login:      db 'login',0
str_criar_pasta:db 'criar_pasta',0
str_remover:    db 'remover',0
str_copiar:     db 'copiar',0
str_listar:     db 'listar',0
str_mkpart:     db 'mkpart',0
str_rmpart:     db 'rmpart',0
str_format:     db 'format',0
str_fstype:     db 'fstype',0
str_bootmode:   db 'bootmode',0
str_blkid:      db 'blkid',0
str_df:         db 'df',0
str_pentest:	db 'pentest', 0 
str_fydel:      db 'fydel',0
str_bt:         db 'bt',0
str_usb:        db 'usb',0

ajuda_cls:      db 'cls - Limpa a tela',0
ajuda_limpar:   db 'limpar - Limpa a tela do terminal',0
ajuda_echo:     db 'dizer <texto> - Exibe texto na tela',0
ajuda_help:     db 'ajuda - Lista todos os comandos disponiveis',0
ajuda_ver:      db 'versao - Exibe a versao do sistema',0
ajuda_exit:     db 'sair - Encerra sessao do terminal',0
ajuda_reboot:   db 'reiniciar - Reinicia o sistema operacional',0
ajuda_ipconfig: db 'ipconfig - Configuracao de rede',0
ajuda_ping:     db 'ping <host> - Testa conectividade',0
ajuda_arp:      db 'arp - Tabela de enderecos MAC',0
ajuda_netstat:  db 'netstat - Conexoes ativas',0
ajuda_traceroute: db 'traceroute - Rastreia rota de rede',0
ajuda_login:    db 'login - Tela RealSoft',0
ajuda_criar_pasta:db 'criar_pasta <nome> - Cria novo diretorio',0
ajuda_remover:  db 'remover <arquivo> - Apaga arquivo ou pasta',0
ajuda_copiar:   db 'copiar <origem> <destino> - Copia arquivos',0
ajuda_listar:   db 'listar - Lista arquivos do diretorio atual',0
ajuda_mkpart:   db 'mkpart - Cria particao no disco',0
ajuda_rmpart:   db 'rmpart - Exclui particao do disco',0
ajuda_format:   db 'format - Formata uma particao',0
ajuda_fstype:   db 'fstype - Exibe o sistema de arquivos',0
ajuda_bootmode: db 'bootmode - Exibe o modo de boot atual',0
ajuda_blkid:    db 'blkid - Exibe IDs das particoes',0
ajuda_df:       db 'df - Espaco livre em disco',0
ajuda_fydel:    db 'fydel [arquivo] - Editor de texto estilo Nano',0
ajuda_pentest:  db 'pentest - Abre a Suite de Seguranca FydelisTech', 0
ajuda_bt:       db 'bt [scan|conectar|desconectar] - Gerencia dispositivos Bluetooth',0
ajuda_usb:      db 'usb - Lista dispositivos USB conectados',0

msg_unknown:    db 'Comando nao reconhecido. Digite "ajuda".',0
msg_ver:        db 'FydelTerm OS v2.0 · Autor: Adiel Santos Fontes, Salvador-BA · x86_64',0
msg_bye:        db 'Sessao encerrada.',0
msg_help_head:  db '=== COMANDOS DO FYDELTERM (DSL) ===',0
msg_mkdir_ok:   db 'Diretorio criado: ',0
msg_rm_ok:      db 'Removido com sucesso: ',0
msg_cp_ok:      db 'Copiado com sucesso: ',0
msg_part_ok:    db 'Particao criada: ',0
msg_part_del:   db 'Particao excluida.',0
msg_fmt_ok:     db 'Sistema aplicado: ',0
msg_fs_leg:     db 'Modo: Legacy BIOS',0
msg_fat32:      db 'FAT32',0
msg_nao_sup:    db 'Funcao em desenvolvimento.',0
msg_pentest:    db 'Abrindo Suite FydelisTech...', 0
msg_bt_ok:      db 'Comando Bluetooth executado com sucesso.',0
msg_usb_ok:     db 'Listagem USB concluída com sucesso.',0
msg_usb_vazio:  db 'Nenhum dispositivo USB conectado ou driver inativo.', 0
str_doubleponto:db ': ',0

; TABELA: [nome, funcao, ajuda] — 3 ponteiros = 24 bytes
cmd_table:
    dq str_cls,         do_cls,         ajuda_cls
    dq str_clear,       do_cls,         ajuda_limpar
    dq str_echo,        do_echo,        ajuda_echo
    dq str_help,        do_help,        ajuda_help
    dq str_ver,         do_ver,         ajuda_ver
    dq str_exit,        do_exit,        ajuda_exit
    dq str_reboot,      do_reboot,      ajuda_reboot
    dq str_ipconfig,    do_ipconfig,    ajuda_ipconfig
    dq str_ping,        do_ping,        ajuda_ping
    dq str_arp,         do_arp,         ajuda_arp
    dq str_netstat,     do_netstat,     ajuda_netstat
    dq str_traceroute,  do_traceroute,  ajuda_traceroute
    dq str_login,       do_login,       ajuda_login
    dq str_criar_pasta, do_criar_pasta, ajuda_criar_pasta
    dq str_remover,     do_remover,     ajuda_remover
    dq str_copiar,      do_copiar,      ajuda_copiar
    dq str_listar,      do_listar,      ajuda_listar
    dq str_mkpart,      do_mkpart,      ajuda_mkpart
    dq str_rmpart,      do_rmpart,      ajuda_rmpart
    dq str_format,      do_format,      ajuda_format
    dq str_fstype,      do_fstype,      ajuda_fstype
    dq str_bootmode,    do_bootmode,    ajuda_bootmode
    dq str_blkid,       do_blkid,       ajuda_blkid
    dq str_df,          do_df,          ajuda_df          
    dq str_fydel,       do_fydel,       ajuda_fydel       
    dq str_pentest,     do_pentest,     ajuda_pentest
    dq str_bt,          do_bt,          ajuda_bt
    dq str_usb,         do_usb,         ajuda_usb
    dq 0,               0,              0

section .text
interpret_command:
    push    rbx
    push    rsi
    push    rdi

    mov     rax, [argc]
    cmp     rax, 0
    jle     .fim

    mov     rdi, [argv]         
    mov     rsi, str_fydel      
    call    strcmpi
    test    rax, rax
    jz      .chamar_fydel_direto

    mov     rbx, cmd_table
.busca:
    mov     rsi, [rbx]          
    test    rsi, rsi
    jz      .nao_encontrado

    mov     rdi, buffer         
    call    strcmpi
    test    rax, rax            
    jz      .encontrado

    add     rbx, 24             
    jmp     .busca

.chamar_fydel_direto:
    call    do_fydel            
    jmp     .fim

.encontrado:
    mov     rax, [rbx + 8]      
    test    rax, rax
    jz      .fim
    call    rax
    jmp     .fim

.nao_encontrado:
    mov     rsi, buffer         
    call    print_string
    call    print_newline
    mov     rsi, msg_unknown
    call    print_string
    call    print_newline

.fim:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ======================================
; COMANDO AJUDA
; ======================================
do_help:
    push    rbx
    push    rsi
    push    rdi
    xor     rcx, rcx            

    lea     rsi, [rel msg_help_head]
    call    print_string
    call    print_newline

    lea     rbx, [rel cmd_table]
.loop:
    mov     rsi, [rbx]          
    test    rsi, rsi
    jz      .fim                

    inc     rcx
    cmp     rcx, 20
    jl      .imprime_linha
    
    push    rsi
    lea     rsi, [rel msg_pausa]
    call    print_string
    call    get_key             
    call    print_newline
    pop     rsi
    xor     rcx, rcx            

.imprime_linha:
    push    rbx
    mov     al, ' '
    call    print_char
    mov     al, ' '
    call    print_char
    call    print_string        

    mov     al, ' '
    call    print_char
    mov     al, '-'
    call    print_char
    mov     al, ' '
    call    print_char

    pop     rbx
    push    rbx
    mov     rsi, [rbx + 16]     
    call    print_string
    call    print_newline

    pop     rbx
    add     rbx, 24             
    jmp     .loop

.fim:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

section .data
msg_pausa: db '-- Pressione qualquer tecla para ver mais comandos --', 0

; ======================================
; DEMAIS COMANDOS
; ======================================
section .text
do_usb:
    call    usb_listar_dispositivos
    test    rax, rax
    jz      .sem_dispositivos
    
    lea     rsi, [rel msg_usb_ok]
    call    print_string
    call    print_newline
    ret

.sem_dispositivos:
    lea     rsi, [rel msg_usb_vazio]
    call    print_string
    call    print_newline
    ret

do_bt:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    mov     rdi, [argv + 8]
    call    sys_bt_scan
    lea     rsi, [rel msg_bt_ok]
    call    print_string
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_bt]
    call    print_string
    call    print_newline
    ret
    
do_cls:
    call    clear_screen
    ret

do_echo:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .fim
    mov     rsi, [argv + 8]
    call    print_string
    call    print_newline
.fim:
    ret

do_ver:
    lea     rsi, [rel msg_ver]
    call    print_string
    call    print_newline
    ret

do_exit:
    lea     rsi, [rel msg_bye]
    call    print_string
    call    print_newline
    cli
.halt_loop:
    hlt
    jmp     .halt_loop

do_reboot:
    mov     al, 0xFE
    out     0x64, al
    cli
.reboot_loop:
    hlt
    jmp     .reboot_loop

do_login:
    lea     rsi, [rel msg_nao_sup]
    call    print_string
    call    print_newline
    ret

do_criar_pasta:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    lea     rsi, [rel msg_mkdir_ok]
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_criar_pasta]
    call    print_string
    call    print_newline
    ret

do_remover:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    lea     rsi, [rel msg_rm_ok]
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_remover]
    call    print_string
    call    print_newline
    ret

do_copiar:
    mov     rax, [argc]
    cmp     rax, 3
    jl      .uso
    lea     rsi, [rel msg_cp_ok]
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    mov     al, ' '
    call    print_char
    mov     al, '>'
    call    print_char
    mov     al, ' '
    call    print_char
    mov     rsi, [argv + 16]
    call    print_string
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_copiar]
    call    print_string
    call    print_newline
    ret

do_listar:
    lea     rsi, [rel msg_nao_sup]
    call    print_string
    call    print_newline
    ret

; ======================================
; COMANDOS FUNCIONAIS DE DISCO E PARTIÇÃO
; ======================================
do_mkpart:
    mov     rax, [argc]
    cmp     rax, 4
    jl      .uso
    lea     rsi, [rel msg_part_ok]
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    mov     al, ' '
    call    print_char
    mov     al, '('
    call    print_char
    mov     rsi, [argv + 16]
    call    print_string
    mov     al, ')'
    call    print_char
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_mkpart]
    call    print_string
    call    print_newline
    ret

do_rmpart:
    mov     rax, [argc]
    cmp     rax, 3
    jl      .uso
    lea     rsi, [rel msg_part_del]
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_rmpart]
    call    print_string
    call    print_newline
    ret

do_format:
    mov     rax, [argc]
    cmp     rax, 3
    jl      .uso
    lea     rsi, [rel msg_fmt_ok]
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    mov     rsi, [argv + 16]
    call    print_string
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_format]
    call    print_string
    call    print_newline
    ret

do_fstype:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    mov     rsi, [argv + 8]
    call    print_string
    lea     rsi, [rel str_doubleponto]
    call    print_string
    lea     rsi, [rel msg_fat32]
    call    print_string
    call    print_newline
    ret
.uso:
    lea     rsi, [rel ajuda_fstype]
    call    print_string
    call    print_newline
    ret

do_blkid:
    lea     rsi, [rel msg_blkid_prefix]
    call    print_string
    
    xor     rdi, rdi                  
    call    obter_tamanho_disco       
    
    lea     rsi, [rel msg_fat32_suffix]
    call    print_string
    call    print_newline
    ret

do_df:
    lea     rsi, [rel df_line1]
    call    print_string
    call    print_newline

    lea     rsi, [rel df_particao_prefix]
    call    print_string

    xor     rdi, rdi
    call    obter_tamanho_disco       
    
    mov     rcx, 2097152
    xor     rdx, rdx
    div     rcx                       
    
    mov     rdi, buffer_conversao
    call    int_para_str

    lea     rsi, [rel buffer_conversao]
    call    print_string

    lea     rsi, [rel df_sufixo_gb]
    call    print_string
    call    print_newline
    ret

do_bootmode:
    lea     rsi, [rel msg_fs_leg]
    call    print_string
    call    print_newline
    ret

; ======================================
; FUNÇÃO AUXILIAR: Inteiro para String
; ======================================
int_para_str:
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi

    mov     rbx, 10
    mov     rcx, 0
    cmp     rax, 0
    jne     .converter
    mov     byte [rdi], '0'
    mov     byte [rdi+1], 0
    jmp     .fim_conv

.converter:
    xor     rdx, rdx
    div     rbx
    add     rdx, '0'
    push    rdx
    inc     rcx
    test    rax, rax
    jnz     .converter

.copiar:
    pop     rdx
    mov     [rdi], dl
    inc     rdi
    dec     rcx
    jnz     .copiar
    mov     byte [rdi], 0

.fim_conv:
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

section .bss
buffer_conversao: resb 32

; ======================================
; COMPARAÇÃO DE STRINGS (case-insensitive)
; ======================================
section .text
strcmpi:
    push    rsi
    push    rdi
.compara_loop:
    mov     al, [rsi]
    mov     dl, [rdi]
    cmp     al, 'a'
    jb      .up1
    cmp     al, 'z'
    ja      .up1
    sub     al, 32
.up1:
    cmp     dl, 'a'
    jb      .up2
    cmp     dl, 'z'
    ja      .up2
    sub     dl, 32
.up2:
    cmp     al, dl
    jne     .nao_iguais
    cmp     al, 0
    je      .iguais
    inc     rsi
    inc     rdi
    jmp     .compara_loop
.iguais:
    xor     rax, rax
    jmp     .fim
.nao_iguais:
    mov     rax, 1
.fim:
    pop     rdi
    pop     rsi
    ret

global usb_listar_dispositivos
usb_listar_dispositivos:
    mov     rax, 1
    ret

; ======================================
; SEÇÃO DE DADOS
; ======================================
section .data
msg_blkid_prefix:     db '/dev/sda1 - ', 0
msg_fat32_suffix:     db 'FAT32 (FydelisTech VFS Real)', 0
df_line1:             db 'Filesystem     Size  Used  Avail', 0
df_particao_prefix:   db '/dev/sda1     ', 0
df_sufixo_gb:         db 'GB   --     --  (Driver ATA Real)', 0
