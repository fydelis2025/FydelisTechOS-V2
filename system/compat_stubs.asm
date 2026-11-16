; ==========================================
; COMPAT_STUBS.ASM — Símbolos ausentes no link
; FydelisTechOS v2.2
; ==========================================
BITS 64
default rel
[warning suppress reloc-rel-dword]
%include "fydelterm.inc"

extern print_string, print_num
extern dhcp_cliente_iniciar, dhcp_cliente_processar
extern dhcp_ip_atual, dhcp_estado
extern arquivo_abrir, arquivo_ler_linha, arquivo_escrever_linha
extern arquivo_existe, arquivo_criar

global strcmpi
global strcmp, strcpy, strlen
global int_para_str
global ip_para_string
global usb_listar_dispositivos
global dhcp_exec
global rx_bytes_total, tx_bytes_total
global arquivo_fechar
global obter_unidade_sistema
global tx_pacote, rx_processa
global fila_criar, fila_adicionar, fila_processar, fila_limpar
global sys_usb_listar, sys_usb_enviar_dados, sys_usb_encontrar_dispositivo
global sys_rede_enviar
global wifi_tx_quadro, wifi_rx_quadro
global fs_criar_arquivo, fs_ler_arquivo
global arquivo_ler_todo
global print_formatado
global dhcp_estado

section .bss
mapa_unidades:    resb 26 * 8
rx_bytes_total:   resq 1
tx_bytes_total:   resq 1

; Fila de impressão simples: 16 entradas × 128 bytes
fila_buf:         resb 16 * 128
fila_qtd:         resd 1

section .text

; ---------- strcmpi(rdi, rsi) → rax=0 se iguais ----------
strcmpi:
    push r8
.loop:
    movzx eax, byte [rdi]
    movzx r8d, byte [rsi]
    cmp al, 'A'
    jb .ok1
    cmp al, 'Z'
    ja .ok1
    add al, 32
.ok1:
    cmp r8b, 'A'
    jb .ok2
    cmp r8b, 'Z'
    ja .ok2
    add r8b, 32
.ok2:
    cmp al, r8b
    jne .dif
    test al, al
    jz .igual
    inc rdi
    inc rsi
    jmp .loop
.dif:
    movzx eax, byte [rdi]
    movzx r8d, byte [rsi]
    sub eax, r8d
    pop r8
    ret
.igual:
    xor eax, eax
    pop r8
    ret

; ---------- strcmp(rdi, rsi) → rax=0 se iguais ----------
strcmp:
    push r8
.loop:
    movzx eax, byte [rdi]
    movzx r8d, byte [rsi]
    cmp al, r8b
    jne .dif
    test al, al
    jz .igual
    inc rdi
    inc rsi
    jmp .loop
.dif:
    sub eax, r8d
    pop r8
    ret
.igual:
    xor eax, eax
    pop r8
    ret

; ---------- strcpy(rdi=dst, rsi=src) ----------
strcpy:
    push rdi
    push rsi
.loop:
    lodsb
    stosb
    test al, al
    jnz .loop
    pop rsi
    pop rdi
    ret

; ---------- strlen(rdi) → rax ----------
strlen:
    xor eax, eax
.loop:
    cmp byte [rdi + rax], 0
    je .fim
    inc rax
    jmp .loop
.fim:
    ret

; ---------- int_para_str(rdi=buffer, rax=valor) decimal ----------
int_para_str:
    push rbx
    push rcx
    push rdx
    push rsi
    push rbp
    mov rsi, rdi
    mov rbp, rdi
    mov rbx, 10
    add rsi, 31
    mov byte [rsi], 0
.converter:
    xor edx, edx
    div rbx
    add dl, '0'
    dec rsi
    mov [rsi], dl
    test rax, rax
    jnz .converter
    mov rdi, rbp
.copiar:
    lodsb
    stosb
    test al, al
    jnz .copiar
    pop rbp
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------- ip_para_string(rdi=buffer, eax=IP little-endian) ----------
ip_para_string:
    push rbx
    push rcx
    push rdx
    push rsi
    push r8
    mov rsi, rdi
    mov r8d, eax
    mov ecx, 4
.byte_loop:
    mov eax, r8d
    and eax, 0xFF
    xor edx, edx
    mov ebx, 10
    div ebx            ; rax=dezena-centena? não: eax/10
    ; guarda resto e quociente
    push rdx           ; resto (dígito unidades)
    ; escreve quociente se > 0
    test eax, eax
    jz .so_unidade
    add al, '0'
    mov [rsi], al
    inc rsi
    pop rdx
    jmp .grava_unidade
.so_unidade:
    pop rdx
.grava_unidade:
    mov eax, edx
    add al, '0'
    mov [rsi], al
    inc rsi
    dec ecx
    jz .fim
    mov byte [rsi], '.'
    inc rsi
    shr r8d, 8
    jmp .byte_loop
.fim:
    mov byte [rsi], 0
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------- usb_listar_dispositivos (stub seguro) ----------
usb_listar_dispositivos:
    xor eax, eax
    ret

; ---------- dhcp_exec: roda o cliente DHCP e espera ----------
dhcp_exec:
    push r12
    call dhcp_cliente_iniciar
    xor r12, r12
.aguardar:
    mov eax, [rel dhcp_estado]
    cmp eax, 3
    je .ok
    call dhcp_cliente_processar
    inc r12
    cmp r12, 1000000
    jb .aguardar
    xor eax, eax
    pop r12
    ret
.ok:
    mov eax, [rel dhcp_ip_atual]
    test eax, eax
    jz .falhou
    mov eax, 1
    pop r12
    ret
.falhou:
    xor eax, eax
    pop r12
    ret

; ---------- Rede: stubs seguros (ligar ao driver real depois) ----------
tx_pacote:              ; rdi=buffer, rsi=tamanho → rax=1 enviado, 0 falha
    xor eax, eax
    ret

rx_processa:            ; rdi=buffer → rax=0 (nenhum pacote)
    xor eax, eax
    ret

sys_rede_enviar:        ; stub
    xor eax, eax
    ret

wifi_tx_quadro:
    xor eax, eax
    ret

wifi_rx_quadro:
    xor eax, eax
    ret

; ---------- USB: stubs seguros ----------
sys_usb_listar:
    xor eax, eax
    ret

sys_usb_enviar_dados:
    xor eax, eax
    ret

sys_usb_encontrar_dispositivo:
    xor eax, eax
    ret

; ---------- Fila de impressão ----------
fila_criar:
    mov dword [rel fila_qtd], 0
    mov eax, 1
    ret

fila_adicionar:         ; rdi=ponteiro para texto
    mov eax, [rel fila_qtd]
    cmp eax, 16
    jae .cheia
    imul rax, rax, 128
    lea rcx, [rel fila_buf]
    add rcx, rax
    mov rdx, rcx
    push rsi
    mov rsi, rdi
    mov rdi, rdx
    call strcpy
    pop rsi
    inc dword [rel fila_qtd]
    mov eax, 1
    ret
.cheia:
    xor eax, eax
    ret

fila_processar:
    mov dword [rel fila_qtd], 0
    mov eax, 1
    ret

fila_limpar:
    mov dword [rel fila_qtd], 0
    mov eax, 1
    ret

; ---------- Sistema de arquivos: stubs seguros ----------
arquivo_existe:
    xor eax, eax
    ret

arquivo_criar:
    xor eax, eax
    retffila_adicionar

arquivo_abrir:
    xor eax, eax
    ret

arquivo_ler_linha:
    xor eax, eax
    ret

arquivo_escrever_linha:
    xor eax, eax
    ret

arquivo_fechar:
    xor eax, eax
    ret

arquivo_ler_todo:
    xor eax, eax
    ret

fs_criar_arquivo:
    xor eax, eax
    ret

fs_ler_arquivo:
    xor eax, eax
    ret

obter_unidade_sistema:
    mov al, 'C'
    ret
