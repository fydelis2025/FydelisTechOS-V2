; ======================================
; Módulo de Rede FydelTerm — Ponte Assembly ↔ C++
; Comandos: ipconfig, wifi, ping, arp, netstat, traceroute
; ======================================
BITS 64
%include "fydelterm.inc"

; ✅ Funções externas — C++/Qt (System V AMD64: RDI, RSI, RDX, RCX, R8, R9)
extern print_string, print_newline, print_char, print_num
extern argc, argv
extern rede_ler_iface_nome
extern rede_ler_mac, rede_ler_ip, rede_ler_mascara
extern rede_ler_gateway, rede_ler_dns, rede_ler_status_link
extern rede_ler_bytes_rx, rede_ler_bytes_tx
extern rede_exec_ping, rede_ler_tabela_arp
extern rede_ler_conexoes, rede_exec_traceroute
extern rede_ler_wifi_disponiveis
extern rede_conectar_wifi, rede_desconectar_wifi
extern rede_ler_status_wifi

section .data
align 16
hdr_net:      db '=== Configuracao de Rede (FydelNet Core) ===',0
hdr_wifi:     db '=== REDES WIRELESS DISPONIVEIS ===',0
lbl_if:       db 'Interface: ',0
lbl_mac:      db 'MAC:       ',0
lbl_ip:       db 'IP:        ',0
lbl_mask:     db 'Mascara:   ',0
lbl_gw:       db 'Gateway:   ',0
lbl_dns:      db 'DNS:       ',0
lbl_up:       db 'Status:    CONECTADO ✅',0
lbl_down:     db 'Status:    DESCONECTADO ❌',0
hdr_stats:    db '=== Estatisticas de Transmissao ===',0
lbl_rx:       db 'RX Recebido: ',0
lbl_tx:       db 'TX Enviado:  ',0
lbl_arp:      db '=== Tabela ARP ===',0
lbl_conn:     db '=== Conexoes Ativas ===',0
msg_ping_uso: db 'Uso: ping <host/ip>',0
msg_tr_uso:   db 'Uso: traceroute <host/ip>',0
msg_wifi_uso: db 'Uso: wifi list | wifi connect <nome> | wifi disconnect',0
msg_aguarde:  db 'Aguarde...',0
msg_sem_wifi: db 'Nenhuma interface WiFi detectada',0
msg_conectou: db 'Conectado a rede: ',0
msg_descon:   db 'Desconectado da rede WiFi',0
tipo_cabo:    db 'Cabeada',0
tipo_wifi:    db 'WiFi Sem Fio',0
lbl_bytes:    db 'B',0
lbl_kilo:     db 'K',0
lbl_mega:     db 'M',0
lbl_giga:     db 'G',0

section .text
global do_ipconfig, do_wifi, do_ping, do_arp, do_netstat, do_traceroute

; ==========================================
; 📊 COMANDO: ipconfig
; ==========================================
do_ipconfig:
    push    rsi
    push    rax

    mov     rsi, hdr_net
    call    print_string
    call    print_newline
    call    print_newline

    ; Nome da interface
    mov     rsi, lbl_if
    call    print_string
    call    rede_ler_iface_nome
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; MAC
    mov     rsi, lbl_mac
    call    print_string
    call    rede_ler_mac
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; IP
    mov     rsi, lbl_ip
    call    print_string
    call    rede_ler_ip
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; Máscara
    mov     rsi, lbl_mask
    call    print_string
    call    rede_ler_mascara
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; Gateway
    mov     rsi, lbl_gw
    call    print_string
    call    rede_ler_gateway
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; DNS
    mov     rsi, lbl_dns
    call    print_string
    call    rede_ler_dns
    mov     rsi, rax
    test    rsi, rsi
    jz      .dns_ok
    call    print_string
.dns_ok:
    call    print_newline
    call    print_newline

    ; Status
    call    rede_ler_status_link
    cmp     rax, 1
    je      .conectado
    mov     rsi, lbl_down
    jmp     .status_prn
.conectado:
    mov     rsi, lbl_up
.status_prn:
    call    print_string
    call    print_newline
    call    print_newline

    ; Estatísticas
    mov     rsi, hdr_stats
    call    print_string
    call    print_newline

    mov     rsi, lbl_rx
    call    print_string
    call    rede_ler_bytes_rx
    call    print_tamanho
    call    print_newline

    mov     rsi, lbl_tx
    call    print_string
    call    rede_ler_bytes_tx
    call    print_tamanho
    call    print_newline

    pop     rax
    pop     rsi
    ret

; ==========================================
; 📶 COMANDO: wifi
; ==========================================
do_wifi:
    push    rsi
    push    rdi
    push    rax

    mov     rax, [argc]
    cmp     rax, 2
    jl      .mostrar_uso

    mov     rdi, [argv + 8]
    cmp     byte [rdi], 'l'
    je      .listar
    cmp     byte [rdi], 'c'
    je      .conectar
    cmp     byte [rdi], 'd'
    je      .desconectar

.mostrar_uso:
    mov     rsi, msg_wifi_uso
    call    print_string
    call    print_newline
    jmp     .fim

.listar:
    mov     rsi, hdr_wifi
    call    print_string
    call    print_newline
    call    rede_ler_wifi_disponiveis
    test    rax, rax
    jz      .sem_wifi
    mov     rcx, rax
.lista_loop:
    mov     rsi, [rcx]
    test    rsi, rsi
    jz      .lista_fim
    call    print_string
    call    print_newline
    add     rcx, 8
    jmp     .lista_loop
.sem_wifi:
    mov     rsi, msg_sem_wifi
    call    print_string
    call    print_newline
.lista_fim:
    jmp     .fim

.conectar:
    mov     rax, [argc]
    cmp     rax, 3
    jl      .mostrar_uso
    mov     rsi, msg_aguarde
    call    print_string
    call    print_newline
    mov     rdi, [argv + 16]
    call    rede_conectar_wifi
    mov     rsi, msg_conectou
    call    print_string
    mov     rsi, [argv + 16]
    call    print_string
    call    print_newline
    jmp     .fim

.desconectar:
    call    rede_desconectar_wifi
    mov     rsi, msg_descon
    call    print_string
    call    print_newline

.fim:
    pop     rax
    pop     rdi
    pop     rsi
    ret

; ==========================================
; 🔔 COMANDO: ping
; ==========================================
do_ping:
    push    rsi
    push    rdi
    push    rax

    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    mov     rdi, [argv + 8]
    call    rede_exec_ping
    jmp     .fim
.uso:
    mov     rsi, msg_ping_uso
    call    print_string
    call    print_newline
.fim:
    pop     rax
    pop     rdi
    pop     rsi
    ret

; ==========================================
; 📋 COMANDO: arp
; ==========================================
do_arp:
    push    rsi
    push    rax

    mov     rsi, lbl_arp
    call    print_string
    call    print_newline
    call    rede_ler_tabela_arp
    test    rax, rax
    jz      .fim
    mov     rcx, rax
.loop:
    mov     rsi, [rcx]
    test    rsi, rsi
    jz      .fim
    call    print_string
    call    print_newline
    add     rcx, 8
    jmp     .loop
.fim:
    pop     rax
    ret

; ==========================================
; 🔌 COMANDO: netstat
; ==========================================
do_netstat:
    push    rsi
    push    rax

    mov     rsi, lbl_conn
    call    print_string
    call    print_newline
    call    rede_ler_conexoes
    test    rax, rax
    jz      .fim
    mov     rcx, rax
.loop:
    mov     rsi, [rcx]
    test    rsi, rsi
    jz      .fim
    call    print_string
    call    print_newline
    add     rcx, 8
    jmp     .loop
.fim:
    pop     rax
    ret

; ==========================================
; 🗺️ COMANDO: traceroute
; ==========================================
do_traceroute:
    push    rsi
    push    rdi
    push    rax

    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    mov     rdi, [argv + 8]
    call    rede_exec_traceroute
    jmp     .fim
.uso:
    mov     rsi, msg_tr_uso
    call    print_string
    call    print_newline
.fim:
    pop     rax
    pop     rdi
    pop     rsi
    ret

; ==========================================
; 🧾 AUXILIAR: Formatar tamanho (B → KB → MB → GB)
; ==========================================
print_tamanho:
    push    rcx
    push    rdx
    push    rbx

    mov     rcx, 1024
    mov     rbx, lbl_bytes      ; Ponteiro para string de unidade

    cmp     rax, rcx
    jb      .imprimir
    cqo
    div     rcx
    mov     rbx, lbl_kilo

    cmp     rax, rcx
    jb      .imprimir
    cqo
    div     rcx
    mov     rbx, lbl_mega

    cmp     rax, rcx
    jb      .imprimir
    cqo
    div     rcx
    mov     rbx, lbl_giga

.imprimir:
    call    print_num          ; Imprime o número em RAX
    mov     rsi, rbx
    call    print_string       ; Imprime unidade (B/K/M/G)

    pop     rbx
    pop     rdx
    pop     rcx
    ret
