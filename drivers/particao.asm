; ==========================================
; 💽 PARTICAO.ASM — Nomenclatura Híbrida FydelisTech
; Letras A:B:C: + Pastas /fyd/disco/ fyd/usb/ fyd/midia/
; MBR · GPT · FAT32 · exFAT · v2.2
; Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
default rel
%include "fydelterm.inc"

; ========== TAMANHOS E CONSTANTES ==========
SETOR_TAMANHO           equ 512
FAT32_ENTRADA_DIR       equ 32
EXFAT_ENTRADA_DIR       equ 64
MAX_DISCOS_FIXOS        equ 8     ; fyd1 a fyd8 → C: até J:
MAX_USB                 equ 8     ; fydu1 a fydu8 → U1: até U8:
MAX_MIDIA               equ 4     ; fydm1 a fydm4 → M1: até M4:
MAX_REDE                equ 4     ; fydr1 a fydr4 → R1: até R4:
LIMIAR_GPT_SETORES      equ 4000000000  ; ~2 TB → GPT

; ========== TIPOS DE DISPOSITIVO ==========
TIPO_DISCO_FIXO         equ 1
TIPO_USB                equ 2
TIPO_MIDIA_REMOVIVEL    equ 3
TIPO_REDE               equ 4

; ========== MBR / GPT ==========
MBR_ASSINATURA          equ 0xAA55
MBR_PARTICAO_OFFSET     equ 0x1BE
MBR_TIPO_FAT32          equ 0x0B
MBR_TIPO_FAT32_LBA      equ 0x0C
MBR_TIPO_EXFAT          equ 0x07
MBR_TIPO_EFI            equ 0xEF
GPT_CABECALHO_LBA       equ 1
GPT_ENTRADAS_LBA        equ 2
GPT_QTD_ENTRADAS        equ 128
GPT_TAMANHO_ENTRADA     equ 128
GPT_PARTICAO_INICIAL    equ 34

; ========== FAT32 ==========
FAT32_ASSINATURA_BPB    equ 0x28

; ========== EXPORTAÇÃO ==========
global detectar_tabela
global listar_unidades
global criar_unidade
global remover_unidade
global formatar_unidade
global formatar_fat32
global formatar_exfat
global inicializar_disco
global mapa_unidades          ; compatível com commands.asm
global mapa_dispositivos      ; novo sistema de pastas
global criar_particao
global apagar_entrada_particao

; ========== EXTERN ==========
extern print_string, print_char, print_newline
extern int_para_str

; ========== ESTRUTURA DE UNIDADE ==========
struc Unidade
    .letra:         resb 1    ; +0
    .tipo_sistema:  resb 1    ; +1  <- lido por do_fstype
    .lba_inicio:    resq 1    ; +2
    .lba_tamanho:   resq 1    ; +10
    .ativo:         resb 1    ; +18
    .removivel:     resb 1    ; +19
    .reservado:     resb 58   ; +20 .. +79 (total 80 bytes)
endstruc

; ========== ESTRUTURA DE DISPOSITIVO ==========
struc Dispositivo
    .tipo:          resb 1     ; 1=fixo, 2=usb, 3=midia, 4=rede
    .indice:        resb 1     ; 1, 2, 3...
    .letra_str:     resb 3     ; "C:", "U1", "M1"...
    .caminho:       resb 32    ; "/fyd/disco/fyd1"
    .lba_inicio:    resq 1
    .lba_tamanho:   resq 1
    .tipo_fs:       resb 1     ; FAT32, exFAT...
    .ativo:         resb 1
    .reservado:     resb 22
endstruc

section .data
msg_cab_disp:   db "  TIPO    | NOME     | LETRA | CAMINHO               | TAMANHO",10, \
                   "----------+----------+-------+-----------------------+----------",10,0
msg_disco_fixo: db "Disco",0
msg_usb:        db "USB",0
msg_midia:      db "Mídia",0
msg_rede:       db "Rede",0
msg_exfat:      db "exFAT",0
msg_fat32:      db "FAT32",0
msg_fydfs:      db "FydelisFS",0
msg_cabecalho:  db "  UNIDADE  |   SISTEMA   |  TAMANHO    |  STATUS",10, \
                   " ----------+------------+-------------+----------",10,0
msg_ativo:      db "  Ativo",10,0
msg_sep:        db "  |  ",0
msg_espaco:     db " ",0

pasta_disco:    db "/fyd/disco",0
pasta_usb:      db "/fyd/usb",0
pasta_midia:    db "/fyd/midia",0
pasta_rede:     db "/fyd/rede",0
prefixo_fyd:    db "fyd",0
prefixo_usb:    db "fydu",0
prefixo_midia:  db "fydm",0
prefixo_rede:   db "fydr",0

msg_kb:         db " KB",0
msg_mb:         db " MB",0
msg_gb:         db " GB",0
msg_tb:         db " TB",0

section .bss
align 16
buffer_setor:            resb 512
buffer_fat:              resb 4096
buffer_conversao:        resb 32
buffer_caminho:          resb 64

mapa_unidades:           resb 26 * Unidade_size
mapa_dispositivos:       resb (MAX_DISCOS_FIXOS + MAX_USB + MAX_MIDIA + MAX_REDE) * Dispositivo_size
qtd_unidades:            resd 1
qtd_dispositivos:        resd 1
prox_disco_fixo:         resd 1
prox_usb:                resd 1
prox_midia:              resd 1
prox_rede:               resd 1
tipo_tabela:             resb 1
tamanho_disco_setores:   resq 1
ultimo_lba_usado:        resq 1

section .text

; ==========================================
; 🚀 INICIALIZAR — Detecta MBR/GPT + Monta pastas
; ==========================================
inicializar_disco:
    push rax
    push rdi

    mov dword [rel prox_disco_fixo], 1
    mov dword [rel prox_usb], 1
    mov dword [rel prox_midia], 1
    mov dword [rel prox_rede], 1
    mov dword [rel qtd_dispositivos], 0

    xor edi, edi
    call ler_setor
    cmp rax, 1
    jne .forcar_inicializacao

    cmp word [rel buffer_setor + 510], MBR_ASSINATURA
    je .ja_possui_mbr

.forcar_inicializacao:
    call particao_tamanho_disco
    cmp rax, LIMIAR_GPT_SETORES
    jae .usar_gpt

    mov byte [rel tipo_tabela], 0
    call inicializar_mbr
    jmp .mapear

.usar_gpt:
    mov byte [rel tipo_tabela], 1
    call escrever_cabecalho_gpt
    jmp .mapear

.ja_possui_mbr:
    call detectar_tabela

.mapear:
    call atualizar_mapa
    call mapear_para_dispositivos

.fim:
    pop rdi
    pop rax
    ret

; ==========================================
; 📂 MAPEAR UNIDADES → Dispositivos com Caminho
; ==========================================
mapear_para_dispositivos:
    push rbx
    push rcx
    push rdi
    push rsi

    xor ebx, ebx
.loop:
    cmp ebx, 26
    jae .fim

    mov rax, rbx
    imul rax, Unidade_size
    lea rdi, [rel mapa_unidades]
    add rdi, rax

    cmp byte [rdi + Unidade.letra], 0
    je .prox

    xor ecx, ecx
.busca:
    cmp ecx, (MAX_DISCOS_FIXOS + MAX_USB + MAX_MIDIA + MAX_REDE)
    jae .cheio
    mov rsi, rcx
    imul rsi, Dispositivo_size
    lea rdx, [rel mapa_dispositivos]
    add rdx, rsi
    cmp byte [rdx + Dispositivo.tipo], 0
    je .encontrado
    inc ecx
    jmp .busca

.encontrado:
    mov byte [rdx + Dispositivo.tipo], TIPO_DISCO_FIXO
    mov eax, [rel prox_disco_fixo]
    mov [rdx + Dispositivo.indice], al

    mov al, 'C'
    add al, [rel prox_disco_fixo]
    sub al, 1
    mov [rdx + Dispositivo.letra_str], al
    mov byte [rdx + Dispositivo.letra_str + 1], ':'
    mov byte [rdx + Dispositivo.letra_str + 2], 0

    lea rsi, [rel pasta_disco]
    lea rdi, [rel buffer_caminho]
    call copiar_string
    lea rsi, [rel prefixo_fyd]
    call copiar_string
    mov al, [rel prox_disco_fixo]
    add al, '0'
    stosb
    mov byte [rdi], 0

    lea rsi, [rel buffer_caminho]
    lea rdi, [rdx + Dispositivo.caminho]
    call copiar_string

    mov rax, [rdi + Unidade.lba_inicio]
    mov [rdx + Dispositivo.lba_inicio], rax
    mov rax, [rdi + Unidade.lba_tamanho]
    mov [rdx + Dispositivo.lba_tamanho], rax
    mov al, [rdi + Unidade.tipo_sistema]
    mov [rdx + Dispositivo.tipo_fs], al
    mov byte [rdx + Dispositivo.ativo], 1

    inc dword [rel prox_disco_fixo]
    inc dword [rel qtd_dispositivos]

.prox:
    inc ebx
    jmp .loop

.cheio:
.fim:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; ==========================================
; 📋 LISTAR UNIDADES
; ==========================================
listar_unidades:
    push rbx
    push rsi
    push rdi
    push rax

    call atualizar_mapa
    call mapear_para_dispositivos

    lea rsi, [rel msg_cab_disp]
    call print_string

    xor ebx, ebx
.loop:
    cmp ebx, (MAX_DISCOS_FIXOS + MAX_USB + MAX_MIDIA + MAX_REDE)
    jae .fim

    mov rax, rbx
    imul rax, Dispositivo_size
    lea rdi, [rel mapa_dispositivos]
    add rdi, rax

    cmp byte [rdi + Dispositivo.tipo], 0
    je .prox

    mov al, ' '
    call print_char
    cmp byte [rdi + Dispositivo.tipo], TIPO_DISCO_FIXO
    je .imp_fixo
    cmp byte [rdi + Dispositivo.tipo], TIPO_USB
    je .imp_usb
    cmp byte [rdi + Dispositivo.tipo], TIPO_MIDIA_REMOVIVEL
    je .imp_midia
    lea rsi, [rel msg_rede]
    jmp .imp_tipo
.imp_fixo:
    lea rsi, [rel msg_disco_fixo]
    jmp .imp_tipo
.imp_usb:
    lea rsi, [rel msg_usb]
    jmp .imp_tipo
.imp_midia:
    lea rsi, [rel msg_midia]
.imp_tipo:
    call print_string
    lea rsi, [rel msg_sep]
    call print_string

    lea rsi, [rdi + Dispositivo.caminho + 11]
    call print_string
    lea rsi, [rel msg_sep]
    call print_string

    lea rsi, [rdi + Dispositivo.letra_str]
    call print_string
    lea rsi, [rel msg_sep]
    call print_string

    lea rsi, [rdi + Dispositivo.caminho]
    call print_string
    lea rsi, [rel msg_sep]
    call print_string

    mov rax, [rdi + Dispositivo.lba_tamanho]
    shl rax, 9
    call bytes_para_texto
    call print_newline

.prox:
    inc ebx
    jmp .loop

.fim:
    cmp dword [rel qtd_dispositivos], 0
    jne .saiu

    lea rsi, [rel msg_cabecalho]
    call print_string
    xor ebx, ebx
.loop_antigo:
    cmp ebx, 26
    jae .saiu

    mov rax, rbx
    imul rax, Unidade_size
    lea rdi, [rel mapa_unidades]
    add rdi, rax

    cmp byte [rdi + Unidade.letra], 0
    je .prox_antigo

    mov al, ' '
    call print_char
    call print_char
    mov al, [rdi + Unidade.letra]
    call print_char
    mov al, ':'
    call print_char
    mov al, ' '
    call print_char
    call print_char
    call print_char

    mov al, [rdi + Unidade.tipo_sistema]
    cmp al, MBR_TIPO_FAT32
    je .tipo_f32
    cmp al, MBR_TIPO_FAT32_LBA
    je .tipo_f32
    cmp al, MBR_TIPO_EXFAT
    je .tipo_ex
    lea rsi, [rel msg_fydfs]
    jmp .imp_t
.tipo_f32:
    lea rsi, [rel msg_fat32]
    jmp .imp_t
.tipo_ex:
    lea rsi, [rel msg_exfat]
.imp_t:
    call print_string
    lea rsi, [rel msg_sep]
    call print_string
    mov rax, [rdi + Unidade.lba_tamanho]
    shl rax, 9
    call bytes_para_texto
    lea rsi, [rel msg_ativo]
    call print_string

.prox_antigo:
    inc ebx
    jmp .loop_antigo

.saiu:
    pop rax
    pop rdi
    pop rsi
    pop rbx
    ret

; ========== FUNÇÕES AUXILIARES ==========
copiar_string:
    lodsb
    stosb
    test al, al
    jnz copiar_string
    ret

bytes_para_texto:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    mov rbx, 1000000000000
    cmp rax, rbx
    jae .tb
    mov rbx, 1000000000
    cmp rax, rbx
    jae .gb
    mov rbx, 1000000
    cmp rax, rbx
    jae .mb
    mov rbx, 1024
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conversao]
    call int_para_str
    lea rsi, [rel buffer_conversao]
    call print_string
    lea rsi, [rel msg_kb]
    call print_string
    jmp .fim
.mb:
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conversao]
    call int_para_str
    lea rsi, [rel buffer_conversao]
    call print_string
    lea rsi, [rel msg_mb]
    call print_string
    jmp .fim
.gb:
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conversao]
    call int_para_str
    lea rsi, [rel buffer_conversao]
    call print_string
    lea rsi, [rel msg_gb]
    call print_string
    jmp .fim
.tb:
    xor rdx, rdx
    div rbx
    lea rdi, [rel buffer_conversao]
    call int_para_str
    lea rsi, [rel buffer_conversao]
    call print_string
    lea rsi, [rel msg_tb]
    call print_string
.fim:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ==========================================
; ➕ CRIAR UNIDADE
; ==========================================
criar_unidade:
    push rbx
    push rsi
    push rdi
    push rdx
    push rax

    cmp rdi, 26
    jae .invalido

    mov rax, rdi
    imul rax, Unidade_size
    lea rbx, [rel mapa_unidades]
    add rbx, rax

    cmp byte [rbx + Unidade.letra], 0
    jne .em_uso

    mov al, 'A'
    add al, dil
    mov [rbx + Unidade.letra], al
    mov byte [rbx + Unidade.ativo], 1

    cmp byte [rel tipo_tabela], 1
    je .gpt_comeco
    mov rcx, 2048
    jmp .definido
.gpt_comeco:
    mov rcx, [rel ultimo_lba_usado]
.definido:
    mov rsi, rdx
    mov rdx, MBR_TIPO_FAT32
    call criar_particao
    test rax, rax
    jz .erro

    cmp byte [rel tipo_tabela], 1
    jne .fim
    mov rax, [rel ultimo_lba_usado]
    add rax, rsi
    mov [rel ultimo_lba_usado], rax

.fim:
    mov rax, 1
    jmp .saida
.invalido:
.em_uso:
.erro:
    xor rax, rax
.saida:
    pop rax
    pop rdx
    pop rdi
    pop rsi
    pop rbx
    ret

; ==========================================
; ➖ REMOVER UNIDADE
; ==========================================
remover_unidade:
    push rbx
    push rdi
    push rax

    cmp rdi, 26
    jae .invalido

    mov rax, rdi
    imul rax, Unidade_size
    lea rbx, [rel mapa_unidades]
    add rbx, rax

    cmp byte [rbx + Unidade.letra], 0
    je .nao_existe

    mov rdi, [rbx + Unidade.lba_inicio]
    call apagar_entrada_particao

    mov byte [rbx + Unidade.letra], 0
    mov byte [rbx + Unidade.ativo], 0
    mov rax, 1
    jmp .fim

.invalido:
.nao_existe:
    xor rax, rax
.fim:
    pop rax
    pop rdi
    pop rbx
    ret

; ==========================================
; 💾 FORMATAR UNIDADE
; ==========================================
formatar_unidade:
    push rbx
    push rsi
    push rdi
    push rax

    cmp rdi, 26
    jae .invalido

    mov rax, rdi
    imul rax, Unidade_size
    lea rbx, [rel mapa_unidades]
    add rbx, rax

    cmp byte [rbx + Unidade.ativo], 0
    je .nao_existe

    cmp dword [rsi], 'FAT3'
    je .fmt_fat32
    cmp dword [rsi], 'exFA'
    je .fmt_exfat
    jmp .invalido

.fmt_fat32:
    mov rdi, [rbx + Unidade.lba_inicio]
    call formatar_fat32
    jmp .ok
.fmt_exfat:
    mov rdi, [rbx + Unidade.lba_inicio]
    call formatar_exfat
.ok:
    mov rax, 1
    jmp .fim

.invalido:
.nao_existe:
    xor rax, rax
.fim:
    pop rax
    pop rdi
    pop rsi
    pop rbx
    ret

; ==========================================
; ⚙️ SUBROUTINES DE SUPORTE (Stubs/Implementações)
; ==========================================
criar_particao:
    ; Entrada: rcx = LBA inicial, rsi = tamanho, rdx = tipo
    ; Saída: rax = 1 (sucesso)
    mov rax, 1
    ret

apagar_entrada_particao:
    ; Entrada: rdi = LBA inicial
    ; Saída: rax = 1 (sucesso)
    mov rax, 1
    ret

formatar_fat32:
    ; Entrada: rdi = LBA inicial
    ; Saída: rax = 1 (sucesso)
    mov rax, 1
    ret

formatar_exfat:
    ; Entrada: rdi = LBA inicial
    ; Saída: rax = 1 (sucesso)
    mov rax, 1
    ret

detectar_tabela:
    mov rax, 1
    ret

atualizar_mapa:
    ret

ler_setor:
    mov rax, 1
    ret

particao_tamanho_disco:
    mov rax, 5000000000     ; Exemplo: > 2TB para GPT ou menor para MBR
    ret

escrever_cabecalho_gpt:
    ret

; ==========================================
; 📝 INICIALIZAR MBR
; ==========================================
inicializar_mbr:
    push rdi
    push rcx
    push rsi

    mov rcx, 512
    lea rdi, [rel buffer_setor]
    xor eax, eax
    rep stosb
    mov word [rel buffer_setor + 510], MBR_ASSINATURA
    xor edi, edi

    pop rsi
    pop rcx
    pop rdi
    ret
