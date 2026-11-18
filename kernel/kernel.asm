; ======================================
; Kernel FydelisTech OS - v4.2 COMPLETO (CORRIGIDO)
; Transicao 16/32/64-bit + VESA + BSS Zero + GDT/IDT + PIC Mask + Deteccao Real
; Salvador - Bahia
; ======================================
DEFAULT REL
%include "fydelterm.inc"

extern __bss_start
extern __bss_end
extern gdt_init
extern idt_init
extern kernel_exec_bin
extern construir_estrutura_sistema
extern pmm_inicializar
extern mem_detect_e820
extern mem_total, mem_livre
extern fb_base, fb_largura, fb_altura, fb_pitch, fb_bpp
extern fb_inicializar
extern gpu_preencher_tela
extern gpu_preencher_retangulo
extern get_key
extern reset_buffer
extern set_input_base
extern add_char
extern parse_line
extern interpret_command

extern detectar_disco
extern identificar_disco
extern disco_ler_setor
extern disco_escrever_setor
extern obter_tamanho_disco

extern audio_init
extern bt_detectar_placa
extern bt_inicializar
extern inicializar_nic_mmio

extern hosts_inicializar
extern fydlog_inicializar

;extern pci_init
;extern usb_scan_controllers

extern cve_guard_iniciar
extern cve_guard_adicionar_regra
extern cve_guard_inspecionar_comando

global bytes_para_gb
global _entry16
global start

; ======================================
; CONSTANTES
; ======================================
PAGE_SIZE        equ 4096
PAGE_2MB         equ 0x200000
MB_MULT          equ 1048576        ; Bytes -> MB
GB_MULT          equ 1073741824     ; Bytes -> GB

; ATA/IDE
ATA_DATA         equ 0x1F0
ATA_SECTORS      equ 0x1F2
ATA_LBA_LO       equ 0x1F3
ATA_LBA_MID      equ 0x1F4
ATA_LBA_HI       equ 0x1F5
ATA_CMD          equ 0x1F7
ATA_CMD_READ     equ 0x20
ATA_CMD_WRITE    equ 0x30
ATA_CMD_IDENTIFY equ 0xEC
ATA_STATUS_BSY   equ 0x80
ATA_STATUS_RDY   equ 0x40
ATA_STATUS_DRQ   equ 0x08
ATA_STATUS_ERR   equ 0x01
SETOR_TAMANHO    equ 512

; PALETA
COR_FUNDO        equ 0xFF090611
COR_ROXO_ESCURO  equ 0xFF2A1050
COR_ROXO_NEON    equ 0xFF9D4EDD
COR_CIANO_NEON   equ 0xFF00FFFF
COR_CINZA_VIDRO  equ 0xFF3A2060
COR_TEXTO        equ 0xFFF0E6FF

; ======================================
; ESTAGIO DE TRANSICAO (16 -> 32 -> 64-BIT)
; Fixado no inicio absoluto de .text (offset 0x8000)
; ======================================
section .text._start
BITS 16
_entry16:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7C00

    ; Limpa estrutura VESA em 0x7000
    mov     dword [0x7000], 0
    mov     dword [0x7004], 0

    ; 1. Detectar VESA (VBE2)
    mov     dword [0x5000], '2EBV'
    mov     di, 0x5000
    mov     ax, 0x4F00
    int     0x10
    cmp     ax, 0x004F
    jne     .sem_vesa

    ; 2. Tenta modo 0x145; se falhar, usa 0x118 (1024x768 padrao)
    mov     bx, 0x0145
    mov     cx, bx
    mov     di, 0x5200
    mov     ax, 0x4F01
    int     0x10
    cmp     ax, 0x004F
    je      .vesa_ok

    mov     bx, 0x0118
    mov     cx, bx
    mov     di, 0x5200
    mov     ax, 0x4F01
    int     0x10
    cmp     ax, 0x004F
    jne     .sem_vesa

.vesa_ok:
    mov     eax, [es:di+0x28]       ; Endereco fisico do LFB
    mov     [0x7000], eax
    mov     ax, [es:di+0x12]        ; Largura
    mov     [0x7008], ax
    mov     ax, [es:di+0x14]        ; Altura
    mov     [0x700A], ax
    mov     ax, [es:di+0x10]        ; Pitch
    mov     [0x700C], ax
    mov     al, [es:di+0x19]        ; BPP
    mov     [0x700E], al

    ; 3. Ativar modo grafico VESA com bit LFB (0x4000)
    or      bx, 0x4000
    mov     ax, 0x4F02
    int     0x10

.sem_vesa:
    ; 4. Habilitar A20 e entrar em Modo Protegido (32-bit)
    in      al, 0x92
    or      al, 2
    out     0x92, al

    lgdt    [gdt_boot_desc]
    mov     eax, cr0
    or      eax, 1
    mov     cr0, eax
    jmp     0x08:_entry32

BITS 32
_entry32:
    mov     ax, 0x10
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     esp, 0x90000

    ; 5. Configurar Paginacao Identity Map de 4 GB (cobre Kernel + Framebuffer LFB)
    mov     edi, 0x1000
    xor     eax, eax
    mov     ecx, 6144               ; Zera 24 KB (0x1000..0x6FFF)
    rep     stosd

    mov     dword [0x1000], 0x2003
    mov     dword [0x2000], 0x3003
    mov     dword [0x2008], 0x4003
    mov     dword [0x2010], 0x5003
    mov     dword [0x2018], 0x6003

    mov     edi, 0x3000
    mov     eax, 0x00000083         ; Present + RW + Page Size (2MB)
    mov     ecx, 2048
.map_4gb:
    mov     [edi], eax
    add     eax, 0x00200000
    add     edi, 8
    dec     ecx
    jnz     .map_4gb

    mov     eax, 0x1000
    mov     cr3, eax

    ; Ativar PAE + LME (Long Mode) + Paging
    mov     eax, cr4
    or      eax, 1 << 5
    mov     cr4, eax

    mov     ecx, 0xC0000080
    rdmsr
    or      eax, 1 << 8
    wrmsr

    mov     eax, cr0
    or      eax, 1 << 31
    mov     cr0, eax

    lgdt    [dword gdt64_boot_desc]
    jmp     dword 0x18:start

align 8
gdt_boot_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF           ; 0x08: Codigo 32-bit
    dq 0x00CF92000000FFFF           ; 0x10: Dados 32-bit
    dq 0x00AF9A0000000000           ; 0x18: Codigo 64-bit
gdt_boot_end:

gdt_boot_desc:
    dw gdt_boot_end - gdt_boot_start - 1
    dd gdt_boot_start

gdt64_boot_desc:
    dw gdt_boot_end - gdt_boot_start - 1
    dq gdt_boot_start

; ======================================
; ENTRADA PRINCIPAL DO KERNEL (64-BIT)
; ======================================
BITS 64
start:
    cli
    cld                             ; Garante direcao crescente para rep stosb
    mov     ax, 0x10
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     rsp, 0x90000

    ; 0a. Zera toda a secao .bss (__bss_start ate __bss_end)
    lea     rdi, [rel __bss_start]
    lea     rcx, [rel __bss_end]
    sub     rcx, rdi                ; RCX = tamanho total do .bss em bytes
    jbe     .bss_limpo              ; Evita underflow se .bss tiver tamanho 0
    xor     eax, eax
    rep     stosb
.bss_limpo:

    ; 0b. Instala GDT definitiva (CS=0x08, TSS=0x28) e IDT 64-bit (seletor 0x08)
    call    gdt_init
    call    idt_init

    ; 0c. Silencia todas as IRQs do PIC 8259A legado (evita IRQ0 colidir com Vetor 8 / #DF)
    mov     al, 0xFF
    out     0x21, al
    out     0xA1, al

    ; Transferir dados VESA salvos em 0x7000 com extensao zero para 64/32 bits
    mov     eax, [0x7000]           ; Leitura 32-bit zera os 32 bits superiores de RAX
    mov     [fb_base], rax          ; Salva ponteiro completo de 64 bits
    movzx   eax, word [0x7008]
    mov     [fb_largura], eax
    movzx   eax, word [0x700A]
    mov     [fb_altura], eax
    movzx   eax, word [0x700C]
    mov     [fb_pitch], eax
    movzx   eax, byte [0x700E]
    mov     [fb_bpp], eax

    ; Inicializa o driver de video apenas se fb_base for valido
    cmp     qword [fb_base], 0
    je      .pula_fb
    call    fb_inicializar

    ; Pinta a tela inicial
    mov     rdi, COR_FUNDO
    call    gpu_preencher_tela
.pula_fb:

    ; [CHECKPOINT 1 - Faixa Azul: Video OK, testando print_string]
    mov     rdi, 10
    mov     rsi, 10
    mov     rdx, 120
    mov     rcx, 20
    mov     r8d, 0xFF0066FF
    call    gpu_preencher_retangulo

    lea     rsi, [msg_cabecalho]
    call    print_string

    ; ======================================
    ; FASE 1 - CPU
    ; ======================================
    lea     rsi, [msg_fase_cpu]
    call    print_string
    call    cpu_verificar
    cmp     rax, 1
    jne     .cpu_erro

    lea     rsi, [msg_cpu_info]
    call    print_string
    lea     rsi, [cpu_vendor]
    call    print_string
    call    print_newline

    ; [CHECKPOINT 2 - Faixa Verde: CPU e Texto OK, testando Memoria]
    mov     rdi, 140
    mov     rsi, 10
    mov     rdx, 250
    mov     rcx, 20
    mov     r8d, 0xFF00CC66
    call    gpu_preencher_retangulo

    ; ======================================
    ; FASE 2 - MEMORIA REAL
    ; ======================================
    lea     rsi, [msg_fase_mem]
    call    print_string
    call    pmm_inicializar
    call    mem_detect_e820

    mov     rax, [mem_total]
    mov     [mem_total_bytes], rax
    lea     rsi, [msg_mem_total]
    call    print_string
    mov     rdi, rax
    call    bytes_para_gb
    call    print_num
    lea     rsi, [msg_gb_sufixo]
    call    print_string

    mov     rax, [mem_livre]
    mov     [mem_livre_bytes], rax
    lea     rsi, [msg_mem_livre]
    call    print_string
    mov     rdi, rax
    call    bytes_para_gb
    call    print_num
    lea     rsi, [msg_gb_sufixo]
    call    print_string

    ; [CHECKPOINT 3 - Faixa Amarela: Memoria OK, testando Disco]
    mov     rdi, 270
    mov     rsi, 10
    mov     rdx, 380
    mov     rcx, 20
    mov     r8d, 0xFFFFCC00
    call    gpu_preencher_retangulo

    ; ======================================
    ; FASE 3 - DISCO REAL
    ; ======================================
    lea     rsi, [msg_fase_disco]
    call    print_string

    xor     rdi, rdi
    call    detectar_disco
    cmp     rax, 1
    jne     .sem_disco

    xor     rdi, rdi
    lea     rsi, [info_disco]
    call    identificar_disco

    call    obter_tamanho_disco
    mov     rdi, rax
    call    bytes_para_gb
    mov     [disco_tam_gb], eax

    lea     rsi, [msg_disco_tam]
    call    print_string
    mov     rdi, rax
    call    print_num
    lea     rsi, [msg_gb_sufixo]
    call    print_string

    jmp     .montar_estrutura

.sem_disco:
    lea     rsi, [msg_sem_disco]
    call    print_string

.montar_estrutura:
    ; ======================================
    ; FASE 4 - ESTRUTURA DE DIRETORIOS (/fyd)
    ; ======================================
    call    construir_estrutura_sistema
    call    hosts_inicializar
    call    fydlog_inicializar
    ; Inicializa o CVE Guard e carrega assinaturas base
    call    cve_guard_iniciar

    lea     rdi, [rel cve_id_1]
    lea     rsi, [rel cve_pad_1]
    lea     rdx, [rel cve_msg_1]
    call    cve_guard_adicionar_regra

    lea     rdi, [rel cve_id_2]
    lea     rsi, [rel cve_pad_2]
    lea     rdx, [rel cve_msg_2]
    call    cve_guard_adicionar_regra

    lea     rdi, [rel cve_id_3]
    lea     rsi, [rel cve_pad_3]
    lea     rdx, [rel cve_msg_3]
    call    cve_guard_adicionar_regra

    lea     rdi, [rel cve_id_4]
    lea     rsi, [rel cve_pad_4]
    lea     rdx, [rel cve_msg_4]
    call    cve_guard_adicionar_regra

    ; ======================================
    ; FASE 5 - PERIFERICOS & REDE (AUDIO, BLUETOOTH, E1000)
    ; ======================================
    lea     rsi, [msg_fase_hw]
    call    print_string

    call    audio_init

    call    bt_detectar_placa
    test    rax, rax
    jz      .sem_bt
    call    bt_inicializar
.sem_bt:

    call    inicializar_nic_mmio

    lea     rsi, [msg_hw_ok]
    call    print_string

.menu:
    ; ======================================
    ; MENU
    ; ======================================
    lea     rsi, [msg_opcoes]
    call    print_string

.escolha:
    call    get_key
    cmp     al, '1'
    je      .modo_terminal
    cmp     al, '2'
    je      .modo_grafico
    pause                           ; Reduz consumo de CPU durante espera
    jmp     .escolha

.cpu_erro:
    lea     rsi, [msg_cpu_erro]
    call    print_string
    cli
    hlt

; ======================================
; MODO GRAFICO
; ======================================
.modo_grafico:
    mov     rdi, COR_ROXO_ESCURO
    call    gpu_preencher_tela

    ; Barra de progresso centralizada
    mov     r10d, [fb_largura]
    mov     r11d, [fb_altura]
    mov     r12, r10
    shr     r12, 1
    mov     r13, 36
    mov     r14, r10
    sub     r14, r12
    shr     r14, 1
    mov     r15, r11
    sub     r15, r13
    shr     r15, 1

    ; Moldura neon
    lea     rdi, [r14 - 2]
    lea     rsi, [r15 - 2]
    lea     rdx, [r14 + r12 + 2]
    lea     rcx, [r15 + r13 + 2]
    mov     r8d, COR_ROXO_NEON
    call    gpu_preencher_retangulo

    ; Fundo
    mov     rdi, r14
    mov     rsi, r15
    lea     rdx, [r14 + r12]
    lea     rcx, [r15 + r13]
    mov     r8d, COR_CINZA_VIDRO
    call    gpu_preencher_retangulo

    ; Animacao
    xor     ebx, ebx
.barra_loop:
    cmp     ebx, 100
    jg      .barra_fim

    mov     rax, r12
    mul     rbx
    mov     ecx, 100
    div     ecx

    mov     r8d, COR_ROXO_NEON
    cmp     ebx, 100
    jne     .desenha
    mov     r8d, COR_CIANO_NEON
.desenha:
    mov     rdi, r14
    mov     rsi, r15
    lea     rdx, [r14 + rax]
    lea     rcx, [r15 + r13]
    call    gpu_preencher_retangulo

    mov     rcx, 350000
.pausa:
    pause
    dec     rcx
    jnz     .pausa
    inc     ebx
    jmp     .barra_loop

.barra_fim:
    lea     rsi, [msg_carregando]
    call    print_string
    call    print_newline

    ; Garante alinhamento estrito de 16 bytes na pilha antes de chamar C (System V ABI)
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    call    kernel_exec_bin

    mov     rsp, rbp
    pop     rbp

    lea     rsi, [msg_encerrado]
    call    print_string
    call    print_newline
    jmp     .modo_terminal

; ======================================
; MODO TERMINAL
; ======================================
.modo_terminal:
    mov     rdi, COR_FUNDO
    call    gpu_preencher_tela
    lea     rsi, [msg_cabecalho]
    call    print_string

main_loop:
    call    reset_buffer
    lea     rsi, [msg_prompt]
    call    print_string
    call    set_input_base
.le_tecla:
    call    get_key
    cmp     al, KEY_NULL
    jne     .processa_tecla
    pause                           ; Alivia CPU enquanto aguarda digitacao
    jmp     .le_tecla
.processa_tecla:
    cmp     al, KEY_ENTER
    je      .executa
    cmp     al, KEY_BACKSPACE
    je      .trata_bs
    cmp     al, 0x20
    jb      .le_tecla
    cmp     al, 0x7E
    ja      .le_tecla
    push    rax
    call    add_char
    pop     rax
    call    print_char
    jmp     .le_tecla
.trata_bs:
    cmp     dword [buf_head], 0
    je      .le_tecla
    mov     al, KEY_BACKSPACE
    call    print_char
    mov     al, ' '
    call    print_char
    call    print_char
    dec     dword [buf_head]
    mov     eax, [buf_head]
    mov     byte [buffer + rax], 0
    jmp     .le_tecla
.executa:
    call    print_newline
    mov     eax, [buf_head]
    mov     byte [buffer + rax], 0
    cmp     dword [buf_head], 0
    je      main_loop

    ; Inspeciona o comando contra as regras do CVE Guard
    lea     rdi, [rel buffer]
    call    cve_guard_inspecionar_comando
    cmp     rax, 1
    je      .comando_bloqueado

    call    parse_line
    call    interpret_command
    jmp     main_loop

.comando_bloqueado:
    lea     rsi, [rel msg_cve_bloqueado]
    call    print_string
    jmp     main_loop

; ======================================
; CONVERSAO DE UNIDADES
; ======================================
section .text
bytes_para_gb:
    mov     rax, rdi
    mov     rcx, GB_MULT
    xor     rdx, rdx
    div     rcx
    ret

print_num:
    push    rbx
    push    rcx
    push    rdx
    push    rax

    mov     rax, rdi
    mov     rcx, 10
    sub     rsp, 32
    mov     rbx, rsp
    mov     byte [rbx], 0
    dec     rbx

.converte:
    xor     rdx, rdx
    div     rcx
    add     dl, '0'
    mov     [rbx], dl
    dec     rbx
    test    rax, rax
    jnz     .converte

    inc     rbx
    mov     rsi, rbx
    call    print_string

    add     rsp, 32
    pop     rax
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ======================================
; CPU - DETECCAO
; ======================================
cpu_verificar:
    push    rbx
    pushfq
    pushfq
    xor     qword [rsp], 1 << 21
    popfq
    pushfq
    pop     rax
    xor     rax, [rsp]
    jz      .sem_cpuid
    popfq

    xor     rax, rax
    cpuid
    cmp     rax, 1
    jb      .erro

    mov     rax, 0
    cpuid
    mov     [cpu_vendor], ebx
    mov     [cpu_vendor+4], edx
    mov     [cpu_vendor+8], ecx
    mov     byte [cpu_vendor+12], 0

    mov     rax, 1
    cpuid
    pop     rbx
    mov     rax, 1
    ret
.sem_cpuid:
.erro:
    popfq
    pop     rbx
    xor     rax, rax
    ret

; ======================================
; PAGINACAO
; ======================================
paging_init:
    push    rbx
    mov     rdi, pml4
    mov     rcx, 512
    xor     rax, rax
    rep     stosq
    mov     rdi, pdpt
    mov     rcx, 512
    xor     rax, rax
    rep     stosq
    mov     rdi, pdt
    mov     rcx, 512
    xor     rax, rax
    rep     stosq

    mov     rax, pdpt
    or      rax, 1 | 2
    mov     [pml4], rax
    mov     rax, pdt
    or      rax, 1 | 2
    mov     [pdpt], rax

    mov     rdi, pdt
    mov     rcx, 512
    mov     rax, 1 | 2 | (1<<7)
.map_2mb:
    mov     [rdi], rax
    add     rax, PAGE_2MB
    add     rdi, 8
    dec     rcx
    jnz     .map_2mb

    mov     rax, pml4
    mov     cr3, rax
    mov     rax, cr4
    or      rax, 1<<5
    mov     cr4, rax
    mov     rax, cr0
    or      rax, 1<<31
    mov     cr0, rax
    pop     rbx
    ret

; ======================================
; MENSAGENS
; ======================================
section .rodata
msg_cabecalho:   db '+------------------------------------------------------------+',10
                 db '|          FYDELISTECH OS - Sistema Operacional do Zero      |',10
                 db '|                    v4.2 - Salvador - Bahia                 |',10
                 db '+------------------------------------------------------------+',10,10,0

msg_fase_cpu:    db '  [*] Verificando processador...',0
msg_fase_mem:    db '  [*] Inicializando memoria...',0
msg_fase_disco:  db '  [*] Detectando armazenamento...',0
msg_fase_hw:     db '  [*] Inicializando Audio, Bluetooth e Rede E1000...',0
msg_hw_ok:       db ' OK',10,0
msg_fase_gpu:    db '  [*] Preparando interface...',0

msg_cpu_info:    db '  [OK] Processador: ',0
msg_mem_total:   db '  [OK] Memoria Total: ',0
msg_mem_livre:   db '  [OK] Memoria Livre: ',0
msg_disco_info:  db '  [OK] Disco: ',0
msg_disco_modelo:db '  [OK] Modelo: ',0
msg_disco_tam:   db '  [OK] Tamanho Total: ',0
msg_gb_sufixo:   db ' GB',10,0
msg_mb_sufixo:   db ' MB',10,0
msg_sep:         db ' / ',0

msg_opcoes:      db 10,'  Escolha:',10
                 db '    [1] Terminal FydelTerm',10
                 db '    [2] Area de Trabalho Grafica',10,10,'  -> ',0
msg_prompt:      db 'fydelterm> ',0
msg_sem_disco:   db '  [!] Disco nao detectado',10,0
msg_cpu_erro:    db '  [X] CPU incompativel',10,0

msg_carregando:  db 'Enviando para framebuffer...',10,0
msg_encerrado:   db 'Sessao grafica encerrada.',10,0

; ======================================
; DADOS
; ======================================
section .bss
align 4
cpu_vendor:        resb 16
mem_total_bytes:   resq 1
mem_livre_bytes:   resq 1
disco_setores:     resq 1
disco_tam_gb:      resd 1
disco_modelo_str:  resb 40

align 16
info_disco:        resw 256
buffer_setor:      resb 512

align 4096
pml4:   resb PAGE_SIZE
pdpt:   resb PAGE_SIZE
pdt:    resb PAGE_SIZE
