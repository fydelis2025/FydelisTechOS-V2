; ======================================
; Interpretador de Comandos — FydelTerm DSL (Português)
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

extern do_ipconfig, do_ping, do_arp, do_netstat, do_traceroute
extern clear_screen, print_string, print_newline, print_char

global interpret_command
global do_cls, do_echo, do_help, do_ver, do_exit, do_reboot, do_pentest
global do_login, do_criar_pasta, do_remover, do_copiar, do_listar
global do_mkpart, do_rmpart, do_format, do_fstype
global do_bootmode, do_blkid, do_df
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

ajuda_cls:        db 'cls - Limpa a tela',0
ajuda_limpar:     db 'limpar - Limpa a tela do terminal',0
ajuda_echo:       db 'dizer <texto> - Exibe texto na tela',0
ajuda_help:       db 'ajuda - Lista todos os comandos disponiveis',0
ajuda_ver:        db 'versao - Exibe a versao do sistema',0
ajuda_exit:       db 'sair - Encerra sessao do terminal',0
ajuda_reboot:     db 'reiniciar - Reinicia o sistema operacional',0
ajuda_ipconfig:   db 'ipconfig - Configuracao de rede',0
ajuda_ping:       db 'ping <host> - Testa conectividade',0
ajuda_arp:        db 'arp - Tabela de enderecos MAC',0
ajuda_netstat:    db 'netstat - Conexoes ativas',0
ajuda_traceroute: db 'traceroute - Rastreia rota de rede',0
ajuda_login:      db 'login - Tela RealSoft',0
ajuda_criar_pasta:db 'criar_pasta <nome> - Cria novo diretorio',0
ajuda_remover:    db 'remover <arquivo> - Apaga arquivo ou pasta',0
ajuda_copiar:     db 'copiar <origem> <destino> - Copia arquivos',0
ajuda_listar:     db 'listar - Lista arquivos do diretorio atual',0
ajuda_mkpart:     db 'mkpart - Cria particao no disco',0
ajuda_rmpart:     db 'rmpart - Exclui particao do disco',0
ajuda_format:     db 'format - Formata uma particao',0
ajuda_fstype:     db 'fstype - Exibe o sistema de arquivos',0
ajuda_bootmode:   db 'bootmode - Exibe o modo de boot atual',0
ajuda_blkid:      db 'blkid - Exibe IDs das particoes',0
ajuda_df:         db 'df - Espaco livre em disco',0
ajuda_pentest:	  db ' pentest - Abre a Suíte de Segurança FydelisTech', 0

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
msg_pentest:	db 'Abrindo Suíte FydelisTech...', 10, 0
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
	dq str_pentest,		do_pentest,		ajuda_pentest
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
    test    rdi, rdi
    jz      .fim

    mov     rbx, cmd_table
.busca:
    mov     rsi, [rbx]
    test    rsi, rsi
    jz      .nao_encontrado

    call    strcmpi
    jz      .encontrado

    add     rbx, 24
    jmp     .busca

.encontrado:
    mov     rax, [rbx + 8]
    test    rax, rax
    jz      .fim
    call    rax
    jmp     .fim

.nao_encontrado:
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

    mov     rsi, msg_help_head
    call    print_string
    call    print_newline

    mov     rbx, cmd_table
.loop:
    mov     rsi, [rbx]
    test    rsi, rsi
    jz      .fim

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

    mov     rsi, [rbx + 16]
    call    print_string
    call    print_newline

    add     rbx, 24
    jmp     .loop

.fim:
    pop     rsi
    pop     rbx
    ret

; ======================================
; DEMAIS COMANDOS
; ======================================
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
    mov     rsi, msg_ver
    call    print_string
    call    print_newline
    ret

do_exit:
    mov     rsi, msg_bye
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
    mov     rsi, msg_nao_sup
    call    print_string
    call    print_newline
    ret

do_criar_pasta:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    mov     rsi, msg_mkdir_ok
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    call    print_newline
    ret
.uso:
    mov     rsi, ajuda_criar_pasta
    call    print_string
    call    print_newline
    ret

do_remover:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    mov     rsi, msg_rm_ok
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    call    print_newline
    ret
.uso:
    mov     rsi, ajuda_remover
    call    print_string
    call    print_newline
    ret

do_copiar:
    mov     rax, [argc]
    cmp     rax, 3
    jl      .uso
    mov     rsi, msg_cp_ok
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
    mov     rsi, ajuda_copiar
    call    print_string
    call    print_newline
    ret

do_listar:
    mov     rsi, msg_nao_sup
    call    print_string
    call    print_newline
    ret

do_mkpart:
    mov     rax, [argc]
    cmp     rax, 4
    jl      .uso
    mov     rsi, msg_part_ok
    call    print_string
    mov     rsi, [argv + 8]
    call    print_string
    call    print_newline
    ret
.uso:
    mov     rsi, ajuda_mkpart
    call    print_string
    call    print_newline
    ret

do_rmpart:
    mov     rax, [argc]
    cmp     rax, 3
    jl      .uso
    mov     rsi, msg_part_del
    call    print_string
    call    print_newline
    ret
.uso:
    mov     rsi, ajuda_rmpart
    call    print_string
    call    print_newline
    ret

do_format:
    mov     rax, [argc]
    cmp     rax, 3
    jl      .uso
    mov     rsi, msg_fmt_ok
    call    print_string
    mov     rsi, [argv + 16]
    call    print_string
    call    print_newline
    ret
.uso:
    mov     rsi, ajuda_format
    call    print_string
    call    print_newline
    ret

do_fstype:
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    mov     rsi, [argv + 8]
    call    print_string
    mov     rsi, str_doubleponto
    call    print_string
    mov     rsi, msg_fat32
    call    print_string
    call    print_newline
    ret
.uso:
    mov     rsi, ajuda_fstype
    call    print_string
    call    print_newline
    ret

do_bootmode:
    mov     rsi, msg_fs_leg
    call    print_string
    call    print_newline
    ret

do_blkid:
    mov     rsi, blkid_line
    call    print_string
    call    print_newline
    ret

do_df:
    mov     rsi, df_line1
    call    print_string
    call    print_newline
    mov     rsi, df_line2
    call    print_string
    call    print_newline
    ret

; ======================================
; PENTEST
; ======================================
do_pentest:
	mov 	rsi, msg_pentest
	call 	print_string
	;Aqui o Fydelterm avisa ao ambiente gráfico para abrir a janela
	ret
; ======================================
; COMPARAÇÃO DE STRINGS (case-insensitive)
; ======================================
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

; Strings usadas por do_blkid e do_df
section .data
blkid_line: db '/dev/sda1 - FAT32',0
df_line1:   db 'Filesystem    Size  Used  Avail',0
df_line2:   db '/dev/sda1     32GB   4GB    28GB',0
