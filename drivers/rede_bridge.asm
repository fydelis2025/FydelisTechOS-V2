; ============================================================================
; REDE.ASM — Comandos de Rede do FydelTerm (Bridge sobre rede_bridge.asm + net_core.asm)
; Exporta: do_ipconfig, do_ping, do_arp, do_netstat, do_traceroute
; FydelisTech OS v4.2 · Salvador - Bahia
; ============================================================================
BITS 64
default rel

%include "fydelterm.inc"

; Importa do rede_bridge.asm (driver E1000 / DHCP / Ping real)
extern rede_ler_iface_nome, rede_ler_ip, rede_ler_mascara
extern rede_ler_gateway, rede_ler_dns, rede_ler_status_link
extern rede_ler_bytes_rx, rede_ler_bytes_tx
extern rede_exec_ping, rede_ler_tabela_arp, rede_ler_conexoes
extern rede_exec_traceroute

; Importa do net_core.asm (formatacao MAC e comandos auxiliares)
extern net_obter_mac_str, net_arp_listar, net_conexoes_listar, net_traceroute_real

global do_ipconfig, do_ping, do_arp, do_netstat, do_traceroute

section .rodata
msg_ipc_titulo:     db 'Configuracao de Rede FydelisTech OS (e1000):', 10, 0
msg_ipc_iface:      db '  Adaptador Ethernet : ', 0
msg_ipc_mac:        db '  Endereco Fisico    : ', 0
msg_ipc_ip:         db '  Endereco IPv4      : ', 0
msg_ipc_mask:       db '  Mascara de Sub-rede: ', 0
msg_ipc_gw:         db '  Gateway Padrao     : ', 0
msg_ipc_dns:        db '  Servidor DNS       : ', 0
msg_ipc_link_up:    db '  Status do Link     : CONECTADO (1000 Mbps)', 10, 0
msg_ipc_link_dn:    db '  Status do Link     : DESCONECTADO', 10, 0
msg_ipc_rx:         db '  Bytes Recebidos    : ', 0
msg_ipc_tx:         db '  Bytes Enviados     : ', 0

section .text

; ============================================================================
; COMANDO: ipconfig
; ============================================================================
do_ipconfig:
    push    rbx

    lea     rsi, [rel msg_ipc_titulo]
    call    print_string

    lea     rsi, [rel msg_ipc_iface]
    call    print_string
    call    rede_ler_iface_nome
    mov     rsi, rax
    call    print_string
    call    print_newline

    lea     rsi, [rel msg_ipc_mac]
    call    print_string
    call    net_obter_mac_str
    mov     rsi, rax
    call    print_string
    call    print_newline

    lea     rsi, [rel msg_ipc_ip]
    call    print_string
    call    rede_ler_ip
    mov     rsi, rax
    call    print_string
    call    print_newline

    lea     rsi, [rel msg_ipc_mask]
    call    print_string
    call    rede_ler_mascara
    mov     rsi, rax
    call    print_string
    call    print_newline

    lea     rsi, [rel msg_ipc_gw]
    call    print_string
    call    rede_ler_gateway
    mov     rsi, rax
    call    print_string
    call    print_newline

    lea     rsi, [rel msg_ipc_dns]
    call    print_string
    call    rede_ler_dns
    mov     rsi, rax
    call    print_string
    call    print_newline

    call    rede_ler_status_link
    test    rax, rax
    jz      .link_down
    lea     rsi, [rel msg_ipc_link_up]
    call    print_string
    jmp     .trafego
.link_down:
    lea     rsi, [rel msg_ipc_link_dn]
    call    print_string

.trafego:
    lea     rsi, [rel msg_ipc_rx]
    call    print_string
    call    rede_ler_bytes_rx
    mov     rdi, rax
    call    print_num
    call    print_newline

    lea     rsi, [rel msg_ipc_tx]
    call    print_string
    call    rede_ler_bytes_tx
    mov     rdi, rax
    call    print_num
    call    print_newline

    pop     rbx
    ret

; ============================================================================
; COMANDOS: ping / arp / netstat / traceroute
; ============================================================================
do_ping:
    ; Entrada: RDI = ponteiro para string IP (ex: "10.0.2.2")
    call    rede_exec_ping
    ret

do_arp:
    call    net_arp_listar
    ret

do_netstat:
    call    net_conexoes_listar
    ret

do_traceroute:
    call    net_traceroute_real
    ret
