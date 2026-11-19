; ============================================================================
; REDE_CMD.ASM — Comandos de Rede Nativos (Bare-Metal Real · Sem C++/Qt)
; Comandos: ipconfig, wifi, ping, arp, netstat, traceroute
; FydelisTech OS v4.2 · Salvador - Bahia
; ============================================================================
BITS 64
default rel
%include "fydelterm.inc"

; Rotinas de Terminal
extern print_string, print_newline, print_char, print_num
extern argc, argv

; ============================================================================
; PONTE REAL COM A PILHA DE REDE NATIVA DO KERNEL (net_core.asm / e1000 / rtl8139)
; ============================================================================
extern net_iface_nome           ; -> rax = ponteiro string (ex: "eth0 (e1000)")
extern net_obter_mac_str        ; -> rax = ponteiro string MAC formatado
extern net_obter_ip_str         ; -> rax = ponteiro string IPv4 atual
extern net_obter_mascara_str    ; -> rax = ponteiro string Mascara
extern net_obter_gateway_str    ; -> rax = ponteiro string Gateway
extern net_obter_dns_str        ; -> rax = ponteiro string DNS
extern net_link_ativo           ; -> rax = 1 link UP no hardware, 0 DOWN
extern net_bytes_rx             ; -> rax = total de bytes recebidos pelo NIC
extern net_bytes_tx             ; -> rax = total de bytes transmitidos pelo NIC
extern net_dhcp_renovar         ; -> rax = 1 sucesso, 0 timeout DHCP
extern net_ping_real            ; rdi = str IP/host -> rax = 1 respondeu, 0 perda
extern net_arp_listar           ; -> imprime entradas reais do cache ARP do kernel
extern net_conexoes_listar      ; -> imprime sockets/portas TCP/UDP ativos
extern net_traceroute_real      ; rdi = str IP/host -> executa sondas TTL=1..30

section .data
align 16
hdr_net:      db '=== Configuracao de Rede (FydelNet Real Hardware) ===', 0
lbl_if:       db 'Interface: ', 0
lbl_mac:      db 'MAC:       ', 0
lbl_ip:       db 'IPv4:      ', 0
lbl_mask:     db 'Mascara:   ', 0
lbl_gw:       db 'Gateway:   ', 0
lbl_dns:      db 'DNS:       ', 0
lbl_up:       db 'Status:    [CONECTADO - LINK UP]', 0
lbl_down:     db 'Status:    [DESCONECTADO - LINK DOWN]', 0
hdr_stats:    db '=== Estatisticas Reais da Placa (NIC) ===', 0
lbl_rx:       db 'RX Recebido: ', 0
lbl_tx:       db 'TX Enviado:  ', 0
lbl_arp:      db '=== Tabela ARP Real (Cache Kernel) ===', 0
lbl_conn:     db '=== Sockets / Conexoes Ativas ===', 0
msg_ping_uso: db 'Uso: ping <ip_ipv4>  (ex: ping 10.0.2.2)', 0
msg_tr_uso:   db 'Uso: traceroute <ip_ipv4>', 0
msg_dhcp_ok:  db '[OK] Configuracao IPv4 renovada via DHCP real.', 0
msg_dhcp_err: db '[ERRO] Falha ao obter resposta do servidor DHCP.', 0
msg_wifi_hw:  db '[INFO] Modo Bare-Metal: operando via NIC PCI Ethernet (eth0).', 0
lbl_bytes:    db ' B', 0
lbl_kilo:     db ' KB', 0
lbl_mega:     db ' MB', 0
lbl_giga:     db ' GB', 0

section .text
global do_ipconfig, do_wifi, do_ping, do_arp, do_netstat, do_traceroute

; ============================================================================
; COMANDO: ipconfig  (ou "ipconfig /renew" para disparar DHCP real)
; ============================================================================
do_ipconfig:
    push    rbx
    push    rsi
    push    rdi
    push    rax

    ; Verifica se foi passado argumento "/renew" ou "dhcp"
    mov     rax, [rel argc]
    cmp     rax, 2
    jl      .exibir_info

    lea     rbx, [rel argv]
    mov     rdi, [rbx + 8]
    cmp     byte [rdi], '/'
    je      .renovar_dhcp
    cmp     byte [rdi], 'd'
    je      .renovar_dhcp
    jmp     .exibir_info

.renovar_dhcp:
    call    net_dhcp_renovar
    test    rax, rax
    jz      .dhcp_falhou
    lea     rsi, [rel msg_dhcp_ok]
    call    print_string
    call    print_newline
    jmp     .exibir_info

.dhcp_falhou:
    lea     rsi, [rel msg_dhcp_err]
    call    print_string
    call    print_newline

.exibir_info:
    lea     rsi, [rel hdr_net]
    call    print_string
    call    print_newline
    call    print_newline

    ; Interface PCI detectada
    lea     rsi, [rel lbl_if]
    call    print_string
    call    net_iface_nome
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; Endereco MAC real lido da EEPROM/MMIO da placa
    lea     rsi, [rel lbl_mac]
    call    print_string
    call    net_obter_mac_str
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; Endereco IPv4
    lea     rsi, [rel lbl_ip]
    call    print_string
    call    net_obter_ip_str
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; Mascara de sub-rede
    lea     rsi, [rel lbl_mask]
    call    print_string
    call    net_obter_mascara_str
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; Gateway padrao
    lea     rsi, [rel lbl_gw]
    call    print_string
    call    net_obter_gateway_str
    mov     rsi, rax
    call    print_string
    call    print_newline

    ; Servidor DNS
    lea     rsi, [rel lbl_dns]
    call    print_string
    call    net_obter_dns_str
    mov     rsi, rax
    test    rsi, rsi
    jz      .dns_fim
    call    print_string
.dns_fim:
    call    print_newline
    call    print_newline

    ; Estado fisico do Link (registrador STATUS do NIC)
    call    net_link_ativo
    cmp     rax, 1
    je      .conectado
    lea     rsi, [rel lbl_down]
    jmp     .status_prn
.conectado:
    lea     rsi, [rel lbl_up]
.status_prn:
    call    print_string
    call    print_newline
    call    print_newline

    ; Contadores reais RX/TX
    lea     rsi, [rel hdr_stats]
    call    print_string
    call    print_newline

    lea     rsi, [rel lbl_rx]
    call    print_string
    call    net_bytes_rx
    call    print_tamanho
    call    print_newline

    lea     rsi, [rel lbl_tx]
    call    print_string
    call    net_bytes_tx
    call    print_tamanho
    call    print_newline

    pop     rax
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ============================================================================
; COMANDO: wifi (informa status do barramento wireless / fallback Ethernet)
; ============================================================================
do_wifi:
    push    rsi
    lea     rsi, [rel msg_wifi_hw]
    call    print_string
    call    print_newline
    pop     rsi
    ret

; ============================================================================
; COMANDO: ping <ip> (envia pacotes ICMP Echo Request reais pelo NIC)
; ============================================================================
do_ping:
    push    rbx
    push    rsi
    push    rdi
    push    rax

    mov     rax, [rel argc]
    cmp     rax, 2
    jl      .uso

    lea     rbx, [rel argv]
    mov     rdi, [rbx + 8]
    call    net_ping_real
    jmp     .fim

.uso:
    lea     rsi, [rel msg_ping_uso]
    call    print_string
    call    print_newline

.fim:
    pop     rax
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ============================================================================
; COMANDO: arp (exibe tabela ARP real resolvida na rede local)
; ============================================================================
do_arp:
    push    rsi
    lea     rsi, [rel lbl_arp]
    call    print_string
    call    print_newline
    call    net_arp_listar
    pop     rsi
    ret

; ============================================================================
; COMANDO: netstat (exibe sockets/portas reais da pilha TCP/UDP)
; ============================================================================
do_netstat:
    push    rsi
    lea     rsi, [rel lbl_conn]
    call    print_string
    call    print_newline
    call    net_conexoes_listar
    pop     rsi
    ret

; ============================================================================
; COMANDO: traceroute <ip> (sondas ICMP/UDP com incremento de TTL)
; ============================================================================
do_traceroute:
    push    rbx
    push    rsi
    push    rdi
    push    rax

    mov     rax, [rel argc]
    cmp     rax, 2
    jl      .uso

    lea     rbx, [rel argv]
    mov     rdi, [rbx + 8]
    call    net_traceroute_real
    jmp     .fim

.uso:
    lea     rsi, [rel msg_tr_uso]
    call    print_string
    call    print_newline

.fim:
    pop     rax
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ============================================================================
; AUXILIAR: Formatar tamanho (B -> KB -> MB -> GB)
; ============================================================================
print_tamanho:
    push    rcx
    push    rdx
    push    rbx
    push    rsi

    mov     rcx, 1024
    lea     rbx, [rel lbl_bytes]

    cmp     rax, rcx
    jb      .imprimir
    xor     edx, edx
    div     rcx
    lea     rbx, [rel lbl_kilo]

    cmp     rax, rcx
    jb      .imprimir
    xor     edx, edx
    div     rcx
    lea     rbx, [rel lbl_mega]

    cmp     rax, rcx
    jb      .imprimir
    xor     edx, edx
    div     rcx
    lea     rbx, [rel lbl_giga]

.imprimir:
    call    print_num
    mov     rsi, rbx
    call    print_string

    pop     rsi
    pop     rbx
    pop     rdx
    pop     rcx
    ret
