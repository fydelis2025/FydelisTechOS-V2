; ==========================================
; REDE BRIDGE REAL — FydelisTech OS (ICMP / E1000 legacy)
; Ping REAL + Suporte RX/TX para DHCP e IP Fixo
; FydelisTech OS v4.2 · Salvador • Bahia 🇧🇷
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
global inicializar_nic_mmio
global rede_definir_ip_estatico

; Exportações para integração com dhcp.asm
global tx_pacote
global rx_processa
global ip_para_string
global meu_ip
global mascara_rede
global gateway_ip
global dns_ip
global mac_addr

extern pci_ler_bar0
extern pci_ler_dispositivo
extern pci_ler_classe
extern print_string, print_newline, print_num, print_char

; --- Registradores E1000 ---
E1000_CTRL          equ 0x0000
E1000_STATUS        equ 0x0008      ; bit 1 = LU (link up)
E1000_EERD          equ 0x0014
E1000_ICR           equ 0x00C0
E1000_RCTL          equ 0x0100
E1000_TCTL          equ 0x0400
E1000_RDBAL         equ 0x2800
E1000_RDLEN         equ 0x2808
E1000_RDH           equ 0x2810
E1000_RDT           equ 0x2818
E1000_TDBAL         equ 0x3800
E1000_TDLEN         equ 0x3808
E1000_TDH           equ 0x3810
E1000_TDT           equ 0x3818

; --- Constantes ---
IP_PROTO_ICMP       equ 1
IP_PROTO_UDP        equ 17
DHCP_SERVER_PORT    equ 67
DHCP_CLIENT_PORT    equ 68

NUM_TX_DESC         equ 8
NUM_RX_DESC         equ 32
RX_BUF_SIZE         equ 2048
ETH_P_IP            equ 0x0008      ; 0x0800 em network byte order (big-endian na memória)
ETH_P_ARP           equ 0x0608      ; 0x0806 em network byte order

ICMP_TIME_EXCEEDED  equ 11
TRACEROTE_MAX_HOPS  equ 15

section .data
str_iface:          db 'e1000e0',0
str_ip:             db '10.0.2.15',0,0,0,0,0,0,0
str_mask:           db '255.255.255.0',0,0,0
str_gw:             db '10.0.2.2',0,0,0,0,0,0,0,0
str_dns:            db '10.0.2.3',0,0,0,0,0,0,0,0

; IPs em big-endian host (0x0A00020F = 10.0.2.15)
meu_ip:             dd 0x0A00020F
mascara_rede:       dd 0xFFFFFF00
gateway_ip:         dd 0x0A000202
dns_ip:             dd 0x0A000203

msg_ping_enviando:  db 'Enviando ICMP Echo Request real...',0
msg_ping_sucesso:   db 'Resposta ICMP recebida!',0
msg_ping_erro:      db 'Sem resposta ICMP (NIC/link/destino).',0
msg_sem_link:       db 'NIC: link down.',0
msg_tr_hop:         db ' hop: ',0
msg_tr_fim:         db 'Traceroute concluido.',0
msg_tr_timeout:     db ' *',0
msg_tr_unico:       db 'traceroute: ',0
msg_arp_vazia:      db 'Tabela ARP vazia ou sem conexoes ativas.',0

section .bss
align 4096
nic_mmio_base:      resq 1
nic_ok:             resq 1
mac_addr:           resb 6
rx_idx_sw:          resd 1

tr_ttl:             resd 1
tr_hop_ip:          resd 1

align 4096
tx_ring:            resb NUM_TX_DESC * 16
tx_buf:             resb 2048

align 4096
rx_ring:            resb NUM_RX_DESC * 16
rx_bufs:            resb NUM_RX_DESC * RX_BUF_SIZE

arp_ips:            resd 8
arp_macs:           resb 8 * 8

ping_id:            resw 1
ping_seq:           resw 1
ping_ip_dst:        resd 1
rx_bytes_total:     resq 1
tx_bytes_total:     resq 1

section .text

; ==========================================
; MMIO helpers
; ==========================================
nic_read_reg:
    mov     rax, [rel nic_mmio_base]
    mov     eax, [rax + rdi]
    ret

nic_write_reg:
    mov     rax, [rel nic_mmio_base]
    mov     [rax + rdi], esi
    ret

; ==========================================
; 🔧 APLICAR IP FIXO / ATUALIZAR PILHA TCP/IP
; Entrada: edi = IP (big-endian host, ex: 0x0A00020F = 10.0.2.15)
;          esi = Máscara (ex: 0xFFFFFF00 = 255.255.255.0)
;          edx = Gateway (ex: 0x0A000202 = 10.0.2.2)
; ==========================================
rede_definir_ip_estatico:
    push    rbx
    push    rdi
    push    rsi
    push    rdx

    mov     [rel meu_ip], edi
    mov     [rel mascara_rede], esi
    mov     [rel gateway_ip], edx
    mov     [rel dns_ip], edx

    ; Atualiza strings exibidas na UI e no terminal
    mov     eax, edi
    lea     rdi, [rel str_ip]
    call    ip_para_string

    mov     eax, [rsp + 8]          ; esi (mascara)
    lea     rdi, [rel str_mask]
    call    ip_para_string

    mov     eax, [rsp]              ; edx (gateway)
    lea     rdi, [rel str_gw]
    call    ip_para_string

    mov     eax, [rsp]              ; edx (dns)
    lea     rdi, [rel str_dns]
    call    ip_para_string

    pop     rdx
    pop     rsi
    pop     rdi
    pop     rbx
    mov     rax, 1
    ret

; ==========================================
; INICIALIZAÇÃO REAL DA NIC (E1000)
; ==========================================
inicializar_nic_mmio:
    push    rbx
    push    rcx
    push    rdx
    push    r12

    xor     ebx, ebx
.busca:
    mov     rcx, rbx
    mov     rdi, rbx
    call    pci_ler_dispositivo
    cmp     eax, 0xFFFFFFFF
    je      .prox

    mov     rcx, rbx
    mov     rdi, rbx
    call    pci_ler_classe
    and     eax, 0xFFFF0000
    cmp     eax, 0x02000000
    je      .achou
.prox:
    inc     ebx
    cmp     ebx, 256
    jl      .busca
    xor     eax, eax
    jmp     .fim

.achou:
    mov     rcx, rbx
    mov     rdi, rbx
    call    pci_ler_bar0
    and     rax, 0xFFFFFFF0
    mov     [rel nic_mmio_base], rax
    mov     r12, rax
    test    r12, r12
    jz      .fim

    ; Reset da E1000
    mov     rdi, E1000_CTRL
    mov     esi, 0x04000000
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
    ; Configura Link Up (SLU = bit 6)
    mov     rdi, E1000_CTRL
    call    nic_read_reg
    or      eax, (1 << 6)
    mov     esi, eax
    mov     rdi, E1000_CTRL
    call    nic_write_reg

    ; Leitura do MAC
    mov     ax, [r12 + 0x5400]
    mov     [rel mac_addr], ax
    mov     ax, [r12 + 0x5402]
    mov     [rel mac_addr + 2], ax
    mov     ax, [r12 + 0x5404]
    mov     [rel mac_addr + 4], ax

    ; Buffers de RX nos descritores
    xor     rcx, rcx
.fillrx:
    mov     rax, rcx
    imul    rax, RX_BUF_SIZE
    lea     r8, [rel rx_bufs]
    add     rax, r8
    mov     rdx, rcx
    shl     rdx, 4
    lea     r8, [rel rx_ring]
    add     rdx, r8
    mov     [rdx], rax
    mov     qword [rdx + 8], 0
    inc     rcx
    cmp     rcx, NUM_RX_DESC
    jl      .fillrx

    mov     dword [rel rx_idx_sw], 0

    ; RX ring
    mov     rdi, E1000_RDBAL
    lea     rax, [rel rx_ring]
    mov     esi, eax
    call    nic_write_reg
    mov     rdi, E1000_RDLEN
    mov     esi, NUM_RX_DESC * 16
    call    nic_write_reg
    mov     rdi, E1000_RDH
    xor     esi, esi
    call    nic_write_reg
    mov     rdi, E1000_RDT
    mov     esi, NUM_RX_DESC - 1
    call    nic_write_reg

    ; TX ring
    mov     rdi, E1000_TDBAL
    lea     rax, [rel tx_ring]
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

    ; Habilita TX e RX (inclui Broadcast Accept Mode bit 15 no RCTL para DHCP)
    mov     rdi, E1000_TCTL
    mov     esi, 0x0A
    call    nic_write_reg
    mov     rdi, E1000_RCTL
    mov     esi, 0x8022
    call    nic_write_reg

    mov     qword [rel nic_ok], 1
    mov     eax, 1
.fim:
    pop     r12
    pop     rdx
    pop     rcx
    pop     rbx
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
; TRANSMITIR FRAME ETHERNET: rdi=buf, rsi=len
; ==========================================
tx_pacote:
    push    rax
    push    rcx
    push    rdx

    mov     rdx, [rel nic_mmio_base]
    test    rdx, rdx
    jz      .fim_tx

    mov     eax, [rdx + E1000_TDT]
    and     eax, NUM_TX_DESC - 1
    mov     rcx, rax
    shl     rcx, 4
    lea     r8, [rel tx_ring]
    add     rcx, r8
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
    add     rcx, r8
.wdd:
    movzx   eax, byte [rcx + 12]
    test    eax, 1
    jnz     .ok
    pause
    jmp     .wdd
.ok:
    add     [rel tx_bytes_total], rsi
.fim_tx:
    pop     rdx
    pop     rcx
    pop     rax
    ret

; ==========================================
; CHECKSUM IP/ICMP: rdi=ptr, rcx=len -> ax
; ==========================================
checksum:
    push    rdi
    push    rcx
    push    rbx
    push    rdx
    xor     rbx, rbx
.lp:
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
    not     ax
    and     eax, 0xFFFF
    pop     rdx
    pop     rbx
    pop     rcx
    pop     rdi
    ret

; ==========================================
; ARP CACHE
; ==========================================
arp_procura:
    push    rcx
    xor     rcx, rcx
    lea     r8, [rel arp_ips]
.lp:
    cmp     [r8 + rcx*4], eax
    je      .achou
    inc     rcx
    cmp     rcx, 8
    jl      .lp
    xor     edi, edi
    pop     rcx
    ret
.achou:
    lea     rdi, [rel arp_macs]
    lea     rdi, [rdi + rcx*8]
    pop     rcx
    ret

arp_grava:
    push    rcx
    xor     rcx, rcx
    lea     r8, [rel arp_ips]
.lp:
    cmp     dword [r8 + rcx*4], 0
    je      .grava
    cmp     [r8 + rcx*4], eax
    je      .grava
    inc     rcx
    cmp     rcx, 8
    jl      .lp
    xor     ecx, ecx
.grava:
    mov     [r8 + rcx*4], eax
    lea     rdi, [rel arp_macs]
    lea     rdi, [rdi + rcx*8]
    mov     ax, [rsi]
    mov     [rdi], ax
    mov     ax, [rsi + 2]
    mov     [rdi + 2], ax
    mov     ax, [rsi + 4]
    mov     [rdi + 4], ax
    pop     rcx
    ret

; ==========================================
; PROCESSA RX UNIFICADO (ARP + ICMP + DHCP)
; Entrada opcional: rdi = buffer destino (se != 0, copia payload DHCP nele)
; Saída: rax = 1 se recebeu ICMP Reply ou copiou frame DHCP; 0 caso contrário
; ==========================================
rx_processa:
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi
    push    r12
    push    r13

    mov     r12, rdi                ; ponteiro opcional do chamador (ex: dhcp_rx_buf)
    xor     rbx, rbx

    mov     rdx, [rel nic_mmio_base]
    test    rdx, rdx
    jz      .fim

.rxloop:
    mov     eax, [rel rx_idx_sw]
    and     eax, NUM_RX_DESC - 1
    mov     r13d, eax
    mov     rcx, rax
    shl     rcx, 4
    lea     r8, [rel rx_ring]
    add     rcx, r8

    movzx   eax, byte [rcx + 12]    ; Status DD (Descriptor Done = bit 0)
    test    eax, 1
    jz      .fim

    movzx   esi, word [rcx + 8]     ; Comprimento do frame recebido
    mov     rdi, [rcx]              ; Ponteiro do buffer RX
    add     [rel rx_bytes_total], rsi

    ; 1. Verifica ARP Reply
    cmp     esi, 42
    jb      .nao_arp
    cmp     word [rdi + 12], ETH_P_ARP
    jne     .nao_arp
    cmp     word [rdi + 20], 0x0200 ; ARP Reply (2 em big-endian)
    jne     .nao_arp
    mov     eax, [rdi + 28]
    bswap   eax
    lea     rsi, [rdi + 22]
    call    arp_grava
    jmp     .consumir

.nao_arp:
    cmp     esi, 54
    jb      .consumir
    cmp     word [rdi + 12], ETH_P_IP
    jne     .consumir

    ; 2. Verifica UDP Porta 68 (DHCP Client) -> entrega ao dhcp_rx_buf
    cmp     byte [rdi + 23], IP_PROTO_UDP
    jne     .chk_icmp
    cmp     word [rdi + 36], 0x4400 ; Porta 68 em big-endian (0x0044)
    jne     .chk_icmp

    test    r12, r12
    jz      .consumir
    mov     ecx, esi
    sub     ecx, 42                 ; Pula 14(ETH) + 20(IP) + 8(UDP) = início BOOTP
    cmp     ecx, 590
    jbe     .copia_dhcp
    mov     ecx, 590
.copia_dhcp:
    push    rsi
    push    rdi
    lea     rsi, [rdi + 42]
    mov     rdi, r12
    rep     movsb
    pop     rdi
    pop     rsi
    mov     rbx, 1
    jmp     .consumir

.chk_icmp:
    ; 3. Verifica ICMP Echo Reply
    cmp     byte [rdi + 23], IP_PROTO_ICMP
    jne     .consumir
    cmp     byte [rdi + 34], 0
    jne     .consumir
    movzx   rax, word [rel ping_seq]
    xchg    al, ah
    cmp     [rdi + 40], ax
    jne     .consumir
    mov     rbx, 1

.consumir:
    mov     rax, r13
    shl     rax, 4
    lea     r8, [rel rx_ring]
    add     rcx, r8
    mov     qword [rcx + 8], 0      ; Limpa length, status e errors

    mov     rdx, [rel nic_mmio_base]
    mov     [rdx + E1000_RDT], r13d

    inc     r13d
    and     r13d, NUM_RX_DESC - 1
    mov     [rel rx_idx_sw], r13d

    test    rbx, rbx
    jnz     .fim
    jmp     .rxloop

.fim:
    mov     eax, ebx
    pop     r13
    pop     r12
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
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

    lea     rsi, [rel msg_ping_enviando]
    call    print_string
    call    print_newline

    call    string_para_ip
    mov     [rel ping_ip_dst], eax
    mov     ebx, eax

    ; Se destino estiver fora da sub-rede local, resolve ARP do gateway
    mov     ecx, [rel meu_ip]
    xor     ecx, ebx
    and     ecx, [rel mascara_rede]
    jz      .mesma_rede
    mov     ebx, [rel gateway_ip]
    mov     [rel ping_ip_dst], ebx
.mesma_rede:
    mov     eax, ebx
    call    arp_procura
    test    rdi, rdi
    jnz     .tem_mac
    mov     eax, ebx
    call    arp_request
    mov     rcx, 20000000
.espera_arp:
    xor     edi, edi
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
    lea     rdi, [rel tx_buf]
    mov     eax, [r8]
    mov     [rdi], eax
    mov     ax, [r8 + 4]
    mov     [rdi + 4], ax

    mov     eax, [rel mac_addr]
    mov     [rdi + 6], eax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 10], ax
    mov     word [rdi + 12], ETH_P_IP
    add     rdi, 14

    ; Cabeçalho IPv4
    mov     byte [rdi], 0x45
    mov     byte [rdi + 1], 0
    mov     word [rdi + 2], 0x3C00  ; 60 bytes big-endian
    mov     word [rdi + 4], 0x3412
    mov     word [rdi + 6], 0x0040
    mov     byte [rdi + 8], 64
    mov     byte [rdi + 9], 1
    mov     word [rdi + 10], 0

    mov     eax, [rel meu_ip]
    bswap   eax
    mov     [rdi + 12], eax

    mov     eax, [rel ping_ip_dst]
    bswap   eax
    mov     [rdi + 16], eax

    mov     rcx, 20
    call    checksum
    mov     [rdi + 10], ax
    add     rdi, 20

    ; Cabeçalho ICMP Echo Request
    mov     byte [rdi], 8
    mov     byte [rdi + 1], 0
    mov     word [rdi + 2], 0
    mov     word [rdi + 4], 0xD0F1
    inc     word [rel ping_seq]
    mov     ax, [rel ping_seq]
    xchg    al, ah
    mov     [rdi + 6], ax
    mov     dword [rdi + 8], 0x00C0FFEE
    mov     rcx, 40
    call    checksum
    mov     [rdi + 2], ax

    lea     rdi, [rel tx_buf]
    mov     rsi, 74
    call    tx_pacote

    mov     rcx, 20000000
.espera_reply:
    xor     edi, edi
    call    rx_processa
    test    rax, rax
    jnz     .sucesso
    dec     rcx
    jnz     .espera_reply

.erro:
    lea     rsi, [rel msg_ping_erro]
    call    print_string
    call    print_newline
    xor     eax, eax
    jmp     .fim
.sucesso:
    lea     rsi, [rel msg_ping_sucesso]
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
    lea     rdi, [rel tx_buf]
    mov     dword [rdi], 0xFFFFFFFF
    mov     word [rdi + 4], 0xFFFF
    mov     eax, [rel mac_addr]
    mov     [rdi + 6], eax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 10], ax
    mov     word [rdi + 12], ETH_P_ARP
    add     rdi, 14

    mov     word [rdi], 0x0100      ; Ethernet (1)
    mov     word [rdi + 2], ETH_P_IP
    mov     byte [rdi + 4], 6
    mov     byte [rdi + 5], 4
    mov     word [rdi + 6], 0x0100  ; Request (1)

    mov     eax, [rel mac_addr]
    mov     [rdi + 8], eax
    mov     ax, [rel mac_addr + 4]
    mov     [rdi + 12], ax

    mov     eax, [rel meu_ip]
    bswap   eax
    mov     [rdi + 14], eax

    mov     dword [rdi + 18], 0
    mov     word [rdi + 22], 0

    mov     eax, [rel ping_ip_dst]
    bswap   eax
    mov     [rdi + 24], eax

    lea     rdi, [rel tx_buf]
    mov     rsi, 42
    call    tx_pacote
    pop     rax
    ret

; ==========================================
; CONVERSÕES IP <-> STRING (BIG-ENDIAN HOST)
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

escreve_num:
    push    rax
    push    rcx
    push    rdx
    movzx   eax, dl
    mov     ecx, 10
    xor     r8d, r8d
.div:
    xor     edx, edx
    div     rcx
    push    rdx
    inc     r8d
    test    eax, eax
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

; ==========================================
; ACESSORES PARA PAINEL / C / BROWSER
; ==========================================
rede_ler_iface_nome:
    lea     rax, [rel str_iface]
    ret
rede_ler_mac:
    lea     rax, [rel mac_addr]
    ret
rede_ler_ip:
    lea     rax, [rel str_ip]
    ret
rede_ler_mascara:
    lea     rax, [rel str_mask]
    ret
rede_ler_gateway:
    lea     rax, [rel str_gw]
    ret
rede_ler_dns:
    lea     rax, [rel str_dns]
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
    lea     rax, [rel msg_arp_vazia]
    ret
rede_ler_conexoes:
    xor     rax, rax
    ret
rede_exec_traceroute:
    xor     eax, eax
    ret
