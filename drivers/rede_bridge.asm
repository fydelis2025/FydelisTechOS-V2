; ==========================================
; REDE BRIDGE REAL — FydelisTech OS (ICMP / E1000 legacy)
; Ping REAL: ARP -> IP -> ICMP -> polling de recepção
; Requer: QEMU com -device e1000 (não e1000e!)
; ==========================================
BITS 64
default rel
%include "fydelterm.inc"

global rede_ler_iface_nome
global rede_ler_mac
global rede_ler_ip
global rede_ler_mascara
global rede_ler_gateway
global rede_ler_dns
global rede_ler_status_link
global rede_ler_bytes_rx
global rede_ler_bytes_tx
global rede_ler_wifi_disponiveis
global rede_conectar_wifi
global rede_desconectar_wifi
global rede_exec_ping
global rede_ler_tabela_arp
global rede_ler_conexoes
global rede_exec_traceroute

extern pci_ler_bar0
extern pci_ler_dispositivo
extern pci_ler_classe
extern print_string, print_newline, print_num, print_char

; --- Registradores E1000 ---
E1000_CTRL      equ 0x0000
E1000_STATUS    equ 0x0008      ; bit 1 = LU (link up)
E1000_EERD      equ 0x0014
E1000_ICR       equ 0x00C0
E1000_RCTL      equ 0x0100
E1000_TCTL      equ 0x0400
E1000_RDBAL     equ 0x2800
E1000_RDLEN     equ 0x2808
E1000_RDH       equ 0x2810
E1000_RDT       equ 0x2818
E1000_TDBAL     equ 0x3800
E1000_TDLEN     equ 0x3808
E1000_TDH       equ 0x3810
E1000_TDT       equ 0x3818

; --- constantes ---
IP_PROTO_UDP        equ 17
DHCP_SERVER_PORT    equ 67
DHCP_CLIENT_PORT    equ 68
DHCP_MSG_DISCOVER   equ 1
DHCP_MSG_REQUEST    equ 3
DHCP_MSG_OFFER      equ 2
DHCP_MSG_ACK        equ 5
DHCP_OPT_MSGTYPE    equ 53
DHCP_OPT_REQIP      equ 50
DHCP_OPT_SRVIDENT   equ 54
DHCP_OPT_END        equ 255

NUM_TX_DESC     equ 8
NUM_RX_DESC     equ 32
RX_BUF_SIZE     equ 2048
ETH_P_IP        equ 0x0800
ETH_P_ARP       equ 0x0806

ICMP_TIME_EXCEEDED  equ 11
TRACEROTE_MAX_HOPS  equ 15

section .data
str_iface:      db 'e1000e0',0
str_ip:         db '127.0.0.1',0
str_mask:       db '255.255.255.0',0
str_gw:         db '0.0.0.0',0
str_dns:        db '0.0.0.0',0
meu_ip:         dd 0x0A00020F           ; 10.0.2.15 big-endian
msg_ping_enviando:  db 'Enviando ICMP Echo Request real...',0
msg_ping_sucesso:   db 'Resposta ICMP recebida!',0
msg_ping_erro:      db 'Sem resposta ICMP (NIC/link/destino).',0
msg_sem_link:       db 'NIC: link down.',0
msg_tr_hop:         db ' hop: ',0
msg_tr_fim:         db 'Traceroute concluido.',0
msg_tr_timeout:     db ' *',0
msg_tr_unico:       db 'traceroute: ',0
msg_arp_vazia: db 'Tabela ARP vazia ou sem conexoes ativas.',0

ip_str_tmp:     times 16 db 0       ; buffer p/ imprimir IP recebido
msg_dhcp_ok:    db 'DHCP: IP recebido com sucesso.',0
msg_dhcp_fail:  db 'DHCP: falha ao obter IP.',0

section .bss
align 4096
nic_mmio_base:  resq 1
nic_ok:         resq 1
mac_addr:       resb 6

tr_ttl:             resd 1
tr_hop_ip:          resd 1          ; IP do roteador que respondeu
tr_done:            resq 1

dhcp_xid:       resd 1
dhcp_srv_ip:    resd 1
dhcp_buf:       resb 600            ; resposta DHCP
dhcp_timer_ms:  resd 1
dhcp_ip_obtido: resd 1
dhcp_mask:      resd 1
dhcp_gw:        resd 1
dhcp_xid_placeholder: resd 1        ; ✅ Adicionado para corrigir erro de símbolo em falta

align 4096
tx_ring:        resb NUM_TX_DESC * 16
tx_buf:         resb 2048

align 4096
rx_ring:        resb NUM_RX_DESC * 16
rx_bufs:        resb NUM_RX_DESC * RX_BUF_SIZE

arp_ips:        resd 8                  ; cache ARP: 8 entradas
arp_macs:       resb 8 * 8

ping_id:        resw 1
ping_seq:       resw 1
ping_ip_dst:    resd 1
rx_bytes_total: resq 1
tx_bytes_total: resq 1

section .text

; ==========================================
; MMIO helpers
; ==========================================
nic_read_reg:                   ; rdi=offset -> eax
    mov     rax, [rel nic_mmio_base]
    mov     eax, [rax + rdi]
    ret

nic_write_reg:                  ; rdi=offset, esi=valor
    mov     rax, [rel nic_mmio_base]
    mov     [rax + rdi], esi
    ret

; ==========================================
; INICIALIZAÇÃO REAL DA NIC
; ==========================================
inicializar_nic_mmio:
    push    rcx
    push    rdx

    xor     rcx, rcx
.busca:
    call    pci_ler_dispositivo
    cmp     rax, 0xFFFFFFFF
    je      .prox
    call    pci_ler_classe
    cmp     eax, 0x02000000
    je      .achou
.prox:
    inc     rcx
    cmp     rcx, 256
    jl      .busca
    xor     eax, eax
    jmp     .fim

.achou:
    call    pci_ler_bar0
    and     rax, 0xFFFFFFF0
    mov     [rel nic_mmio_base], rax
    test    rax, rax
    jz      .fim

    ; Reset
    mov     rdi, E1000_CTRL
    mov     esi, 0x04000000                 ; RST
    call    nic_write_reg
    mov     rcx, 1000000
.wr:
    mov     rdi, E1000_CTRL
    call    nic_read_reg
    test    eax, 0x04000000
    jz      .rst_ok
    dec     rcx
    jnz     .wr
.rst_ok:

    ; MAC da EEPROM
    mov     rax, [rel nic_mmio_base]
    mov     ax, [rax + 0x5400]
    mov     [rel mac_addr], ax
    mov     ax, [rax + 0x5402]
    mov     [rel mac_addr + 2], ax
    mov     ax, [rax + 0x5404]
    mov     [rel mac_addr + 4], ax

    ; RX ring
    mov     rdi, E1000_RDBAL
    mov     rax, rx_ring
    mov     esi, eax
    call    nic_write_reg
    mov     rdi, E1000_RDLEN
    mov     esi, NUM_RX_DESC * 16
    call    nic_write_reg
    mov     rdi, E1000_RDH
    xor     esi, esi
    call    nic_write_reg
    mov     rdi, E1000_RDT
    xor     esi, esi
    call    nic_write_reg

    ; buffers de RX nos descritores
    xor     rcx, rcx
.fillrx:
    mov     rax, rcx
    imul    rax, RX_BUF_SIZE
    add     rax, rx_bufs
    mov     rdx, rcx
    shl     rdx, 4
    add     rdx, rx_ring
    mov     [rdx], rax
    mov     dword [rdx + 8], 0
    inc     rcx
    cmp     rcx, NUM_RX_DESC
    jl      .fillrx

    ; TX ring
    mov     rdi, E1000_TDBAL
    mov     rax, tx_ring
    mov     esi, eax
    call    nic_write_reg
    mov     rdi, E1000_TDLEN
    mov     esi, NUM_TX_DESC * 16
    call    nic_write_reg
    mov     rdi, E1000_TDH
    xor     esi, esi
    call    nic_write_reg
    mov     rdi, E1000_TDT
    xor     esi, esi
    call    nic_write_reg

    ; Habilita TX e RX
    mov     rdi, E1000_TCTL
    mov     esi, 0x0A
    call    nic_write_reg
    mov     rdi, E1000_RCTL
    mov     esi, 0x22
    call    nic_write_reg

    mov     qword [rel nic_ok], 1
    mov     eax, 1
.fim:
    pop     rdx
    pop     rcx
    ret

; ==========================================
; ESPERA LINK -> eax=1 ok / 0 falha
; ==========================================
esperar_link:
    push    rcx
    mov     rcx, 50000000
.lp:
    mov     rdi, E1000_STATUS
    call    nic_read_reg
    test    eax, 2
    jnz     .ok
    dec     rcx
    jnz     .lp
    xor     eax, eax
    pop     rcx
    ret
.ok:
    mov     eax, 1
    pop     rcx
    ret

; ==========================================
; TRANSMITIR: rdi=buf, rsi=len
; ==========================================
tx_pacote:
    push    rax
    push    rcx
    push    rdx

    mov     rdx, [rel nic_mmio_base]
    mov     eax, [rdx + E1000_TDT]
    and     eax, NUM_TX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    add     rcx, tx_ring
    mov     [rcx], rdi
    mov     [rcx + 8], si
    mov     byte [rcx + 11], 0x1B
    mov     byte [rcx + 12], 0

    mov     eax, [rdx + E1000_TDT]
    inc     eax
    and     eax, NUM_TX_DESC - 1
    mov     [rdx + E1000_TDT], eax

    mov     rcx, rax
    dec     rcx
    and     rcx, NUM_TX_DESC - 1
    shl     rcx, 4
    add     rcx, tx_ring
.wdd:
    movzx   eax, byte [rcx + 12]
    test    eax, 1
    jnz     .ok
    pause
    jmp     .wdd
.ok:
    mov     rax, tx_bytes_total
    add     [rax], rsi
    pop     rdx
    pop     rcx
    pop     rax
    ret

; ==========================================
; CHECKSUM IP/ICMP: rdi=ptr, rcx=len -> ax
; ==========================================
checksum:
    push    rcx
    push    rbx
    xor     rbx, rbx
.clr:
    xor     eax, eax
.lp:
    xor     eax, eax
    test    rcx, rcx
    jz      .fold
    cmp     rcx, 1
    je      .odd
    movzx   eax, word [rdi]
    sub     rcx, 2
    add     rdi, 2
    add     rbx, rax
    jmp     .lp
.odd:
    movzx   eax, byte [rdi]
    dec     rcx
    add     rbx, rax
.fold:
    mov     eax, ebx
    shr     ebx, 16
    add     eax, ebx
    adc     eax, 0
    mov     ebx, 0xFFFF
    xor     edx, edx
    div     ebx
    not     ax
    and     eax, 0xFFFF
    pop     rbx
    pop     rcx
    ret

; ==========================================
; ARP CACHE
; ==========================================
arp_procura:
    push    rcx
    xor     rcx, rcx
.lp:
    cmp     [arp_ips + rcx*4], eax
    je      .achou
    inc     rcx
    cmp     rcx, 8
    jl      .lp
    xor     edi, edi
    pop     rcx
    ret
.achou:
    lea     rdi, [arp_macs + rcx*8]
    pop     rcx
    ret

arp_grava:
    push    rcx
    xor     rcx, rcx
.lp:
    cmp     dword [arp_ips + rcx*4], 0
    je      .grava
    cmp     [arp_ips + rcx*4], eax
    je      .grava
    inc     rcx
    cmp     rcx, 8
    jl      .lp
    xor     ecx, ecx
.grava:
    mov     [arp_ips + rcx*4], eax
    lea     rdi, [arp_macs + rcx*8]
    mov     ax, [rsi]
    mov     [rdi], ax
    mov     ax, [rsi + 2]
    mov     [rdi + 2], ax
    mov     ax, [rsi + 4]
    mov     [rdi + 4], ax
    pop     rcx
    ret

; ==========================================
; PING REAL
; ==========================================
rede_exec_ping:
    push    rbx
    push    rsi
    push    rdi
    push    rcx

    mov     rax, [rel nic_ok]
    test    rax, rax
    jnz     .hw_ok
    call    inicializar_nic_mmio
    test    rax, rax
    jz      .erro
.hw_ok:
    call    esperar_link
    test    eax, eax
    jz      .erro

    mov     rsi, msg_ping_enviando
    call    print_string
    call    print_newline

    call    string_para_ip
    mov     [rel ping_ip_dst], eax
    mov     ebx, eax

    mov     eax, ebx
    call    arp_procura
    test    rdi, rdi
    jnz     .tem_mac
    mov     eax, ebx
    call    arp_request
    mov     rcx, 20000000
.espera_arp:
    call    rx_processa
    mov     eax, ebx
    call    arp_procura
    test    rdi, rdi
    jnz     .tem_mac
    dec     rcx
    jnz     .espera_arp
    jmp     .erro

.tem_mac:
    mov     r8, rdi
    mov     rdi, tx_buf
    mov     al, [r8]
    mov     [rdi], al
    mov     al, [r8 + 1]
    mov     [rdi + 1], al
    mov     al, [r8 + 2]
    mov     [rdi + 2], al
    mov     al, [r8 + 3]
    mov     [rdi + 3], al
    mov     al, [r8 + 4]
    mov     [rdi + 4], al
    mov     al, [r8 + 5]
    mov     [rdi + 5], al
    mov     al, [rel mac_addr]
    mov     [rdi + 6], al
    mov     al, [rel mac_addr + 1]
    mov     [rdi + 7], al
    mov     al, [rel mac_addr + 2]
    mov     [rdi + 8], al
    mov     al, [rel mac_addr + 3]
    mov     [rdi + 9], al
    mov     al, [rel mac_addr + 4]
    mov     [rdi + 10], al
    mov     al, [rel mac_addr + 5]
    mov     [rdi + 11], al
    mov     word [rdi + 12], ETH_P_IP
    add     rdi, 14

    mov     byte [rdi], 0x45
    mov     byte [rdi + 1], 0
    mov     word [rdi + 2], 20 + 8 + 32
    mov     word [rdi + 4], 0x1234
    mov     word [rdi + 6], 0x4000
    mov     byte [rdi + 8], 64
    mov     byte [rdi + 9], 1
    mov     eax, [rel meu_ip]
    mov     [rdi + 12], eax
    mov     dword [rdi + 16], ebx
    mov     rsi, rdi
    mov     rcx, 20
    call    checksum
    mov     [rdi + 10], ax
    add     rdi, 20

    mov     byte [rdi], 8
    mov     byte [rdi + 1], 0
    mov     word [rdi + 4], 0xF1D0
    inc     word [rel ping_seq]
    mov     ax, [rel ping_seq]
    mov     [rdi + 6], ax
    mov     dword [rdi + 8], 0x00C0FFEE
    mov     dword [rdi + 12], 0
    mov     dword [rdi + 16], 0
    mov     dword [rdi + 20], 0
    mov     dword [rdi + 24], 0
    mov     dword [rdi + 28], 0
    mov     dword [rdi + 32], 0
    mov     dword [rdi + 36], 0
    mov     rsi, rdi
    mov     rcx, 8 + 32
    call    checksum
    mov     [rdi + 2], ax

    mov     rdi, tx_buf
    mov     rsi, 74
    call    tx_pacote

    mov     rcx, 20000000
.espera_reply:
    mov     rax, [rel ping_seq]
    call    rx_processa
    test    rax, rax
    jnz     .sucesso
    dec     rcx
    jnz     .espera_reply

.erro:
    mov     rsi, msg_ping_erro
    call    print_string
    call    print_newline
    xor     eax, eax
    jmp     .fim
.sucesso:
    mov     rsi, msg_ping_sucesso
    call    print_string
    call    print_newline
    mov     eax, 1
.fim:
    pop     rcx
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ==========================================
; ARP REQUEST
; ==========================================
arp_request:
    push    rax
    mov     rdi, tx_buf
    mov     qword [rdi], 0xFFFFFFFFFFFF
    mov     ax, [rel mac_addr]
    mov     [rdi + 6], ax
    mov     ax, [rel mac_addr + 2]
    mov     [rdi + 8], ax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 10], ax
    mov     word [rdi + 12], ETH_P_ARP
    add     rdi, 14
    mov     word [rdi], 1
    mov     word [rdi + 2], ETH_P_IP
    mov     byte [rdi + 4], 6
    mov     byte [rdi + 5], 4
    mov     word [rdi + 6], 1
    mov     ax, [rel mac_addr]
    mov     [rdi + 8], ax
    mov     ax, [rel mac_addr + 2]
    mov     [rdi + 10], ax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 12], ax
    mov     eax, [rel meu_ip]
    mov     [rdi + 14], eax
    mov     qword [rdi + 18], 0
    mov     eax, [rel ping_ip_dst]
    mov     [rdi + 24], eax
    mov     rdi, tx_buf
    mov     rsi, 14 + 28
    call    tx_pacote
    pop     rax
    ret

; ==========================================
; PROCESSA RX
; ==========================================
rx_processa:
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi

    xor     rbx, rbx
.rxloop:
    mov     rdx, [rel nic_mmio_base]
    mov     eax, [rdx + E1000_RDT]
    and     eax, NUM_RX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    add     rcx, rx_ring
    movzx   eax, byte [rcx + 14]
    test    eax, 1
    jz      .fim

    movzx   esi, word [rcx + 8]
    mov     rdi, [rcx]
    add     [rx_bytes_total], rsi

    cmp     esi, 42
    jb      .nao_arp
    cmp     word [rdi + 12], ETH_P_ARP
    jne     .nao_arp
    cmp     word [rdi + 20], 2
    jne     .nao_arp
    mov     eax, [rdi + 28]
    lea     rsi, [rdi + 22]
    call    arp_grava
    jmp     .consumir
.nao_arp:
    cmp     esi, 54
    jb      .consumir
    cmp     word [rdi + 12], ETH_P_IP
    jne     .consumir
    cmp     byte [rdi + 23], 1
    jne     .consumir
    cmp     byte [rdi + 34], 0
    jne     .consumir
    movzx   rax, word [rel ping_id]
    cmp     [rdi + 38], ax
    jne     .consumir
    movzx   rax, word [rel ping_seq]
    cmp     [rdi + 40], ax
    jne     .consumir
    mov     rbx, 1
.consumir:
    mov     rdx, [rel nic_mmio_base]
    mov     eax, [rdx + E1000_RDT]
    and     eax, NUM_RX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    add     rcx, rx_ring
    mov     rax, rcx
    shr     rax, 4
    imul    rax, RX_BUF_SIZE
    add     rax, rx_bufs
    mov     [rcx], rax
    mov     dword [rcx + 8], 0
    mov     eax, [rdx + E1000_RDT]
    inc     eax
    and     eax, NUM_RX_DESC - 1
    mov     [rdx + E1000_RDT], eax
    jmp     .rxloop

.fim:
    mov     eax, ebx
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ==========================================
; string_para_ip: rdi=string -> eax big-endian
; ==========================================
string_para_ip:
    push    rbx
    push    rcx
    push    rsi
    xor     eax, eax
    xor     ebx, ebx
    mov     rsi, rdi
.pc:
    movzx   ecx, byte [rsi]
    inc     rsi
    cmp     cl, '.'
    je      .arm
    test    cl, cl
    jz      .armfim
    sub     cl, '0'
    imul    ebx, ebx, 10
    movzx   ecx, cl
    add     ebx, ecx
    jmp     .pc
.arm:
    shl     eax, 8
    or      eax, ebx
    xor     ebx, ebx
    jmp     .pc
.armfim:
    shl     eax, 8
    or      eax, ebx
    pop     rsi
    pop     rcx
    pop     rbx
    ret

; ==========================================
; ✅ Função em falta: ip_para_string (eax=IP, rdi=buf)
; ==========================================
ip_para_string:
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi

    mov     rcx, 4
.oct_loop:
    mov     edx, eax
    shr     edx, 24
    call    escreve_num
    cmp     rcx, 1
    je      .ip_fim
    mov     al, '.'
    stosb
    shl     eax, 8
    dec     rcx
    jmp     .oct_loop
.ip_fim:
    mov     al, 0
    stosb
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

; ==========================================
; Acessores
; ==========================================
rede_ler_iface_nome:
    mov     rax, str_iface
    ret

rede_ler_mac:
    mov     rax, mac_addr
    ret

rede_ler_ip:
    mov     rax, str_ip
    ret

rede_ler_mascara:
    mov     rax, str_mask
    ret

rede_ler_gateway:
    mov     rax, str_gw
    ret

rede_ler_dns:
    mov     rax, str_dns
    ret

rede_ler_status_link:
    mov     rax, [rel nic_ok]
    test    rax, rax
    jz      .zero
    mov     rax, 1
    ret
.zero:
    xor     rax, rax
    ret

rede_ler_bytes_rx:
    mov     rax, [rel rx_bytes_total]
    ret

rede_ler_bytes_tx:
    mov     rax, [rel tx_bytes_total]
    ret

rede_ler_wifi_disponiveis:
    xor     rax, rax
    ret
rede_conectar_wifi:
    xor     rax, rax
    ret
rede_desconectar_wifi:
    xor     rax, rax
    ret
rede_ler_tabela_arp:
    mov     rax, msg_arp_vazia
    ret
rede_ler_conexoes:
    xor     rax, rax
    ret

; ==========================================
; TRACEROUTE REAL
; ==========================================
rede_exec_traceroute:
    push    rbx
    push    rsi
    push    rdi
    push    rcx

    mov     rax, [rel nic_ok]
    test    rax, rax
    jnz     .hw_ok
    call    inicializar_nic_mmio
    test    rax, rax
    jz      .erro
.hw_ok:
    call    esperar_link
    test    eax, eax
    jz      .erro

    call    string_para_ip
    mov     [rel ping_ip_dst], eax
    mov     ebx, eax
    inc     word [rel ping_id]

    mov     dword [rel tr_ttl], 1
.hop_loop:
    mov     eax, ebx
    call    arp_procura
    test    rdi, rdi
    jnz     .tem_mac
    mov     eax, ebx
    call    arp_request
    mov     rcx, 20000000
.ea:
    xor     eax, eax
    call    rx_processa
    mov     eax, ebx
    call    arp_procura
    test    rdi, rdi
    jnz     .tem_mac
    dec     rcx
    jnz     .ea
    jmp     .erro
.tem_mac:
    mov     r8, rdi
    call    montar_eth_ip_icmp

    mov     rdi, tx_buf
    mov     rsi, 74
    call    tx_pacote

    mov     rcx, 20000000
.er:
    mov     eax, [rel tr_ttl]
    call    rx_processa_tr
    test    rax, rax
    jnz     .tem_resposta
    dec     rcx
    jnz     .er
    mov     rsi, msg_tr_timeout
    call    print_string
    jmp     .prox_hop

.tem_resposta:
    cmp     rax, 2
    je      .final
    mov     eax, [rel tr_hop_ip]
    call    print_ip
    call    print_newline
    jmp     .prox_hop
.final:
    mov     eax, [rel tr_hop_ip]
    call    print_ip
    mov     rsi, msg_tr_fim
    call    print_string
    call    print_newline
    mov     eax, 1
    jmp     .fim

.prox_hop:
    inc     dword [rel tr_ttl]
    cmp     dword [rel tr_ttl], 15
    jle     .hop_loop
    mov     eax, 1
    jmp     .fim
.erro:
    mov     rsi, msg_tr_timeout
    call    print_string
    call    print_newline
    xor     eax, eax
.fim:
    pop     rcx
    pop     rdi
    pop     rsi
    pop     rbx
    ret
    
montar_eth_ip_icmp:
    push    rax
    push    rcx
    mov     rdi, tx_buf
    mov     ax, [r8]
    mov     [rdi], ax
    mov     ax, [r8 + 2]
    mov     [rdi + 2], ax
    mov     ax, [r8 + 4]
    mov     [rdi + 4], ax
    mov     ax, [rel mac_addr]
    mov     [rdi + 6], ax
    mov     ax, [rel mac_addr + 2]
    mov     [rdi + 8], ax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 10], ax
    mov     word [rdi + 12], ETH_P_IP
    add     rdi, 14

    mov     byte [rdi], 0x45
    mov     byte [rdi + 1], 0
    mov     word [rdi + 2], 60
    mov     word [rdi + 4], 0x1234
    mov     word [rdi + 6], 0x4000
    mov     eax, [rel tr_ttl]
    mov     [rdi + 8], al
    mov     byte [rdi + 9], 1
    mov     eax, [rel meu_ip]
    mov     [rdi + 12], eax
    mov     [rdi + 16], ebx
    mov     rcx, 20
    call    checksum
    mov     [rdi + 10], ax
    add     rdi, 20

    mov     byte [rdi], 8
    mov     byte [rdi + 1], 0
    movzx   eax, word [rel ping_id]
    mov     [rdi + 4], ax
    mov     eax, [rel tr_ttl]
    mov     [rdi + 6], ax
    mov     dword [rdi + 8], 0x00C0FFEE
    mov     dword [rdi + 12], 0
    mov     dword [rdi + 16], 0
    mov     dword [rdi + 20], 0
    mov     dword [rdi + 24], 0
    mov     dword [rdi + 28], 0
    mov     dword [rdi + 32], 0
    mov     dword [rdi + 36], 0
    mov     rcx, 40
    call    checksum
    mov     [rdi + 2], ax
    pop     rcx
    pop     rax
    ret

rx_processa_tr:
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi

    xor     rbx, rbx
.rxloop:
    mov     rdx, [rel nic_mmio_base]
    mov     eax, [rdx + E1000_RDT]
    and     eax, NUM_RX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    add     rcx, rx_ring
    movzx   eax, byte [rcx + 14]
    test    eax, 1
    jz      .fim

    movzx   esi, word [rcx + 8]
    mov     rdi, [rcx]

    cmp     esi, 42
    jb      .chk_icmp
    cmp     word [rdi + 12], ETH_P_ARP
    jne     .chk_icmp
    cmp     word [rdi + 20], 2
    jne     .chk_icmp
    mov     eax, [rdi + 28]
    lea     rsi, [rdi + 22]
    call    arp_grava
    jmp     .consumir

.chk_icmp:
    cmp     esi, 54
    jb      .consumir
    cmp     word [rdi + 12], ETH_P_IP
    jne     .consumir
    cmp     byte [rdi + 23], 1
    jne     .consumir
    movzx   eax, word [rel ping_id]
    cmp     [rdi + 38], ax
    jne     .consumir
    mov     eax, [rel tr_ttl]
    cmp     [rdi + 40], ax
    jne     .consumir

    movzx   eax, byte [rdi + 34]
    cmp     eax, 0
    jne     .chk_te
    mov     r8d, [rdi + 30]
    mov     [rel tr_hop_ip], r8d
    mov     rbx, 2
    jmp     .consumir
.chk_te:
    cmp     eax, ICMP_TIME_EXCEEDED
    jne     .consumir
    mov     r8d, [rdi + 30]
    mov     [rel tr_hop_ip], r8d
    mov     rbx, 1
.consumir:
    mov     rdx, [rel nic_mmio_base]
    mov     eax, [rdx + E1000_RDT]
    and     eax, NUM_RX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    add     rcx, rx_ring
    mov     rax, rcx
    shr     rax, 4
    imul    rax, RX_BUF_SIZE
    add     rax, rx_bufs
    mov     [rcx], rax
    mov     dword [rcx + 8], 0
    mov     byte [rcx + 14], 0
    mov     eax, [rdx + E1000_RDT]
    inc     eax
    and     eax, NUM_RX_DESC - 1
    mov     [rdx + E1000_RDT], eax
    jmp     .rxloop

.fim:
    mov     eax, ebx
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

print_ip:
    push    rax
    push    rbx
    push    rcx
    push    rdx

    mov     rcx, 4
.oct:
    mov     edx, eax
    shr     edx, 24
    push    rax
    mov     eax, edx
    call    print_num
    pop     rax
    cmp     rcx, 1
    je      .fim
    mov     rsi, '.'
    push    rax
    mov     rax, rsi
    call    print_char
    pop     rax
    shl     eax, 8
    dec     rcx
    jmp     .oct
.fim:
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret
   
dhcp_exec:
    push    rbx
    push    rcx

    mov     dword [rel dhcp_xid], 0x1F2D3C4B
    xor     eax, eax
    call    dhcp_enviar
    mov     rcx, 20000000
.esp_offer:
    call    rx_processa_dhcp
    cmp     rax, 2
    je      .offer_ok
    dec     rcx
    jnz     .esp_offer
    jmp     .fail

.offer_ok:
    mov     eax, 1
    call    dhcp_enviar
    mov     rcx, 20000000
.esp_ack:
    call    rx_processa_dhcp
    cmp     rax, 5
    je      .ack_ok
    dec     rcx
    jnz     .esp_ack
    jmp     .fail

.ack_ok:
    mov     eax, [rel dhcp_ip_obtido]
    mov     rdi, ip_str_tmp
    call    ip_para_string
    mov     rsi, ip_str_tmp
    mov     rdi, str_ip
.cpy:
    lodsb
    stosb
    test    al, al
    jnz     .cpy

    mov     eax, [rel dhcp_mask]
    mov     rdi, str_mask
    call    ip_para_string_em
    mov     eax, [rel dhcp_gw]
    mov     rdi, str_gw
    call    ip_para_string_em

    mov     rsi, msg_dhcp_ok
    call    print_string
    call    print_newline
    mov     eax, 1
    jmp     .fim
.fail:
    mov     rsi, msg_dhcp_fail
    call    print_string
    call    print_newline
    xor     eax, eax
.fim:
    pop     rcx
    pop     rbx
    ret

dhcp_enviar:
    push    rax
    push    rbx
    push    rcx
    push    rdi
    push    rsi

    mov     rbx, rax
    mov     rdi, tx_buf

    mov     qword [rdi], 0xFFFFFFFFFFFF
    mov     ax, [rel mac_addr]
    mov     [rdi + 6], ax
    mov     ax, [rel mac_addr + 2]
    mov     [rdi + 8], ax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 10], ax
    mov     word [rdi + 12], ETH_P_IP
    add     rdi, 14

    mov     byte [rdi], 0x45
    mov     byte [rdi + 1], 0
    mov     word [rdi + 2], 20 + 8 + 300
    mov     word [rdi + 4], 0
    mov     word [rdi + 6], 0
    mov     byte [rdi + 8], 64
    mov     byte [rdi + 9], IP_PROTO_UDP
    mov     dword [rdi + 12], 0
    mov     dword [rdi + 16], 0xFFFFFFFF
    mov     rcx, 20
    call    checksum
    mov     [rdi + 10], ax
    add     rdi, 20

    mov     word [rdi], DHCP_CLIENT_PORT
    mov     word [rdi + 2], DHCP_SERVER_PORT
    mov     word [rdi + 4], 8 + 300
    mov     word [rdi + 6], 0
    add     rdi, 8

    mov     byte [rdi], 1
    mov     byte [rdi + 1], 1
    mov     byte [rdi + 2], 6
    mov     byte [rdi + 3], 0
    mov     eax, [rel dhcp_xid]
    mov     [rdi + 4], eax
    mov     word [rdi + 8], 0
    mov     word [rdi + 10], 0x8000
    mov     dword [rdi + 12], 0
    mov     dword [rdi + 16], 0
    mov     dword [rdi + 20], 0
    mov     dword [rdi + 24], 0
    mov     ax, [rel mac_addr]
    mov     [rdi + 28], ax
    mov     ax, [rel mac_addr + 2]
    mov     [rdi + 30], ax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 32], ax
    mov     byte [rdi + 34], 0
    mov     byte [rdi + 35], 0
    mov     dword [rdi + 36], 0x63825363
    add     rdi, 240

    mov     byte [rdi], 99
    mov     byte [rdi + 1], 130
    mov     byte [rdi + 2], 83
    mov     byte [rdi + 3], 99
    add     rdi, 4

    mov     byte [rdi], DHCP_OPT_MSGTYPE
    mov     byte [rdi + 1], 1
    test    rbx, rbx
    jnz     .req
    mov     byte [rdi + 2], DHCP_MSG_DISCOVER
    jmp     .apos_tipo
.req:
    mov     byte [rdi + 2], DHCP_MSG_REQUEST
    mov     byte [rdi + 3], DHCP_OPT_REQIP
    mov     byte [rdi + 4], 4
    mov     eax, [rel dhcp_ip_obtido]
    mov     [rdi + 5], eax
    mov     byte [rdi + 9], DHCP_OPT_SRVIDENT
    mov     byte [rdi + 10], 4
    mov     eax, [rel dhcp_srv_ip]
    mov     [rdi + 11], eax
    add     rdi, 15
    jmp     .fim_opts
.apos_tipo:
    add     rdi, 3
.fim_opts:
    mov     byte [rdi], DHCP_OPT_END

    mov     rdi, tx_buf
    mov     rsi, 342
    call    tx_pacote
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rbx
    pop     rax
    ret

rx_processa_dhcp:
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi

    xor     rbx, rbx
.loop:
    mov     rdx, [rel nic_mmio_base]
    mov     eax, [rdx + E1000_RDT]
    and     eax, NUM_RX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    add     rcx, rx_ring
    movzx   eax, byte [rcx + 14]
    test    eax, 1
    jz      .fim
    movzx   esi, word [rcx + 8]
    mov     rdi, [rcx]

    cmp     esi, 300
    jb      .consumir
    cmp     word [rdi + 12], ETH_P_IP
    jne     .consumir
    cmp     byte [rdi + 23], IP_PROTO_UDP
    jne     .consumir
    cmp     word [rdi + 36], DHCP_CLIENT_PORT
    jne     .consumir
    cmp     dword [rdi + 38], 0x63825363
    jne     .consumir

.parse:
    mov     r8d, [rdi + 46]
    mov     [rel dhcp_ip_obtido], r8d
    mov     rsi, rdi
    add     rsi, 14 + 20 + 8 + 240
.opts:
    movzx   eax, byte [rsi]
    cmp     eax, DHCP_OPT_END
    je      .fim_opts
    test    eax, eax
    jz      .next
    movzx   rcx, byte [rsi + 1]
    cmp     eax, DHCP_OPT_MSGTYPE
    jne     .chk_mask
    movzx   eax, byte [rsi + 2]
    mov     rbx, rax
    jmp     .next
.chk_mask:
    cmp     eax, 1
    jne     .chk_gw
    mov     eax, [rsi + 2]
    mov     [rel dhcp_mask], eax
    jmp     .next
.chk_gw:
    cmp     eax, 3
    jne     .chk_srv
    mov     eax, [rsi + 2]
    mov     [rel dhcp_gw], eax
    jmp     .next
.chk_srv:
    cmp     eax, DHCP_OPT_SRVIDENT
    jne     .next
    mov     eax, [rsi + 2]
    mov     [rel dhcp_srv_ip], eax
    jmp     .next
.next:
    add     rsi, 2
    add     rsi, rcx
    jmp     .opts
.fim_opts:
    jmp     .consumir

.consumir:
    mov     rdx, [rel nic_mmio_base]
    mov     eax, [rdx + E1000_RDT]
    and     eax, NUM_RX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    add     rcx, rx_ring
    mov     rax, rcx
    shr     rax, 4
    imul    rax, RX_BUF_SIZE
    add     rax, rx_bufs
    mov     [rcx], rax
    mov     dword [rcx + 8], 0
    mov     byte [rcx + 14], 0
    mov     eax, [rdx + E1000_RDT]
    inc     eax
    and     eax, NUM_RX_DESC - 1
    mov     [rdx + E1000_RDT], eax
    jmp     .loop

.fim:
    mov     eax, ebx
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

ip_para_string_em:
    push    rax
    push    rbx
    push    rcx
    push    rdx

    mov     rcx, 4
.oct:
    mov     edx, eax
    shr     edx, 24
    call    escreve_num
    cmp     rcx, 1
    je      .fim
    mov     al, '.'
    stosb
    shl     eax, 8
    dec     rcx
    jmp     .oct
.fim:
    mov     al, 0
    stosb
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

escreve_num:
    push    rax
    push    rcx
    push    rdx
    mov     al, dl
    mov     dl, 0
    mov     rcx, 10
    xor     r8d, r8d
.div:
    xor     edx, edx
    div     rcx
    push    rdx
    inc     r8d
    test    al, al
    jnz     .div
.store:
    pop     rax
    add     al, '0'
    stosb
    dec     r8d
    jnz     .store
    pop     rdx
    pop     rcx
    pop     rax
    ret
