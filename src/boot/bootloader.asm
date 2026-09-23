; ==========================================
; FydelisTech - Custom Bootloader MBR (512 Bytes)
; Localização: core/boot/bootloader.asm
; ==========================================
BITS 16
ORG 0x7C00

start16:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; 1. Configura modo de vídeo VGA Texto 80x25
    mov ax, 0x0003
    int 0x10

    ; 2. Lê o Kernel via LBA Estendido (AH = 0x42) usando a pilha com BP
    sub sp, 16
    mov bp, sp
    mov word [bp], 0x0010       ; Tamanho do pacote (16 bytes) + Reservado (0)
    mov word [bp+2], 64         ; Número de setores a ler (64 setores = 32 KB)
    mov word [bp+4], 0x8000     ; Offset de destino na RAM
    mov word [bp+6], 0x0000     ; Segmento de destino (0)
    mov dword [bp+8], 1         ; Setor LBA inicial (Setor 1, logo após o MBR)
    mov dword [bp+12], 0        ; Parte alta do LBA

    mov si, bp                  ; SI aponta para o pacote na pilha
    mov ah, 0x42                ; Função de leitura estendida LBA
    mov dl, 0x80                ; Unidade de disco 0x80
    int 0x13
    
    add sp, 16                  ; Limpa a pilha
    jc disk_error               ; Se der erro, exibe 'E'

    ; 3. Ativa a linha A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; 4. Entra em Modo Protegido (32 bits)
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:start32

disk_error:
    ; Se falhar a leitura do disco, escreve 'E' em verde neon na tela
    mov ax, 0xb800
    mov es, ax
    mov byte [es:0], 'E'
    mov byte [es:1], 0x0A
    cli
    hlt

BITS 32
start32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; 5. Limpa e configura Paginação de 64 bits (PML4, PDPT, PD)
    mov edi, 0x1000         ; Endereço base da tabela PML4
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096 / 4
    rep stosd

    ; Configura entradas das tabelas de paginação (Identity Map dos primeiros 2MB)
    mov dword [0x1000], 0x2003          ; PML4[0] -> PDPT (Present + Writable)
    mov dword [0x2000], 0x3003          ; PDPT[0] -> PD (Present + Writable)
    mov dword [0x3000], 0x00000083      ; PD[0] -> 2MB Huge Page (Present + Writable + Page Size)

    ; 6. Ativa PAE (Physical Address Extension) em CR4
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; 7. Ativa Long Mode no MSR EFER (IA32_EFER)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; 8. Ativa Paginação (bit PG em CR0)
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; 9. Carrega GDT de 64 bits e faz o salto longo para o kernel em 0x8000
    lgdt [gdt64_descriptor]
    jmp 0x18:0x8000

; --- Tabela Global de Descritores (GDT) ---
align 8
gdt_start:
    dq 0x0000000000000000 ; 0x00: Descritor Nulo
    dq 0x00CF9A000000FFFF ; 0x08: Código 32-bit (base 0, limite 4GB, executável/leitura)
    dq 0x00CF92000000FFFF ; 0x10: Dados 32-bit (base 0, limite 4GB, leitura/escrita)
    dq 0x00AF9A0000000000 ; 0x18: Código 64-bit Long Mode (L=1, P=1, D/C=0)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

gdt64_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xAA55
