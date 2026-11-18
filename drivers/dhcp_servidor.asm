; ==========================================
; 🌐 DHCP UNIFICADO (SERVIDOR & CLIENTE RFC 2131)
; Encapsulamento Ethernet + IPv4 + UDP + Integração IP Fixo
; FydelisTech OS v4.2 — Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
DEFAULT REL
%include "fydelterm.inc"

; ========== PORTAS E CONSTANTES BOOTP/DHCP ==========
DHCP_SERVER_PORT    equ 67
DHCP_CLIENT_PORT    equ 68

BOOTP_OP_REQUEST    equ 1
BOOTP_OP_REPLY      equ 2
BOOTP_HTYPE_ETH     equ 1
BOOTP_HLEN_ETH      equ 6
DHCP_MAGIC_COOKIE   equ 0x63825363
DHCP_FLAG_BROADCAST equ 0x0080       ; 0x8000 em network byte order (big-endian)

DHCP_DISCOVER       equ 1
DHCP_OFFER          equ 2
DHCP_REQUEST        equ 3
DHCP_ACK            equ 5
DHCP_NAK            equ 6

; Opções DHCP (RFC 2132)
DHCP_OPT_PAD        equ 0
DHCP_OPT_SUBNET     equ 1
DHCP_OPT_GATEWAY    equ 3
DHCP_OPT_DNS        equ 6
DHCP_OPT_REQ_IP     equ 50
DHCP_OPT_LEASE      equ 51
DHCP_OPT_MSGTYPE    equ 53
DHCP_OPT_SERVERID   equ 54
DHCP_OPT_PARAM_LIST equ 55
DHCP_OPT_END        equ 255

; Estados do Cliente DHCP
DHCP_ST_IDLE        equ 0
DHCP_ST_DISCOVER    equ 1
DHCP_ST_REQUEST     equ 2
DHCP_ST_BOUND       equ 3

; ========== CONFIGURAÇÃO DO SERVIDOR EMBUTIDO ==========
SERVIDOR_IP         equ 0x0102000A   ; 10.0.2.1  (network byte order)
IP_INICIO           equ 0x1002000A   ; 10.0.2.16
IP_FIM              equ 0xFE02000A   ; 10.0.2.254
MASCARA             equ 0x00FFFFFF   ; 255.255.255.0
GATEWAY_IP          equ SERVIDOR_IP
DNS_IP              equ SERVIDOR_IP
TEMPO_CONCESSAO     equ 0x80510100   ; 86400s (24h) em big-endian
DHCP_PKT_TAM        equ 300
DHCP_FRAME_TAM      equ 342          ; 14 (ETH) + 20 (IP) + 8 (UDP) + 300 (BOOTP)

; ========== EXTERNAIS (REDE.ASM & KERNEL) ==========
extern tx_pacote, rx_processa
extern print_string, print_newline, print_num
extern ip_para_string
extern rede_definir_ip_estatico
extern inicializar_nic_mmio
extern mac_addr

; ========== EXPORTAÇÃO ==========
global dhcp_servidor_iniciar
global dhcp_servidor_processar
global dhcp_servidor_status
global dhcp_servidor_ativo
global dhcp_cliente_iniciar
global dhcp_cliente_processar
global dhcp_cliente_resetar
global dhcp_definir_mac
global dhcp_definir_ip_estatico
global dhcp_ler_status
global dhcp_ip_atual
global dhcp_mascara
global dhcp_gateway
global dhcp_dns

; ========== DADOS ==========
section .bss
align 4096
dhcp_servidor_ativo: resd 1
dhcp_proximo_ip:     resd 1
dhcp_clientes_mac:   resb 32 * 6
dhcp_clientes_ip:    resd 32
dhcp_qtd_clientes:   resd 1

dhcp_estado:         resd 1
dhcp_ip_atual:       resd 1
dhcp_ip_ofertado:    resd 1
dhcp_servidor_remoto:resd 1
dhcp_mascara:        resd 1
dhcp_gateway:        resd 1
dhcp_dns:            resd 1
dhcp_xid:            resd 1
dhcp_mac_local:      resb 6
                     resb 2          ; padding de alinhamento

dhcp_rx_buf:         resb 600
dhcp_tx_buf:         resb 600
dhcp_eth_frame:      resb 600
ip_buf:              resb 20

section .data
str_dhcp_ativo:      db '  [OK] DHCP Servidor ativo - 10.0.2.1',0
str_dhcp_parado:     db '  [!] DHCP Servidor parado',0
str_dhcp_atribuido:  db '  [DHCP] IP atribuido: ',0
str_dhcp_clientes:   db '  [DHCP] Clientes ativos: ',0
str_dhcp_pegou_ip:   db '  [OK] DHCP IP obtido: ',0
str_dhcp_aguarde:    db '  [*] Enviando DHCP DISCOVER...',0
str_dhcp_nak:        db '  [!] DHCP NAK recebido do servidor',0

section .text

; ==========================================
; 🔧 CONFIGURAÇÃO DE MAC, RESET E IP ESTÁTICO
; ==========================================
dhcp_definir_mac:
    mov     eax, [rdi]
    mov     [rel dhcp_mac_local], eax
    mov     ax, [rdi + 4]
    mov     [rel dhcp_mac_local + 4], ax
    ret

; Garante que dhcp_mac_local tenha o MAC real da NIC (mac_addr) se ainda estiver zerado
dhcp_sincronizar_mac_nic:
    mov     eax, [rel dhcp_mac_local]
    or      ax, [rel dhcp_mac_local + 4]
    jnz     .ok

    mov     eax, [rel mac_addr]
    mov     [rel dhcp_mac_local], eax
    mov     ax, [rel mac_addr + 4]
    mov     [rel dhcp_mac_local + 4], ax
.ok:
    ret

dhcp_cliente_resetar:
    mov     dword [rel dhcp_estado], DHCP_ST_IDLE
    mov     dword [rel dhcp_ip_atual], 0
    mov     dword [rel dhcp_ip_ofertado], 0
    mov     dword [rel dhcp_servidor_remoto], 0
    mov     dword [rel dhcp_mascara], 0
    mov     dword [rel dhcp_gateway], 0
    mov     dword [rel dhcp_dns], 0
    ret

; Chamado pelo botão [Aplicar IP Fixo] da UI (exec.c)
; Entrada: edi = IP (big-endian host, ex: 0x0A000219 = 10.0.2.25)
;          esi = Máscara (ex: 0xFFFFFF00)
;          edx = Gateway (ex: 0x0A000202)
dhcp_definir_ip_estatico:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    mov     [rel dhcp_ip_atual], edi
    mov     [rel dhcp_mascara], esi
    mov     [rel dhcp_gateway], edx
    mov     [rel dhcp_dns], edx
    mov     dword [rel dhcp_estado], DHCP_ST_BOUND

    ; Propaga para meu_ip, mascara_rede, gateway_ip e strings do rede.asm
    call    rede_definir_ip_estatico

    mov     rax, 1
    mov     rsp, rbp
    pop     rbp
    ret

; ==========================================
; 📦 ENCAPSULAR BOOTP (300B) EM ETHERNET + IPv4 + UDP E TRANSMITIR
; Entrada: esi = porta origem (68 cliente / 67 servidor)
;          edx = porta destino (67 servidor / 68 cliente)
; ==========================================
dhcp_enviar_frame:
    push    rbx
    push    r12
    push    r13

    mov     r12d, esi               ; porta origem
    mov     r13d, edx               ; porta destino
    call    dhcp_sincronizar_mac_nic

    lea     rdi, [rel dhcp_eth_frame]

    ; 1. Cabeçalho Ethernet (14 bytes) - Broadcast FF:FF:FF:FF:FF:FF
    mov     dword [rdi + 0], 0xFFFFFFFF
    mov     word  [rdi + 4], 0xFFFF
    mov     eax, [rel dhcp_mac_local]
    mov     [rdi + 6], eax
    mov     ax, [rel dhcp_mac_local + 4]
    mov     [rdi + 10], ax
    mov     word  [rdi + 12], 0x0008 ; EtherType IPv4 (0x0800 big-endian)

    ; 2. Cabeçalho IPv4 (20 bytes -> offset 14..33)
    lea     rbx, [rdi + 14]
    mov     byte  [rbx + 0], 0x45   ; Version 4, IHL 5
    mov     byte  [rbx + 1], 0x00   ; DSCP/ECN
    mov     word  [rbx + 2], 0x4801 ; Total Length = 328 (0x0148 em big-endian)
    mov     word  [rbx + 4], 0x0100 ; Identification
    mov     word  [rbx + 6], 0x0000 ; Flags / Fragment Offset
    mov     byte  [rbx + 8], 64     ; TTL = 64
    mov     byte  [rbx + 9], 17     ; Protocol = UDP (17)
    mov     word  [rbx + 10], 0     ; Checksum inicial = 0
    mov     dword [rbx + 12], 0x00000000 ; Src IP: 0.0.0.0
    mov     dword [rbx + 16], 0xFFFFFFFF ; Dst IP: 255.255.255.255

    ; Calcula checksum do cabeçalho IPv4 (10 words)
    xor     ecx, ecx
    xor     edx, edx
.ip_csum:
    movzx   eax, word [rbx + rdx]
    add     ecx, eax
    add     edx, 2
    cmp     edx, 20
    jl      .ip_csum
    mov     eax, ecx
    shr     eax, 16
    and     ecx, 0xFFFF
    add     ecx, eax
    mov     eax, ecx
    shr     eax, 16
    add     ecx, eax
    not     cx
    mov     [rbx + 10], cx

    ; 3. Cabeçalho UDP (8 bytes -> offset 34..41)
    lea     rbx, [rdi + 34]
    mov     eax, r12d
    xchg    al, ah
    mov     [rbx + 0], ax           ; Source Port (big-endian)
    mov     eax, r13d
    xchg    al, ah
    mov     [rbx + 2], ax           ; Dest Port (big-endian)
    mov     word  [rbx + 4], 0x3401 ; UDP Length = 308 (0x0134 em big-endian)
    mov     word  [rbx + 6], 0x0000 ; Checksum UDP opcional (0 em IPv4)

    ; 4. Copia payload BOOTP/DHCP (300 bytes -> offset 42..341)
    lea     rsi, [rel dhcp_tx_buf]
    lea     rdi, [rel dhcp_eth_frame + 42]
    mov     rcx, DHCP_PKT_TAM / 4
    rep     movsd

    ; 5. Envia frame Ethernet completo pela E1000
    lea     rdi, [rel dhcp_eth_frame]
    mov     rsi, DHCP_FRAME_TAM
    call    tx_pacote

    pop     r13
    pop     r12
    pop     rbx
    ret

; ==========================================
; 🔍 AUXILIAR: BUSCAR OPÇÃO DHCP NO PACOTE RX
; Entrada: rsi = início das opções (dhcp_rx_buf + 240)
;          dl  = código da opção desejada (ex: DHCP_OPT_MSGTYPE)
; Saída:   rax = ponteiro para o registro da opção (ou 0 se não achar)
; ==========================================
dhcp_buscar_opcao:
    lea     rcx, [rel dhcp_rx_buf + 585]
.loop:
    cmp     rsi, rcx
    jae     .nao_encontrado

    movzx   eax, byte [rsi]
    cmp     al, DHCP_OPT_END
    je      .nao_encontrado

    cmp     al, DHCP_OPT_PAD
    jne     .verifica_codigo
    inc     rsi
    jmp     .loop

.verifica_codigo:
    cmp     al, dl
    je      .achou

    movzx   eax, byte [rsi + 1]
    lea     rsi, [rsi + rax + 2]
    jmp     .loop

.achou:
    mov     rax, rsi
    ret

.nao_encontrado:
    xor     rax, rax
    ret

; ==========================================
; 🖥️ MÓDULO 1 — SERVIDOR DHCP
; ==========================================
dhcp_servidor_iniciar:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    cmp     dword [rel dhcp_servidor_ativo], 1
    je      .fim

    mov     dword [rel dhcp_proximo_ip], IP_INICIO
    mov     dword [rel dhcp_servidor_ativo], 1
    mov     dword [rel dhcp_qtd_clientes], 0

    lea     rsi, [rel str_dhcp_ativo]
    call    print_string
    call    print_newline

.fim:
    mov     rax, 1
    mov     rsp, rbp
    pop     rbp
    ret

dhcp_servidor_processar:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    cmp     dword [rel dhcp_servidor_ativo], 1
    jne     .fim

    lea     rdi, [rel dhcp_rx_buf]
    call    rx_processa
    test    rax, rax
    jz      .fim

    cmp     byte [rel dhcp_rx_buf], BOOTP_OP_REQUEST
    jne     .fim
    cmp     dword [rel dhcp_rx_buf + 236], DHCP_MAGIC_COOKIE
    jne     .fim

    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_MSGTYPE
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .fim

    movzx   eax, byte [rax + 2]
    cmp     al, DHCP_DISCOVER
    je      .tratar_discover
    cmp     al, DHCP_REQUEST
    je      .tratar_request
    jmp     .fim

.tratar_discover:
    lea     rdi, [rel dhcp_rx_buf + 28]
    call    buscar_ip_por_mac
    test    eax, eax
    jnz     .envia_offer

    call    encontrar_ip_livre
    mov     r9d, eax
    lea     rdi, [rel dhcp_rx_buf + 28]
    mov     esi, r9d
    call    registrar_cliente
    mov     eax, r9d

.envia_offer:
    mov     edi, eax
    mov     esi, DHCP_OFFER
    call    montar_resposta
    jmp     .fim

.tratar_request:
    lea     rdi, [rel dhcp_rx_buf + 28]
    call    buscar_ip_por_mac
    test    eax, eax
    jz      .fim

    mov     r9d, eax
    mov     edi, r9d
    mov     esi, DHCP_ACK
    call    montar_resposta

    lea     rsi, [rel str_dhcp_atribuido]
    call    print_string
    mov     eax, r9d
    bswap   eax
    lea     rdi, [rel ip_buf]
    call    ip_para_string
    lea     rsi, [rel ip_buf]
    call    print_string
    call    print_newline

.fim:
    mov     rsp, rbp
    pop     rbp
    ret

encontrar_ip_livre:
    mov     eax, [rel dhcp_proximo_ip]
.verificar:
    cmp     eax, IP_FIM
    jbe     .ok
    mov     eax, IP_INICIO
.ok:
    xor     rdx, rdx
    lea     rsi, [rel dhcp_clientes_ip]
.procurar:
    cmp     [rsi + rdx * 4], eax
    je      .ocupado
    inc     rdx
    cmp     rdx, 32
    jl      .procurar

    mov     edx, eax
    inc     edx
    mov     [rel dhcp_proximo_ip], edx
    ret

.ocupado:
    inc     eax
    jmp     .verificar

registrar_cliente:
    push    rbx
    mov     ebx, esi
    mov     eax, [rel dhcp_qtd_clientes]
    cmp     eax, 32
    jae     .fim

    mov     ecx, eax
    imul    rax, 6
    lea     rdx, [rel dhcp_clientes_mac]
    add     rdx, rax

    mov     rsi, rdi
    mov     rdi, rdx
    mov     r8, rcx
    mov     rcx, 6
    rep     movsb

    lea     rdx, [rel dhcp_clientes_ip]
    mov     [rdx + r8 * 4], ebx
    inc     dword [rel dhcp_qtd_clientes]
.fim:
    pop     rbx
    ret

buscar_ip_por_mac:
    push    rbx
    xor     ecx, ecx
    mov     ebx, [rel dhcp_qtd_clientes]
.loop:
    cmp     ecx, ebx
    jae     .nao

    mov     rax, rcx
    imul    rax, 6
    lea     rsi, [rel dhcp_clientes_mac]
    add     rsi, rax

    push    rcx
    push    rdi
    mov     rcx, 6
    repe    cmpsb
    pop     rdi
    pop     rcx
    je      .encontrado

    inc     ecx
    jmp     .loop

.encontrado:
    lea     rsi, [rel dhcp_clientes_ip]
    mov     eax, [rsi + rcx * 4]
    pop     rbx
    ret

.nao:
    xor     eax, eax
    pop     rbx
    ret

montar_resposta:
    push    rbx
    push    rbp
    mov     ebx, esi
    mov     ebp, edi

    lea     rdi, [rel dhcp_tx_buf]
    mov     rcx, 600 / 8
    xor     rax, rax
    rep     stosq

    lea     rdi, [rel dhcp_tx_buf]
    mov     byte [rdi + 0], BOOTP_OP_REPLY
    mov     byte [rdi + 1], BOOTP_HTYPE_ETH
    mov     byte [rdi + 2], BOOTP_HLEN_ETH

    mov     eax, [rel dhcp_rx_buf + 4]
    mov     [rdi + 4], eax
    mov     ax, [rel dhcp_rx_buf + 10]
    mov     [rdi + 10], ax

    mov     [rdi + 16], ebp
    mov     dword [rdi + 20], SERVIDOR_IP

    lea     rsi, [rel dhcp_rx_buf + 28]
    lea     rdi, [rel dhcp_tx_buf + 28]
    mov     rcx, 16
    rep     movsb

    mov     dword [rel dhcp_tx_buf + 236], DHCP_MAGIC_COOKIE

    lea     rdi, [rel dhcp_tx_buf + 240]

    mov     byte [rdi + 0], DHCP_OPT_MSGTYPE
    mov     byte [rdi + 1], 1
    mov     [rdi + 2], bl
    add     rdi, 3

    mov     byte [rdi + 0], DHCP_OPT_SERVERID
    mov     byte [rdi + 1], 4
    mov     dword [rdi + 2], SERVIDOR_IP
    add     rdi, 6

    mov     byte [rdi + 0], DHCP_OPT_SUBNET
    mov     byte [rdi + 1], 4
    mov     dword [rdi + 2], MASCARA
    add     rdi, 6

    mov     byte [rdi + 0], DHCP_OPT_GATEWAY
    mov     byte [rdi + 1], 4
    mov     dword [rdi + 2], GATEWAY_IP
    add     rdi, 6

    mov     byte [rdi + 0], DHCP_OPT_DNS
    mov     byte [rdi + 1], 4
    mov     dword [rdi + 2], DNS_IP
    add     rdi, 6

    mov     byte [rdi + 0], DHCP_OPT_LEASE
    mov     byte [rdi + 1], 4
    mov     dword [rdi + 2], TEMPO_CONCESSAO
    add     rdi, 6

    mov     byte [rdi], DHCP_OPT_END

    mov     esi, DHCP_SERVER_PORT
    mov     edx, DHCP_CLIENT_PORT
    call    dhcp_enviar_frame

    pop     rbp
    pop     rbx
    ret

dhcp_servidor_status:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    cmp     dword [rel dhcp_servidor_ativo], 1
    jne     .parado

    lea     rsi, [rel str_dhcp_clientes]
    call    print_string
    mov     edi, [rel dhcp_qtd_clientes]
    call    print_num
    call    print_newline
    mov     rax, 1
    jmp     .fim

.parado:
    lea     rsi, [rel str_dhcp_parado]
    call    print_string
    call    print_newline
    xor     rax, rax

.fim:
    mov     rsp, rbp
    pop     rbp
    ret

; ==========================================
; 📱 MÓDULO 2 — CLIENTE DHCP (RFC 2131)
; ==========================================
dhcp_cliente_iniciar:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    cmp     dword [rel dhcp_estado], DHCP_ST_DISCOVER
    je      .fim
    cmp     dword [rel dhcp_estado], DHCP_ST_REQUEST
    je      .fim

    ; Garante que a placa E1000 esteja inicializada antes de enviar Discover
    call    inicializar_nic_mmio
    call    dhcp_sincronizar_mac_nic

    mov     dword [rel dhcp_estado], DHCP_ST_DISCOVER
    mov     dword [rel dhcp_ip_ofertado], 0
    mov     dword [rel dhcp_servidor_remoto], 0

    lea     rsi, [rel str_dhcp_aguarde]
    call    print_string
    call    print_newline

    rdtsc
    xor     eax, edx
    or      eax, 0x46590000
    mov     [rel dhcp_xid], eax

    call    montar_discover
    mov     esi, DHCP_CLIENT_PORT
    mov     edx, DHCP_SERVER_PORT
    call    dhcp_enviar_frame

.fim:
    mov     rax, 1
    mov     rsp, rbp
    pop     rbp
    ret

dhcp_cliente_processar:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    mov     eax, [rel dhcp_estado]
    cmp     eax, DHCP_ST_DISCOVER
    je      .ler_pacote
    cmp     eax, DHCP_ST_REQUEST
    je      .ler_pacote
    jmp     .fim

.ler_pacote:
    lea     rdi, [rel dhcp_rx_buf]
    call    rx_processa
    test    rax, rax
    jz      .fim

    cmp     byte [rel dhcp_rx_buf], BOOTP_OP_REPLY
    jne     .fim
    mov     eax, [rel dhcp_rx_buf + 4]
    cmp     eax, [rel dhcp_xid]
    jne     .fim
    cmp     dword [rel dhcp_rx_buf + 236], DHCP_MAGIC_COOKIE
    jne     .fim

    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_MSGTYPE
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .fim

    movzx   eax, byte [rax + 2]
    cmp     al, DHCP_OFFER
    je      .tratar_oferta
    cmp     al, DHCP_ACK
    je      .tratar_confirmacao
    cmp     al, DHCP_NAK
    je      .tratar_nak
    jmp     .fim

.tratar_oferta:
    cmp     dword [rel dhcp_estado], DHCP_ST_DISCOVER
    jne     .fim

    mov     eax, [rel dhcp_rx_buf + 16]
    test    eax, eax
    jz      .fim
    mov     [rel dhcp_ip_ofertado], eax

    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_SERVERID
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .usa_siaddr
    mov     eax, [rax + 2]
    jmp     .salva_srv
.usa_siaddr:
    mov     eax, [rel dhcp_rx_buf + 20]
.salva_srv:
    mov     [rel dhcp_servidor_remoto], eax

    mov     dword [rel dhcp_estado], DHCP_ST_REQUEST
    call    montar_request
    mov     esi, DHCP_CLIENT_PORT
    mov     edx, DHCP_SERVER_PORT
    call    dhcp_enviar_frame
    jmp     .fim

.tratar_confirmacao:
    mov     eax, [rel dhcp_rx_buf + 16]
    test    eax, eax
    jnz     .ip_ok
    mov     eax, [rel dhcp_ip_ofertado]
.ip_ok:
    mov     [rel dhcp_ip_atual], eax

    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_SUBNET
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .busca_gw
    mov     eax, [rax + 2]
    mov     [rel dhcp_mascara], eax

.busca_gw:
    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_GATEWAY
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .busca_dns
    mov     eax, [rax + 2]
    mov     [rel dhcp_gateway], eax

.busca_dns:
    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_DNS
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .concluido
    mov     eax, [rax + 2]
    mov     [rel dhcp_dns], eax

.concluido:
    mov     dword [rel dhcp_estado], DHCP_ST_BOUND

    ; Converte IP, Máscara e Gateway (network byte order -> big-endian host)
    ; e atualiza meu_ip, str_ip, str_mask e str_gw diretamente no rede.asm
    mov     edi, [rel dhcp_ip_atual]
    bswap   edi
    mov     esi, [rel dhcp_mascara]
    bswap   esi
    mov     edx, [rel dhcp_gateway]
    bswap   edx
    call    rede_definir_ip_estatico

    lea     rsi, [rel str_dhcp_pegou_ip]
    call    print_string
    mov     edi, [rel dhcp_ip_atual]
    bswap   edi
    lea     rsi, [rel ip_buf]
    call    ip_para_string
    lea     rsi, [rel ip_buf]
    call    print_string
    call    print_newline
    jmp     .fim

.tratar_nak:
    call    dhcp_cliente_resetar
    lea     rsi, [rel str_dhcp_nak]
    call    print_string
    call    print_newline

.fim:
    mov     rsp, rbp
    pop     rbp
    ret

; ==========================================
; 📦 CONSTRUTORES DE PACOTES DO CLIENTE
; ==========================================
dhcp_preencher_base_cliente:
    call    dhcp_sincronizar_mac_nic

    lea     rdi, [rel dhcp_tx_buf]
    mov     rcx, 600 / 8
    xor     rax, rax
    rep     stosq

    lea     rdi, [rel dhcp_tx_buf]
    mov     byte [rdi + 0], BOOTP_OP_REQUEST
    mov     byte [rdi + 1], BOOTP_HTYPE_ETH
    mov     byte [rdi + 2], BOOTP_HLEN_ETH

    mov     eax, [rel dhcp_xid]
    mov     [rdi + 4], eax
    mov     word [rdi + 10], DHCP_FLAG_BROADCAST

    mov     eax, [rel dhcp_mac_local]
    mov     [rdi + 28], eax
    mov     ax, [rel dhcp_mac_local + 4]
    mov     [rdi + 32], ax

    mov     dword [rdi + 236], DHCP_MAGIC_COOKIE
    ret

montar_discover:
    call    dhcp_preencher_base_cliente

    lea     rdi, [rel dhcp_tx_buf + 240]
    mov     byte [rdi + 0], DHCP_OPT_MSGTYPE
    mov     byte [rdi + 1], 1
    mov     byte [rdi + 2], DHCP_DISCOVER
    add     rdi, 3

    mov     byte [rdi + 0], DHCP_OPT_PARAM_LIST
    mov     byte [rdi + 1], 3
    mov     byte [rdi + 2], DHCP_OPT_SUBNET
    mov     byte [rdi + 3], DHCP_OPT_GATEWAY
    mov     byte [rdi + 4], DHCP_OPT_DNS
    add     rdi, 5

    mov     byte [rdi], DHCP_OPT_END
    ret

montar_request:
    call    dhcp_preencher_base_cliente

    lea     rdi, [rel dhcp_tx_buf + 240]
    mov     byte [rdi + 0], DHCP_OPT_MSGTYPE
    mov     byte [rdi + 1], 1
    mov     byte [rdi + 2], DHCP_REQUEST
    add     rdi, 3

    mov     byte [rdi + 0], DHCP_OPT_REQ_IP
    mov     byte [rdi + 1], 4
    mov     eax, [rel dhcp_ip_ofertado]
    mov     [rdi + 2], eax
    add     rdi, 6

    mov     eax, [rel dhcp_servidor_remoto]
    test    eax, eax
    jz      .param_list
    mov     byte [rdi + 0], DHCP_OPT_SERVERID
    mov     byte [rdi + 1], 4
    mov     [rdi + 2], eax
    add     rdi, 6

.param_list:
    mov     byte [rdi + 0], DHCP_OPT_PARAM_LIST
    mov     byte [rdi + 1], 3
    mov     byte [rdi + 2], DHCP_OPT_SUBNET
    mov     byte [rdi + 3], DHCP_OPT_GATEWAY
    mov     byte [rdi + 4], DHCP_OPT_DNS
    add     rdi, 5

    mov     byte [rdi], DHCP_OPT_END
    ret

; ==========================================
; 📊 STATUS DO CLIENTE DHCP
; Retorno: 0=Idle, 1=Discover, 2=Request, 3=Bound (IP obtido)
; ==========================================
dhcp_ler_status:
    mov     eax, [rel dhcp_estado]
    ret
