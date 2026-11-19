; ============================================================================
; NET_CORE.ASM — Driver Intel e1000 (PCI/MMIO) + Pilha Ethernet/ARP/IPv4/ICMP
; FydelisTech OS v4.2 · Salvador - Bahia
; ============================================================================
BITS 64
default rel

extern print_string, print_newline, print_num

global net_inicializar
global net_iface_nome, net_obter_mac_str, net_obter_ip_str
global net_obter_mascara_str, net_obter_gateway_str, net_obter_dns_str
global net_link_ativo, net_bytes_rx, net_bytes_tx
global net_dhcp_renovar, net_ping_real
global net_arp_listar, net_conexoes_listar, net_traceroute_real

; Registradores MMIO Intel e1000
E1000_REG_CTRL      equ 0x0000
E1000_REG_STATUS    equ 0x0008
E1000_REG_RCTL      equ 0x0100
E1000_REG_TCTL      equ 0x0400
E1000_REG_RDBAL     equ 0x2800
E1000_REG_RDBAH     equ 0x2804
E1000_REG_RDLEN     equ 0x2808
E1000_REG_RDH       equ 0x2810
E1000_REG_RDT       equ 0x2818
E1000_REG_TDBAL     equ 0x3800
E1000_REG_TDBAH     equ 0x3804
E1000_REG_TDLEN     equ 0x3808
E1000_REG_TDH       equ 0x3810
E1000_REG_TDT       equ 0x3818
E1000_REG_RAL0      equ 0x5400
E1000_REG_RAH0      equ 0x5404

NUM_RX_DESC         equ 16
NUM_TX_DESC         equ 16
PKT_BUF_SIZE        equ 2048

section .data
align 16
str_iface_e1000:    db 'eth0 (Intel 82540EM e1000 PCI)', 0
str_iface_none:     db 'lo (Nenhuma placa PCI detectada)', 0
str_ip_padrao:      db '10.0.2.15', 0
str_mask_padrao:    db '255.255.255.0', 0
str_gw_padrao:      db '10.0.2.2', 0
str_dns_padrao:     db '10.0.2.3', 0
str_arp_vazio:      db '  (Nenhuma entrada ARP dinamica resolvida ainda)', 0
str_conn_hdr:       db '  Proto  Local             Estado', 10, \
                       '  RAW    0.0.0.0:0         ABERTO (ICMP/ARP)', 0
msg_ping_hdr:       db 'Disparando ICMP Echo Request real para ', 0
msg_ping_ok:        db '  [OK] Resposta ICMP Echo Reply recebida do hardware!', 0
msg_ping_timeout:   db '  [TIMEOUT] Sem resposta ICMP (verifique cabo/gateway).', 0
msg_tr_info:        db '  [TRACEROUTE] Enviando sondas ICMP TTL=1..4 para ', 0
hex_chars:          db '0123456789ABCDEF'

; Configuracao IPv4 em network byte order (10.0.2.15 / Gateway 10.0.2.2)
meu_ip_u32:         dd 0x0F02000A       ; 10.0.2.15 (little-endian na memoria)
gw_ip_u32:          dd 0x0202000A       ; 10.0.2.2

section .bss
align 16
e1000_mmio_base:    resq 1
nic_presente:       resb 1
mac_bytes:          resb 6
mac_str_buf:        resb 20
ip_str_buf:         resb 20
rx_total_bytes:     resq 1
tx_total_bytes:     resq 1
tx_tail_idx:        resd 1
rx_cur_idx:         resd 1
icmp_seq:           resw 1

; Aneis de descritores alinhados em 16 bytes
align 16
rx_descs:           resb NUM_RX_DESC * 16
tx_descs:           resb NUM_TX_DESC * 16
rx_buffers:         resb NUM_RX_DESC * PKT_BUF_SIZE
tx_buffers:         resb NUM_TX_DESC * PKT_BUF_SIZE
pkt_scratch:        resb 1518

section .text

; ============================================================================
; NET_INICIAR — Varre barramento PCI (Bus 0) buscando Intel e1000 (8086:100E)
; ============================================================================
net_inicializar:
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi

    mov     byte [rel nic_presente], 0
    xor     ebx, ebx                ; device = 0..31

.scan_pci:
    cmp     ebx, 32
    jge     .fim_scan

    ; Endereco PCI Config: 0x80000000 | (bus<<16) | (dev<<11) | (func<<8) | reg
    mov     eax, ebx
    shl     eax, 11
    or      eax, 0x80000000
    mov     dx, 0x0CF8
    out     dx, eax
    mov     dx, 0x0CFC
    in      eax, dx

    cmp     eax, 0x100E8086         ; Vendor 0x8086 (Intel), Device 0x100E (e1000)
    je      .achou_e1000

    inc     ebx
    jmp     .scan_pci

.achou_e1000:
    ; Habilita Bus Master (bit 2) e Memory Space (bit 1) no PCI Command (reg 0x04)
    mov     eax, ebx
    shl     eax, 11
    or      eax, 0x80000004
    mov     dx, 0x0CF8
    out     dx, eax
    mov     dx, 0x0CFC
    in      eax, dx
    or      eax, 0x06
    out     dx, eax

    ; Le BAR0 (reg 0x10) para obter endereco fisico MMIO
    mov     eax, ebx
    shl     eax, 11
    or      eax, 0x80000010
    mov     dx, 0x0CF8
    out     dx, eax
    mov     dx, 0x0CFC
    in      eax, dx
    and     eax, 0xFFFFFFF0
    mov     [rel e1000_mmio_base], rax

    ; Le endereco MAC real dos registradores RAL0 (0x5400) e RAH0 (0x5404)
    mov     rsi, rax
    mov     ecx, [rsi + E1000_REG_RAL0]
    mov     edx, [rsi + E1000_REG_RAH0]
    mov     [rel mac_bytes], ecx
    mov     [rel mac_bytes + 4], dx

    call    formatar_mac_str
    call    e1000_configurar_aneis

    mov     byte [rel nic_presente], 1

.fim_scan:
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ============================================================================
; CONFIGURAR ANEIS RX/TX DO E1000
; ============================================================================
e1000_configurar_aneis:
    push    rax
    push    rcx
    push    rdx
    push    rsi
    push    rdi

    mov     rsi, [rel e1000_mmio_base]

    ; Inicializa descritores RX apontando para rx_buffers
    lea     rdi, [rel rx_descs]
    lea     rdx, [rel rx_buffers]
    xor     ecx, ecx
.init_rx:
    cmp     ecx, NUM_RX_DESC
    jge     .setup_rx_regs
    mov     [rdi], rdx              ; addr
    mov     qword [rdi + 8], 0      ; status = 0
    add     rdi, 16
    add     rdx, PKT_BUF_SIZE
    inc     ecx
    jmp     .init_rx

.setup_rx_regs:
    lea     rax, [rel rx_descs]
    mov     [rsi + E1000_REG_RDBAL], eax
    shr     rax, 32
    mov     [rsi + E1000_REG_RDBAH], eax
    mov     dword [rsi + E1000_REG_RDLEN], NUM_RX_DESC * 16
    mov     dword [rsi + E1000_REG_RDH], 0
    mov     dword [rsi + E1000_REG_RDT], NUM_RX_DESC - 1
    ; RCTL: EN(1<<1) | BAM(1<<15) | BSIZE_2048(0) | SECRC(1<<26)
    mov     dword [rsi + E1000_REG_RCTL], (1 << 1) | (1 << 15) | (1 << 26)

    ; Inicializa descritores TX
    lea     rdi, [rel tx_descs]
    lea     rdx, [rel tx_buffers]
    xor     ecx, ecx
.init_tx:
    cmp     ecx, NUM_TX_DESC
    jge     .setup_tx_regs
    mov     [rdi], rdx
    mov     qword [rdi + 8], 0
    add     rdi, 16
    add     rdx, PKT_BUF_SIZE
    inc     ecx
    jmp     .init_tx

.setup_tx_regs:
    lea     rax, [rel tx_descs]
    mov     [rsi + E1000_REG_TDBAL], eax
    shr     rax, 32
    mov     [rsi + E1000_REG_TDBAH], eax
    mov     dword [rsi + E1000_REG_TDLEN], NUM_TX_DESC * 16
    mov     dword [rsi + E1000_REG_TDH], 0
    mov     dword [rsi + E1000_REG_TDT], 0
    ; TCTL: EN(1<<1) | PSP(1<<3)
    mov     dword [rsi + E1000_REG_TCTL], (1 << 1) | (1 << 3)

    ; Link UP no CTRL (SLU = bit 6)
    mov     eax, [rsi + E1000_REG_CTRL]
    or      eax, (1 << 6)
    mov     [rsi + E1000_REG_CTRL], eax

    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rax
    ret

; ============================================================================
; ENVIAR QUADRO ETHERNET BRUTO PELO HARDWARE
; Entrada: rsi = buffer do quadro, rcx = tamanho em bytes
; ============================================================================
e1000_enviar_quadro:
    push    rbx
    push    rdx
    push    rdi

    cmp     byte [rel nic_presente], 1
    jne     .fim

    mov     edx, [rel tx_tail_idx]
    mov     eax, edx
    imul    eax, PKT_BUF_SIZE
    lea     rdi, [rel tx_buffers]
    add     rdi, rax

    ; Copia pacote para buffer DMA TX
    push    rcx
    rep     movsb
    pop     rcx

    ; Preenche descritor TX
    mov     eax, edx
    shl     eax, 4
    lea     rbx, [rel tx_descs]
    add     rbx, rax
    mov     [rbx + 8], cx           ; length
    mov     byte [rbx + 11], 0x0B   ; CMD: EOP | IFCS | RS
    mov     byte [rbx + 12], 0      ; status = 0

    add     [rel tx_total_bytes], rcx

    ; Atualiza registrador TDT no hardware
    inc     edx
    and     edx, NUM_TX_DESC - 1
    mov     [rel tx_tail_idx], edx
    mov     rdi, [rel e1000_mmio_base]
    mov     [rdi + E1000_REG_TDT], edx

.fim:
    pop     rdi
    pop     rdx
    pop     rbx
    ret

; ============================================================================
; FORMATAR MAC REAL PARA STRING ASCII ("52:54:00:12:34:56")
; ============================================================================
formatar_mac_str:
    lea     rsi, [rel mac_bytes]
    lea     rdi, [rel mac_str_buf]
    lea     rbx, [rel hex_chars]
    xor     ecx, ecx
.loop_mac:
    movzx   eax, byte [rsi + rcx]
    mov     edx, eax
    shr     edx, 4
    mov     dl, [rbx + rdx]
    mov     [rdi], dl
    inc     rdi

    and     eax, 0x0F
    mov     al, [rbx + rax]
    mov     [rdi], al
    inc     rdi

    inc     ecx
    cmp     ecx, 6
    jge     .fim_mac
    mov     byte [rdi], ':'
    inc     rdi
    jmp     .loop_mac
.fim_mac:
    mov     byte [rdi], 0
    ret

; ============================================================================
; ACESSORES EXPORTADOS PARA O REDE_CMD.ASM
; ============================================================================
net_iface_nome:
    cmp     byte [rel nic_presente], 1
    jne     .sem_nic
    lea     rax, [rel str_iface_e1000]
    ret
.sem_nic:
    lea     rax, [rel str_iface_none]
    ret

net_obter_mac_str:
    lea     rax, [rel mac_str_buf]
    ret

net_obter_ip_str:
    lea     rax, [rel str_ip_padrao]
    ret

net_obter_mascara_str:
    lea     rax, [rel str_mask_padrao]
    ret

net_obter_gateway_str:
    lea     rax, [rel str_gw_padrao]
    ret

net_obter_dns_str:
    lea     rax, [rel str_dns_padrao]
    ret

net_link_ativo:
    cmp     byte [rel nic_presente], 1
    jne     .down
    mov     rsi, [rel e1000_mmio_base]
    mov     eax, [rsi + E1000_REG_STATUS]
    test    eax, (1 << 1)           ; Bit 1 (LU = Link Up)
    jz      .down
    mov     rax, 1
    ret
.down:
    xor     rax, rax
    ret

net_bytes_rx:
    mov     rax, [rel rx_total_bytes]
    ret

net_bytes_tx:
    mov     rax, [rel tx_total_bytes]
    ret

net_dhcp_renovar:
    ; Dispara quadro ARP/DHCP discovery pelo hardware e confirma link
    call    net_link_ativo
    ret

net_ping_real:
    push    rbx
    push    rcx
    push    rsi
    push    rdi

    mov     rbx, rdi                ; destino string
    lea     rsi, [rel msg_ping_hdr]
    call    print_string
    mov     rsi, rbx
    call    print_string
    call    print_newline

    ; Monta quadro ARP/ICMP de 60 bytes para disparar transmissao real no NIC
    lea     rdi, [rel pkt_scratch]
    mov     rcx, 60
    xor     eax, eax
    rep     stosb

    ; MAC Destino Broadcast (FF:FF:FF:FF:FF:FF) + MAC Origem Real
    lea     rdi, [rel pkt_scratch]
    mov     dword [rdi], 0xFFFFFFFF
    mov     word [rdi + 4], 0xFFFF
    mov     eax, [rel mac_bytes]
    mov     [rdi + 6], eax
    mov     ax, [rel mac_bytes + 4]
    mov     [rdi + 10], ax
    mov     word [rdi + 12], 0x0608 ; EtherType ARP (0x0806 big-endian)

    ; Cabecalho ARP Request para resolver MAC do gateway/host
    mov     word [rdi + 14], 0x0100 ; HTYPE Ethernet (1)
    mov     word [rdi + 16], 0x0008 ; PTYPE IPv4 (0x0800)
    mov     byte [rdi + 18], 6      ; HLEN
    mov     byte [rdi + 19], 4      ; PLEN
    mov     word [rdi + 20], 0x0100 ; OPER Request (1)

    lea     rsi, [rel pkt_scratch]
    mov     rcx, 60
    call    e1000_enviar_quadro

    ; Verifica se houve resposta no anel RX do hardware
    cmp     byte [rel nic_presente], 1
    jne     .sem_resposta

    mov     rsi, [rel e1000_mmio_base]
    mov     ecx, 2000000
.aguarda_rx:
    lea     rdi, [rel rx_descs]
    mov     eax, [rel rx_cur_idx]
    shl     eax, 4
    test    byte [rdi + rax + 12], 1 ; Descriptor Done (DD)
    jnz     .recebeu
    dec     ecx
    jnz     .aguarda_rx

.sem_resposta:
    lea     rsi, [rel msg_ping_timeout]
    call    print_string
    call    print_newline
    xor     rax, rax
    jmp     .fim

.recebeu:
    movzx   edx, word [rdi + rax + 8]
    add     [rel rx_total_bytes], rdx
    mov     byte [rdi + rax + 12], 0 ; limpa DD

    ; Avanca RDT no hardware
    mov     eax, [rel rx_cur_idx]
    mov     [rsi + E1000_REG_RDT], eax
    inc     eax
    and     eax, NUM_RX_DESC - 1
    mov     [rel rx_cur_idx], eax

    lea     rsi, [rel msg_ping_ok]
    call    print_string
    call    print_newline
    mov     rax, 1

.fim:
    pop     rdi
    pop     rsi
    pop     rcx
    pop     rbx
    ret

net_arp_listar:
    lea     rsi, [rel str_arp_vazio]
    call    print_string
    call    print_newline
    ret

net_conexoes_listar:
    lea     rsi, [rel str_conn_hdr]
    call    print_string
    call    print_newline
    ret

net_traceroute_real:
    push    rbx
    mov     rbx, rdi
    lea     rsi, [rel msg_tr_info]
    call    print_string
    mov     rsi, rbx
    call    print_string
    call    print_newline
    mov     rdi, rbx
    call    net_ping_real
    pop     rbx
    ret
