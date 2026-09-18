; ======================================
; RealSoft OS — Stage 1 / MBR Boot Manager
; Arquitetura: x86 16-bit Real Mode (BIOS)
; ======================================
[org 0x7C00]
[bits 16]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Limpa a tela (Modo Texto BIOS 80x25)
    mov ax, 0x0003
    int 0x10

    ; Exibe o cabeçalho e as opções do menu
    mov si, msg_title
    call print_string
    mov si, msg_menu
    call print_string

.aguarda_tecla:
    mov ah, 0x00
    int 0x16          ; Interrupção da BIOS para leitura de teclado

    cmp al, '1'
    je .boot_normal
    cmp al, '2'
    je .boot_debug
    jmp .aguarda_tecla

.boot_normal:
    mov si, msg_normal
    call print_string
    
    ; Lê o kernel padrão do disco rígido usando INT 0x13
    mov dl, 0x80      ; Unidade de disco principal (Drive 0)
    mov dh, 0         ; Cabeça 0
    mov ch, 0         ; Cilindro 0
    mov cl, 2         ; Setor 2 (logo após o MBR)
    mov bx, 0x7E00    ; Destino na memória RAM onde o kernel será carregado
    mov al, 20        ; Quantidade de setores a ler
    call load_sectors
    
    jmp 0x0000:0x7E00 ; Salta para o ponto de entrada do kernel

.boot_debug:
    mov si, msg_debug
    call print_string
    
    ; Exemplo: Carrega setores alternativos ou passa parâmetros de depuração
    mov dl, 0x80
    mov dh, 0
    mov ch, 0
    mov cl, 22        ; Setor de uma imagem de kernel de debug secundária
    mov bx, 0x7E00
    mov al, 20
    call load_sectors
    
    jmp 0x0000:0x7E00

load_sectors:
    mov ah, 0x02      ; Comando de leitura de setores da BIOS
    int 0x13
    jc .disk_error    ; Se aCarry flag estiver ativa, ocorreu erro de leitura
    ret

.disk_error:
    mov si, msg_error
    call print_string
    cli
.halt:
    hlt
    jmp .halt

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E      ; Função de impressão Teletype da BIOS
    int 0x10
    jmp print_string
.done:
    ret

; --- Textos do Gerenciador de Boot ---
msg_title   db 13, 10, '=====================================', 13, 10, '       REALSOFT BOOT MANAGER v2.0    ', 13, 10, '=====================================', 13, 10, 0
msg_menu    db ' 1. FydelTerm OS [Modo Normal]', 13, 10, ' 2. FydelTerm OS [Modo Debug / Verbose]', 13, 10, 13, 10, 'Selecione a opcao (1-2): ', 0
msg_normal  db 13, 10, '[*] Inicializando ambiente padrao...', 13, 10, 0
msg_debug   db 13, 10, '[*] Carregando logs de depuracao...', 13, 10, 0
msg_error   db 13, 10, '[!] Erro critico ao ler setores do disco!', 13, 10, 0

; Preenche o restante do setor MBR até 512 bytes e adiciona a assinatura de boot
times 510-($-$$) db 0
dw 0xAA55
