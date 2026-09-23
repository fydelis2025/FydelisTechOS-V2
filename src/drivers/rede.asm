; ======================================
; Módulo de Rede FydelTerm (Comando aprimorado)
; Comandos: ipconfig, ping, arp, netstat, traceroute
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

extern print_string, print_newline, print_char
extern argc, argv

section .data
align 16

; --- Configuração de Rede Dinâmica/Simulada ---
iface_eth:  db 'eth0 (Cabeado - Intel e1000)',0
iface_wifi: db 'wlan0 (Sem Fio - Realtek RTL8188)',0
mac_addr:   db '00:1A:2B:3C:4D:5E',0
ip_addr:    db '192.168.1.100',0
mask:       db '255.255.255.0',0
gw:         db '192.168.1.1',0
dns1:       db '8.8.8.8',0
dns2:       db '8.8.4.4',0

link_stat:  dq 1
rx_bytes:   dq 12582912
tx_bytes:   dq 983040
rx_pkts:    dq 46234
tx_pkts:    dq 12456

; --- Mensagens e Textos ---
hdr_net:    db '=== Configuracao de Rede (FydelNet Core) ===',0
lbl_if:     db 'Interface: ',0
lbl_mac:    db 'MAC:       ',0
lbl_ip:     db 'IP:        ',0
lbl_mask:   db 'Mascara:   ',0
lbl_gw:     db 'Gateway:   ',0
lbl_dns:    db 'DNS:       ',0
lbl_up:     db 'Status:    CONECTADO (Link Ativo)',0
lbl_down:   db 'Status:    DESCONECTADO',0
hdr_stats:  db '=== Estatisticas de Transmissao ===',0
lbl_rx:     db 'RX Recebido: ',0
lbl_tx:     db 'TX Enviado:  ',0
lbl_rxpkt:  db 'Pacotes RX:  ',0
lbl_txpkt:  db 'Pacotes TX:  ',0
msg_ping_ok:db 'Resposta de ',0
msg_ping_ms:db ' em 1.4 ms (TTL=64)',0
msg_arp:    db 'Tabela ARP (Cache de Enderecos Físicos):',0
arp_line:   db '  192.168.1.1    00:1A:2B:3C:4D:01 [DINAMICO]',0
msg_ni:     db 'Funcao de rede em andamento — suporte nativo TCP/IP.',0
msg_ping_u: db 'Uso correto: ping <endereco_ip>',0

section .text
global do_ipconfig, do_ping, do_arp, do_netstat, do_traceroute

do_ipconfig:
    push    rsi
    mov     rsi, hdr_net
    call    print_string
    call    print_newline
    call    print_newline

    ; Exibe Interface Ativa
    mov     rsi, lbl_if
    call    print_string
    mov     rsi, iface_eth       ; Exibe o perfil cabeado/padrão ativo
    call    print_string
    call    print_newline

    mov     rsi, lbl_mac
    call    print_string
    mov     rsi, mac_addr
    call    print_string
    call    print_newline

    mov     rsi, lbl_ip
    call    print_string
    mov     rsi, ip_addr
    call    print_string
    call    print_newline

    mov     rsi, lbl_mask
    call    print_string
    mov     rsi, mask
    call    print_string
    call    print_newline

    mov     rsi, lbl_gw
    call    print_string
    mov     rsi, gw
    call    print_string
    call    print_newline

    mov     rsi, lbl_dns
    call    print_string
    mov     rsi, dns1
    call    print_string
    mov     al, ' '
    call    print_char
    mov     rsi, dns2
    call    print_string
    call    print_newline
    call    print_newline

    ; Status do Link
    mov     rax, [link_stat]
    cmp     rax, 1
    jne     .down
    mov     rsi, lbl_up
    jmp     .prn
.down:
    mov     rsi, lbl_down
.prn:
    call    print_string
    call    print_newline
    call    print_newline

    ; Estatísticas
    mov     rsi, hdr_stats
    call    print_string
    call    print_newline

    mov     rsi, lbl_rx
    call    print_string
    mov     rax, [rx_bytes]
    mov     rcx, 1024
    xor     rdx, rdx
    div     rcx
    call    print_num
    mov     al, 'K'
    call    print_char
    mov     al, 'B'
    call    print_char
    call    print_newline

    mov     rsi, lbl_tx
    call    print_string
    mov     rax, [tx_bytes]
    mov     rcx, 1024
    xor     rdx, rdx
    div     rcx
    call    print_num
    mov     al, 'K'
    call    print_char
    mov     al, 'B'
    call    print_char
    call    print_newline

    mov     rsi, lbl_rxpkt
    call    print_string
    mov     rax, [rx_pkts]
    call    print_num
    call    print_newline

    mov     rsi, lbl_txpkt
    call    print_string
    mov     rax, [tx_pkts]
    call    print_num
    call    print_newline

    pop     rsi
    ret

do_ping:
    push    rsi
    mov     rax, [argc]
    cmp     rax, 2
    jl      .uso
    
    mov     rsi, msg_ping_ok
    call    print_string
    mov     rsi, [argv + 8]      ; Pega o IP/Host passado como argumento
    call    print_string
    mov     rsi, msg_ping_ms
    call    print_string
    call    print_newline
    jmp     .fim
.uso:
    mov     rsi, msg_ping_u
    call    print_string
    call    print_newline
.fim:
    pop     rsi
    ret

do_arp:
    push    rsi
    mov     rsi, msg_arp
    call    print_string
    call    print_newline
    mov     rsi, arp_line
    call    print_string
    call    print_newline
    pop     rsi
    ret

do_netstat:
    push    rsi
    mov     rsi, msg_ni
    call    print_string
    call    print_newline
    pop     rsi
    ret

do_traceroute:
    push    rsi
    mov     rsi, msg_ni
    call    print_string
    call    print_newline
    pop     rsi
    ret

; --- Função Auxiliar: Imprime número contido em RAX ---
print_num:
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi

    sub     rsp, 32
    mov     rdi, rsp
    mov     rbx, 10
    add     rdi, 19
    mov     byte [rdi], 0
.dec:
    dec     rdi
    xor     rdx, rdx
    div     rbx
    add     dl, '0'
    mov     [rdi], dl
    test    rax, rax
    jnz     .dec

    mov     rsi, rdi
.l:
    lodsb
    test    al, al
    jz      .done
    call    print_char
    jmp     .l
.done:
    add     rsp, 32
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret
