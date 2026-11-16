; ==========================================
; DHCP UNIFICADO (SERVIDOR & CLIENTE)
; FydelisTech OS v2.2 — Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
default rel
%include "fydelterm.inc"

; ========== PORTAS E TIPOS ==========
DHCP_SERVER_PORT   equ 67
DHCP_CLIENT_PORT   equ 68

DHCP_DISCOVER      equ 1
DHCP_OFFER         equ 2
DHCP_REQUEST       equ 3
DHCP_ACK           equ 5

DHCP_OPT_MSGTYPE   equ 53
DHCP_OPT_SERVERID  equ 54
DHCP_OPT_SUBNET    equ 1
DHCP_OPT_GATEWAY   equ 3
DHCP_OPT_DNS       equ 6
DHCP_OPT_LEASE     equ 51
DHCP_OPT_END       equ 255

; ========== CONFIGURAÇÃO DE REDE ==========
SERVIDOR_IP        equ 0x0102000A   ; 10.0.2.1  (LITTLE-ENDIAN!)
IP_INICIO          equ 0x1002000A   ; 10.0.2.16
IP_FIM             equ 0xFE02000A   ; 10.0.2.254
MASCARA            equ 0x00FFFFFF   ; 255.255.255.0
GATEWAY_IP         equ SERVIDOR_IP
DNS_IP             equ SERVIDOR_IP
TEMPO_CONCESSAO    equ 86400        ; 24h

; ========== EXTERNAIS ==========
extern tx_pacote, rx_processa
extern print_string, print_newline, print_num, memset, memcpy
extern ip_para_string

; ========== EXPORTAÇÃO ==========
global dhcp_servidor_iniciar
global dhcp_servidor_processar
global dhcp_servidor_status
global dhcp_servidor_ativo
global dhcp_cliente_iniciar
global dhcp_cliente_processar
global dhcp_ip_atual

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
dhcp_mascara:        resd 1
dhcp_gateway:        resd 1
dhcp_dns:            resd 1
dhcp_xid:            resd 4

dhcp_rx_buf:         resb 600
dhcp_tx_buf:         resb 600
ip_buf:              resb 16

section .data
str_dhcp_ativo:      db '✅ DHCP Servidor ativo — 10.0.2.1',0
str_dhcp_parado:     db 'DHCP Servidor parado',0
str_dhcp_atribuido:  db 'DHCP → IP atribuído: ',0
str_dhcp_clientes:   db 'Clientes ativos: ',0
str_dhcp_pegou_ip:   db '✅ IP obtido: ',0
str_dhcp_aguarde:    db 'Aguardando servidor DHCP...',0

section .text

; ==========================================
; 🖥️ MÓDULO 1 — SERVIDOR DHCP
; ==========================================
dhcp_servidor_iniciar:
    mov eax, [rel dhcp_servidor_ativo]
    cmp eax, 1
    je .fim
    mov dword [rel dhcp_proximo_ip], IP_INICIO
    mov dword [rel dhcp_servidor_ativo], 1
    mov dword [rel dhcp_qtd_clientes], 0
    lea rsi, [rel str_dhcp_ativo]
    call print_string
    call print_newline
.fim:
    mov rax, 1
    ret

dhcp_servidor_processar:
    mov eax, [rel dhcp_servidor_ativo]
    cmp eax, 1
    jne .fim

    lea rdi, [rel dhcp_rx_buf]
    call rx_processa
    test rax, rax
    jz .fim

    cmp byte [rel dhcp_rx_buf], 1
    jne .fim

    lea rsi, [rel dhcp_rx_buf + 240]
.procurar:
    cmp byte [rsi], DHCP_OPT_END
    je .fim
    cmp byte [rsi], DHCP_OPT_MSGTYPE
    je .encontrado
    inc rsi
    movzx rcx, byte [rsi]      ; correção: len está em [rsi] após o inc
    add rsi, rcx
    inc rsi                     ; pula len + dado
    jmp .procurar

.encontrado:
    movzx eax, byte [rsi + 2]
    cmp al, DHCP_DISCOVER
    je .tratar_discover
    cmp al, DHCP_REQUEST
    je .tratar_request
    jmp .fim

.tratar_discover:
    call encontrar_ip_livre
    mov r9d, eax
    lea rdi, [rel dhcp_rx_buf + 28]
    mov rsi, r9                 ; correção: era "mov rsi, r9d"
    call registrar_cliente
    mov rdi, r9                 ; correção: era "mov rdi, r9d"
    mov rsi, DHCP_OFFER
    call montar_resposta
    jmp .fim

.tratar_request:
    lea rdi, [rel dhcp_rx_buf + 28]
    call buscar_ip_por_mac
    test rax, rax
    jz .fim
    mov r9d, eax
    mov rdi, r9                 ; correção: era "mov rdi, r9d"
    mov rsi, DHCP_ACK
    call montar_resposta

    lea rsi, [rel str_dhcp_atribuido]
    call print_string
    mov eax, r9d
    lea rdi, [rel ip_buf]
    call ip_para_string
    lea rsi, [rel ip_buf]
    call print_string
    call print_newline
.fim:
    ret

encontrar_ip_livre:
    mov eax, [rel dhcp_proximo_ip]
.verificar:
    cmp eax, IP_FIM
    jbe .ok
    mov eax, IP_INICIO
.ok:
    push rax
    xor rdx, rdx
.procurar:
    lea rsi, [rel dhcp_clientes_ip]
    mov r8d, [rsi + rdx*4]
    cmp r8d, eax
    je .ocupado
    inc rdx
    cmp rdx, 32
    jl .procurar
    pop rax
    mov [rel dhcp_proximo_ip], eax
    add dword [rel dhcp_proximo_ip], 1
    ret
.ocupado:
    pop rax
    inc eax
    jmp .verificar

registrar_cliente:
    push rcx
    push rdx
    push rbx

    mov rbx, rsi
    lea rcx, [rel dhcp_qtd_clientes]
    mov eax, [rcx]
    cmp eax, 32
    jae .fim

    imul rax, 6
    lea rdx, [rel dhcp_clientes_mac]
    add rdx, rax

    push rsi
    mov rsi, rdi
    mov rdi, rdx
    mov rcx, 6
    rep movsb
    pop rsi

    lea rdx, [rel dhcp_clientes_ip]
    lea rcx, [rel dhcp_qtd_clientes]
    mov eax, [rcx]
    mov [rdx + rax*4], ebx

    inc dword [rel dhcp_qtd_clientes]
.fim:
    pop rbx
    pop rdx
    pop rcx
    ret

buscar_ip_por_mac:
    push rcx
    push rbx
    push rdx
    xor rcx, rcx
.loop:
    lea rdx, [rel dhcp_qtd_clientes]
    mov ebx, [rdx]
    cmp ecx, ebx
    jae .nao

    mov rax, rcx
    imul rax, 6
    lea rsi, [rel dhcp_clientes_mac]
    add rsi, rax

    push rcx
    push rdi
    mov rcx, 6
    repe cmpsb
    pop rdi
    pop rcx
    jz .encontrado
    inc rcx
    jmp .loop
.encontrado:
    lea rsi, [rel dhcp_clientes_ip]
    mov rax, rcx
    mov eax, [rsi + rax*4]
    jmp .fim
.nao:
    xor rax, rax
.fim:
    pop rdx
    pop rbx
    pop rcx
    ret

montar_resposta:
    push rbx
    push rbp
    mov ebx, esi          ; rsi = tipo de mensagem (OFFER/ACK)
    mov ebp, edi          ; rdi = IP atribuído

    ; 1. Zerar buffer tx
    lea rdi, [rel dhcp_tx_buf]
    mov rcx, 600
    xor al, al
    rep stosb

    ; 2. Bootp op: Reply (2)
    lea rdi, [rel dhcp_tx_buf]
    mov byte [rdi], 2

    ; 3. Copiar XID
    lea rsi, [rel dhcp_rx_buf + 4]
    mov eax, [rsi]
    lea rdi, [rel dhcp_tx_buf + 4]
    mov [rdi], eax

    ; 4. Atribuir IP do cliente (yiaddr)
    lea rdi, [rel dhcp_tx_buf + 16]
    mov eax, ebp
    mov [rdi], eax

    ; 5. IP do servidor (siaddr)
    lea rdi, [rel dhcp_tx_buf + 20]
    mov dword [rdi], SERVIDOR_IP

    ; 6. Copiar chaddr (MAC)
    lea rsi, [rel dhcp_rx_buf + 28]
    lea rdi, [rel dhcp_tx_buf + 32]
    mov rcx, 16
    rep movsb

    ; 7. Magic Cookie
    lea rdi, [rel dhcp_tx_buf + 236]
    mov dword [rdi], 0x63825363

    ; 8. Opções
    lea rdi, [rel dhcp_tx_buf + 240]

    mov byte [rdi], DHCP_OPT_MSGTYPE
    mov byte [rdi + 1], 1
    mov [rdi + 2], bl
    add rdi, 3

    mov byte [rdi], DHCP_OPT_SERVERID
    mov byte [rdi + 1], 4
    mov dword [rdi + 2], SERVIDOR_IP
    add rdi, 6

    mov byte [rdi], DHCP_OPT_SUBNET
    mov byte [rdi + 1], 4
    mov dword [rdi + 2], MASCARA
    add rdi, 6

    mov byte [rdi], DHCP_OPT_GATEWAY
    mov byte [rdi + 1], 4
    mov dword [rdi + 2], GATEWAY_IP
    add rdi, 6

    mov byte [rdi], DHCP_OPT_DNS
    mov byte [rdi + 1], 4
    mov dword [rdi + 2], DNS_IP
    add rdi, 6

    mov byte [rdi], DHCP_OPT_LEASE
    mov byte [rdi + 1], 4
    mov dword [rdi + 2], TEMPO_CONCESSAO
    add rdi, 6

    mov byte [rdi], DHCP_OPT_END

    ; 9. Enviar
    lea rdi, [rel dhcp_tx_buf]
    mov rsi, 300
    call tx_pacote

    pop rbp
    pop rbx
    ret

dhcp_servidor_status:
    mov eax, [rel dhcp_servidor_ativo]
    cmp eax, 1
    jne .parado
    lea rsi, [rel str_dhcp_clientes]
    call print_string
    mov rdi, [rel dhcp_qtd_clientes]
    call print_num
    call print_newline
    mov rax, 1
    ret
.parado:
    lea rsi, [rel str_dhcp_parado]
    call print_string
    call print_newline
    xor rax, rax
    ret

; ==========================================
; 📱 MÓDULO 2 — CLIENTE DHCP
; ==========================================
dhcp_cliente_iniciar:
    mov eax, [rel dhcp_estado]
    cmp eax, 0
    jne .fim
    mov dword [rel dhcp_estado], 1
    lea rsi, [rel str_dhcp_aguarde]
    call print_string
    call print_newline
    rdtsc
    mov [rel dhcp_xid], eax
    call montar_discover
    lea rdi, [rel dhcp_tx_buf]
    mov rsi, 300
    call tx_pacote
.fim:
    ret

dhcp_cliente_processar:
    mov eax, [rel dhcp_estado]
    cmp eax, 1
    jne .fim

    lea rdi, [rel dhcp_rx_buf]
    call rx_processa
    test rax, rax
    jz .fim

    lea rsi, [rel dhcp_rx_buf + 240]
.procurar:
    cmp byte [rsi], DHCP_OPT_END
    je .fim
    cmp byte [rsi], DHCP_OPT_MSGTYPE
    je .encontrado
    inc rsi
    movzx rcx, byte [rsi]      ; correção: len está em [rsi] após o inc
    add rsi, rcx
    inc rsi                     ; pula len + dado
    jmp .procurar

.encontrado:
    movzx eax, byte [rsi + 2]
    cmp al, DHCP_OFFER
    je .tratar_oferta
    cmp al, DHCP_ACK
    je .tratar_confirmacao
    jmp .fim

.tratar_oferta:
    mov eax, [rel dhcp_rx_buf + 16]
    mov [rel dhcp_ip_atual], eax
    mov eax, [rel dhcp_rx_buf + 20]
    mov [rel dhcp_gateway], eax
    call montar_request
    lea rdi, [rel dhcp_tx_buf]
    mov rsi, 300
    call tx_pacote
    jmp .fim

.tratar_confirmacao:
    mov dword [rel dhcp_estado], 3
    lea rsi, [rel str_dhcp_pegou_ip]
    call print_string
    mov eax, [rel dhcp_ip_atual]
    lea rdi, [rel ip_buf]
    call ip_para_string
    lea rsi, [rel ip_buf]
    call print_string
    call print_newline
.fim:
    ret

montar_discover:
    push rcx
    lea rdi, [rel dhcp_tx_buf]
    mov rcx, 600
    xor al, al
    rep stosb

    mov byte [rel dhcp_tx_buf], 1
    mov eax, [rel dhcp_xid]
    mov [rel dhcp_tx_buf + 4], eax
    mov dword [rel dhcp_tx_buf + 236], 0x63825363

    mov byte [rel dhcp_tx_buf + 240], DHCP_OPT_MSGTYPE
    mov byte [rel dhcp_tx_buf + 241], 1
    mov byte [rel dhcp_tx_buf + 242], DHCP_DISCOVER
    mov byte [rel dhcp_tx_buf + 243], DHCP_OPT_END
    pop rcx
    ret

montar_request:
    push rcx
    lea rdi, [rel dhcp_tx_buf]
    mov rcx, 600
    xor al, al
    rep stosb

    mov byte [rel dhcp_tx_buf], 1
    mov eax, [rel dhcp_xid]
    mov [rel dhcp_tx_buf + 4], eax
    mov dword [rel dhcp_tx_buf + 236], 0x63825363

    lea rdi, [rel dhcp_tx_buf + 240]
    mov byte [rdi], DHCP_OPT_MSGTYPE
    mov byte [rdi + 1], 1
    mov byte [rdi + 2], DHCP_REQUEST
    add rdi, 3
    mov byte [rdi], DHCP_OPT_END
    pop rcx
    ret
