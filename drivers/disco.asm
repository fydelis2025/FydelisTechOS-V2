; ==========================================
; 💽 DISCO.ASM — Driver de Acesso ao Disco Físico
; ATA/IDE · Leitura/Escrita de Setores · Identificação
; FydelisTechOS v2.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
default rel
%include "fydelterm.inc"

; ========== PORTAS ATA ==========
ATA_DATA               equ 0x1F0
ATA_SECTORS            equ 0x1F2
ATA_LBA_LO             equ 0x1F3
ATA_LBA_MID            equ 0x1F4
ATA_LBA_HI             equ 0x1F5
ATA_CMD                equ 0x1F7
ATA_CMD_READ           equ 0x20
ATA_CMD_WRITE          equ 0x30
ATA_CMD_IDENTIFY       equ 0xEC
ATA_CMD_FLUSH          equ 0xE7
ATA_STATUS_BSY         equ 0x80
ATA_STATUS_RDY         equ 0x40
ATA_STATUS_DRQ         equ 0x08
ATA_STATUS_ERR         equ 0x01

; ========== TAMANHOS ==========
SETOR_TAMANHO          equ 512
BUFFER_TAMANHO         equ 4096

; ========== EXPORTAÇÃO ==========
global disco_ler_setor
global disco_escrever_setor
global obter_tamanho_disco
global detectar_disco
global identificar_disco
global flush_disco
global buffer_setor

global syscall_obter_tamanho
global syscall_ler_setor
global syscall_escrever_setor

section .bss
align 16
buffer_leitura:   resb BUFFER_TAMANHO
buffer_escrita:   resb BUFFER_TAMANHO
info_disco:       resw 256          ; Dados do IDENTIFY
tamanho_total:    resq 1            ; Total de setores LBA48
disco_ativo:      resd 1            ; 0=nenhum, 1=primário
buffer_setor:     resb 512

section .text

; ==========================================
; ✅ DETECTAR DISCO — Verifica se existe
; Entrada: RDI = número do disco (0=primário)
; Saída: RAX = 1=encontrado, 0=não
; ==========================================
detectar_disco:
    push rcx
    push rdx
    xor rdi, rdi                ; apenas disco primário por ora
    mov rdx, ATA_CMD
    mov rcx, 100000
.aguardar:
    in al, dx
    test al, ATA_STATUS_BSY
    jz .pronto
    dec rcx
    jnz .aguardar
    jmp .nao_encontrado         ; timeout → sem disco
.pronto:
    in al, dx
    test al, ATA_STATUS_ERR
    jnz .nao_encontrado
    mov rax, 1
    jmp .fim
.nao_encontrado:
    xor eax, eax
.fim:
    pop rdx
    pop rcx
    ret

; ==========================================
; ✅ IDENTIFICAR DISCO — Pega modelo, serial, tamanho
; Entrada: RDI = número do disco, RSI = buffer saída (512 bytes)
; Saída: RAX = 1=sucesso, 0=falha
; ==========================================
identificar_disco:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8

    mov r8, rsi                 ; buffer do chamador

    call detectar_disco
    cmp rax, 1
    jne .falha

    ; Enviar comando IDENTIFY
    mov rdx, ATA_SECTORS
    xor al, al
    out dx, al
    mov rdx, ATA_LBA_LO
    xor al, al
    out dx, al
    mov rdx, ATA_LBA_MID
    xor al, al
    out dx, al
    mov rdx, ATA_LBA_HI
    xor al, al
    out dx, al
    mov rdx, ATA_CMD
    mov al, ATA_CMD_IDENTIFY
    out dx, al

    ; Aguardar BSY zerar (com timeout)
    mov rcx, 100000
.aguardar_bsy:
    in al, dx
    test al, ATA_STATUS_BSY
    jz .bsy_liberado
    dec rcx
    jnz .aguardar_bsy
    jmp .falha
.bsy_liberado:
    in al, dx
    test al, ATA_STATUS_ERR
    jnz .falha
    test al, ATA_STATUS_DRQ
    jz .falha

    ; Ler 256 palavras = 512 bytes
    mov rcx, 256
    lea rdi, [rel info_disco]
    mov rdx, ATA_DATA
    rep insw

    ; Extrair tamanho LBA48 (palavras 100-103 → offset 200)
    mov rax, [rel info_disco + 200]
    mov [rel tamanho_total], rax

    ; Copiar para buffer do chamador
    mov rdi, r8
    lea rsi, [rel info_disco]
    mov rcx, 512
    rep movsb

    mov rax, 1
    jmp .fim
.falha:
    xor eax, eax
.fim:
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ==========================================
; ✅ OBTER TAMANHO DO DISCO — setores totais
; Saída: RAX = total de setores (512B)
; ==========================================
obter_tamanho_disco:
    push rdx

    cmp qword [rel tamanho_total], 0
    jne .ja_salvo

    ; Ainda não identificado → identifica agora
    mov edi, 0
    mov esi, 0
    call identificar_disco

.ja_salvo:
    mov rax, [rel tamanho_total]
    cmp rax, 0
    jne .fim
    mov rax, 1000000000         ; fallback ~500GB em setores
.fim:
    pop rdx
    ret

; ==========================================
; ✅ LER SETOR
; Assinatura: bool disco_ler_setor(const char* disco, u64 lba, void* buffer)
;   rdi = caminho (ignorado), rsi = LBA, rdx = buffer saída
; ==========================================
disco_ler_setor:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8

    mov r8, rdx                 ; buffer de saída

    ; Validar LBA
    cmp rsi, [rel tamanho_total]
    jae .falha

    ; Preparar comando LBA28 — CORREÇÃO: byte baixo primeiro
    mov rax, rsi
    mov rdx, ATA_SECTORS
    mov al, 1                   ; 1 setor
    out dx, al

    mov rax, rsi
    mov rdx, ATA_LBA_LO
    out dx, al                  ; bits 0-7
    shr rax, 8
    mov rdx, ATA_LBA_MID
    out dx, al                  ; bits 8-15
    shr rax, 8
    mov rdx, ATA_LBA_HI
    out dx, al                  ; bits 16-23
    shr rax, 8
    and al, 0x0F                ; bits 24-27
    or al, 0xE0                 ; bit 6=1 (LBA) + modo master
    mov rdx, ATA_LBA_HI         ; (registro drive é 0x1F6 = LBA_HI+1)
    inc edx
    out dx, al

    ; Enviar comando
    mov rdx, ATA_CMD
    mov al, ATA_CMD_READ
    out dx, al

    ; Aguardar dados
    mov rcx, 100000
.aguardar:
    in al, dx
    test al, ATA_STATUS_BSY
    jnz .espera
    test al, ATA_STATUS_ERR
    jnz .falha
    test al, ATA_STATUS_DRQ
    jnz .dados_prontos
.espera:
    dec rcx
    jnz .aguardar
    jmp .falha

.dados_prontos:
    ; Ler 512 bytes para o buffer do chamador
    mov rcx, 128                ; 128 x 4 bytes = 512
    mov rdi, r8
    mov rdx, ATA_DATA
    rep insd

    ; Cache flush pós-leitura não é necessário; sucesso
    mov rax, 1
    jmp .fim

.falha:
    xor eax, eax
.fim:
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ==========================================
; ✅ ESCREVER SETOR
; Assinatura: bool disco_escrever_setor(const char* disco, u64 lba, const void* buffer)
;   rdi = caminho (ignorado), rsi = LBA, rdx = buffer entrada
; ==========================================
disco_escrever_setor:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8

    mov r8, rdx                 ; buffer de entrada

    ; Preparar comando LBA28 — mesma correção de bytes
    mov rdx, ATA_SECTORS
    mov al, 1
    out dx, al

    mov rax, rsi
    mov rdx, ATA_LBA_LO
    out dx, al
    shr rax, 8
    mov rdx, ATA_LBA_MID
    out dx, al
    shr rax, 8
    mov rdx, ATA_LBA_HI
    out dx, al
    shr rax, 8
    and al, 0x0F
    or al, 0xE0
    mov rdx, ATA_LBA_HI + 1     ; registro drive (0x1F6)
    out dx, al

    ; Enviar comando de escrita
    mov rdx, ATA_CMD
    mov al, ATA_CMD_WRITE
    out dx, al

    ; Aguardar pronto para receber dados
    mov rcx, 100000
.aguardar:
    in al, dx
    test al, ATA_STATUS_BSY
    jnz .espera
    test al, ATA_STATUS_ERR
    jnz .falha
    test al, ATA_STATUS_DRQ
    jnz .dados_prontos
.espera:
    dec rcx
    jnz .aguardar
    jmp .falha

.dados_prontos:
    ; Escrever 512 bytes do buffer do chamador
    mov rcx, 128
    mov rsi, r8
    mov rdx, ATA_DATA
    rep outsd

    ; Aguardar conclusão da escrita (com timeout)
    mov rcx, 1000000
.espera_fim:
    in al, dx
    test al, ATA_STATUS_BSY
    jz .gravado
    dec rcx
    jnz .espera_fim
    jmp .falha
.gravado:
    call flush_disco
    mov rax, 1
    jmp .fim

.falha:
    xor eax, eax
.fim:
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ==========================================
; ✅ FLUSH — Garante gravação em disco
; ==========================================
flush_disco:
    push rcx
    push rdx
    mov rdx, ATA_CMD
    mov al, ATA_CMD_FLUSH
    out dx, al
    mov rcx, 1000000
.aguardar:
    in al, dx
    test al, ATA_STATUS_BSY
    jz .ok
    dec rcx
    jnz .aguardar
.ok:
    mov rax, 1
    pop rdx
    pop rcx
    ret

; ==========================================
; Pontes de syscall (convite x64 System V)
; ==========================================
syscall_obter_tamanho:
    call obter_tamanho_disco
    ret

syscall_ler_setor:
    ; rdi=disco, rsi=LBA, rdx=buffer → repassa direto
    call disco_ler_setor
    ret

syscall_escrever_setor:
    call disco_escrever_setor
    ret
