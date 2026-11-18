; ==========================================
; 🌐 DHCP UNIFICADO (SERVIDOR & CLIENTE RFC 2131)
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
SERVIDOR_IP         equ 0x0102000A   ; 10.0.2.1  (little-endian)
IP_INICIO           equ 0x1002000A   ; 10.0.2.16
IP_FIM              equ 0xFE02000A   ; 10.0.2.254
MASCARA             equ 0x00FFFFFF   ; 255.255.255.0
GATEWAY_IP          equ SERVIDOR_IP
DNS_IP              equ SERVIDOR_IP
TEMPO_CONCESSAO     equ 0x80510100   ; 86400s (24h) em big-endian
DHCP_PKT_TAM        equ 300

; ========== EXTERNAIS ==========
extern tx_pacote, rx_processa
extern print_string, print_newline, print_num
extern ip_para_string

; ========== EXPORTAÇÃO ==========
global dhcp_servidor_iniciar
global dhcp_servidor_processar
global dhcp_servidor_status
global dhcp_servidor_ativo
global dhcp_cliente_iniciar
global dhcp_cliente_processar
global dhcp_cliente_resetar
global dhcp_definir_mac
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
; 🔧 CONFIGURAÇÃO DE MAC E RESET DO CLIENTE
; Entrada: rdi = ponteiro para 6 bytes do MAC
; ==========================================
dhcp_definir_mac:
    mov     eax, [rdi]
    mov     [rel dhcp_mac_local], eax
    mov     ax, [rdi + 4]
    mov     [rel dhcp_mac_local + 4], ax
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

; ==========================================
; 🔍 AUXILIAR: BUSCAR OPÇÃO DHCP NO PACOTE RX
; Entrada: rsi = início das opções (dhcp_rx_buf + 240)
;          dl  = código da opção desejada (ex: DHCP_OPT_MSGTYPE)
; Saída:   rax = ponteiro para o registro da opção (ou 0 se não achar)
; ==========================================
dhcp_buscar_opcao:
    lea     rcx, [rel dhcp_rx_buf + 596]
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

    movzx   eax, byte [rsi + 1]     ; len da opção
    lea     rsi, [rsi + rax + 2]    ; avança code(1) + len(1) + data(len)
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

    ; Valida BOOTP Request + Magic Cookie
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
    mov     edi, r9d
    lea     rsi, [rel ip_buf]
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
    mov     ebx, esi                ; Tipo (OFFER / ACK)
    mov     ebp, edi                ; IP atribuído

    ; 1. Zera buffer TX
    lea     rdi, [rel dhcp_tx_buf]
    mov     rcx, 600 / 8
    xor     rax, rax
    rep     stosq

    ; 2. Cabeçalho BOOTP Reply
    lea     rdi, [rel dhcp_tx_buf]
    mov     byte [rdi + 0], BOOTP_OP_REPLY
    mov     byte [rdi + 1], BOOTP_HTYPE_ETH
    mov     byte [rdi + 2], BOOTP_HLEN_ETH

    ; 3. XID e Flags do cliente
    mov     eax, [rel dhcp_rx_buf + 4]
    mov     [rdi + 4], eax
    mov     ax, [rel dhcp_rx_buf + 10]
    mov     [rdi + 10], ax

    ; 4. yiaddr e siaddr
    mov     [rdi + 16], ebp
    mov     dword [rdi + 20], SERVIDOR_IP

    ; 5. chaddr (Offset 28, 16 bytes)
    lea     rsi, [rel dhcp_rx_buf + 28]
    lea     rdi, [rel dhcp_tx_buf + 28]
    mov     rcx, 16
    rep     movsb

    ; 6. Magic Cookie
    mov     dword [rel dhcp_tx_buf + 236], DHCP_MAGIC_COOKIE

    ; 7. Opções DHCP
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

    lea     rdi, [rel dhcp_tx_buf]
    mov     rsi, DHCP_PKT_TAM
    call    tx_pacote

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

    ; Permite reiniciar se estiver IDLE ou já BOUND
    cmp     dword [rel dhcp_estado], DHCP_ST_DISCOVER
    je      .fim
    cmp     dword [rel dhcp_estado], DHCP_ST_REQUEST
    je      .fim

    mov     dword [rel dhcp_estado], DHCP_ST_DISCOVER
    mov     dword [rel dhcp_ip_ofertado], 0
    mov     dword [rel dhcp_servidor_remoto], 0

    lea     rsi, [rel str_dhcp_aguarde]
    call    print_string
    call    print_newline

    rdtsc
    xor     eax, edx
    or      eax, 0x46590000         ; Garante XID não-nulo
    mov     [rel dhcp_xid], eax

    call    montar_discover
    lea     rdi, [rel dhcp_tx_buf]
    mov     rsi, DHCP_PKT_TAM
    call    tx_pacote

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

    ; Valida BOOTP Reply, XID da sessão e Magic Cookie
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

    ; Captura yiaddr ofertado
    mov     eax, [rel dhcp_rx_buf + 16]
    test    eax, eax
    jz      .fim
    mov     [rel dhcp_ip_ofertado], eax

    ; Captura Server Identifier (Opção 54) ou fallback para siaddr
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
    lea     rdi, [rel dhcp_tx_buf]
    mov     rsi, DHCP_PKT_TAM
    call    tx_pacote
    jmp     .fim

.tratar_confirmacao:
    ; Salva IP definitivo (yiaddr)
    mov     eax, [rel dhcp_rx_buf + 16]
    test    eax, eax
    jnz     .ip_ok
    mov     eax, [rel dhcp_ip_ofertado]
.ip_ok:
    mov     [rel dhcp_ip_atual], eax

    ; Extrai Máscara (Opção 1)
    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_SUBNET
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .busca_gw
    mov     eax, [rax + 2]
    mov     [rel dhcp_mascara], eax

.busca_gw:
    ; Extrai Gateway (Opção 3)
    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_GATEWAY
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .busca_dns
    mov     eax, [rax + 2]
    mov     [rel dhcp_gateway], eax

.busca_dns:
    ; Extrai DNS (Opção 6)
    lea     rsi, [rel dhcp_rx_buf + 240]
    mov     dl, DHCP_OPT_DNS
    call    dhcp_buscar_opcao
    test    rax, rax
    jz      .concluido
    mov     eax, [rax + 2]
    mov     [rel dhcp_dns], eax

.concluido:
    mov     dword [rel dhcp_estado], DHCP_ST_BOUND

    lea     rsi, [rel str_dhcp_pegou_ip]
    call    print_string
    mov     edi, [rel dhcp_ip_atual]
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

    ; Grava MAC local em chaddr (offset 28)
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

    ; Lista de parâmetros solicitados (Subnet, Router, DNS)
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

    ; Opção 50: Requested IP Address
    mov     byte [rdi + 0], DHCP_OPT_REQ_IP
    mov     byte [rdi + 1], 4
    mov     eax, [rel dhcp_ip_ofertado]
    mov     [rdi + 2], eax
    add     rdi, 6

    ; Opção 54: DHCP Server Identifier
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
