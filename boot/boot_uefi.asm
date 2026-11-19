; ============================================================================
; BOOT_UEFI.ASM — EFI_APPLICATION x86_64 Completo em NASM (Sem EDK2/GNU-EFI)
; 1. Detecta SecureBoot e SetupMode (EFI_GLOBAL_VARIABLE)
; 2. Captura Framebuffer linear via EFI_GRAPHICS_OUTPUT_PROTOCOL (GOP)
; 3. Le 256 KB do kernel.bin no LBA 4096 via EFI_BLOCK_IO_PROTOCOL -> 0x8000
; 4. Executa GetMemoryMap + ExitBootServices e salta para 0x8000 (RDI=0x5000)
; FydelisTech OS v4.2 · Salvador - Bahia
; Compilar: nasm -f bin boot_uefi.asm -o BOOTX64.EFI
; ============================================================================
BITS 64
ORG 0x100000

BOOTINFO_ADDR       equ 0x5000
KERNEL_LOAD_ADDR    equ 0x8000
KERNEL_START_LBA    equ 4096
KERNEL_READ_BYTES   equ 262144      ; 256 KB (512 setores de 512B)

; ============================================================================
; CABECALHO PE32+ (UEFI x86_64 EXECUTABLE)
; ============================================================================
dos_header:
    dw 0x5A4D                       ; "MZ"
    times 58 db 0
    dd pe_header - dos_header       ; e_lfanew

pe_header:
    dd 0x00004550                   ; "PE\0\0"
    dw 0x8664                       ; Machine: AMD64 / x86_64
    dw 2                            ; NumberOfSections (.text, .data)
    dd 0
    dd 0
    dd 0
    dw optional_header_end - optional_header
    dw 0x0206                       ; EXECUTABLE_IMAGE | DEBUG_STRIPPED

optional_header:
    dw 0x020B                       ; Magic: PE32+ (64-bit)
    db 1, 0
    dd text_end - text_start        ; SizeOfCode
    dd data_end - data_start        ; SizeOfInitializedData
    dd 0
    dd efi_main - dos_header        ; AddressOfEntryPoint
    dd text_start - dos_header      ; BaseOfCode
    dq 0x100000                     ; ImageBase
    dd 0x1000                       ; SectionAlignment
    dd 0x200                        ; FileAlignment
    dw 0, 0, 0, 0, 0, 0
    dd 0
    dd image_end - dos_header       ; SizeOfImage
    dd headers_end - dos_header     ; SizeOfHeaders
    dd 0
    dw 10                           ; Subsystem: EFI_APPLICATION (10)
    dw 0
    dq 0x100000, 0x10000
    dq 0x100000, 0x10000
    dd 0
    dd 16
    times 16 dq 0
optional_header_end:

section_table:
    ; .text
    db '.text', 0, 0, 0
    dd text_end - text_start
    dd text_start - dos_header
    dd text_end - text_start
    dd text_start - dos_header
    dd 0, 0
    dw 0, 0
    dd 0x60000020                   ; CODE | EXECUTE | READ

    ; .data
    db '.data', 0, 0, 0
    dd data_end - data_start
    dd data_start - dos_header
    dd data_end - data_start
    dd data_start - dos_header
    dd 0, 0
    dw 0, 0
    dd 0xC0000040                   ; INITIALIZED_DATA | READ | WRITE

    align 0x200, db 0
headers_end:

; ============================================================================
; CODIGO UEFI (.text) — Microsoft x64 ABI (RCX, RDX, R8, R9 + 32B Shadow Space)
; ============================================================================
text_start:
efi_main:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 128

    mov     [rel efi_image_handle], rcx
    mov     [rel efi_system_table], rdx

    ; Ponteiros principais da EFI_SYSTEM_TABLE
    mov     rax, [rdx + 64]         ; ConOut
    mov     [rel efi_con_out], rax
    mov     rax, [rdx + 88]         ; RuntimeServices
    mov     [rel efi_runtime_srv], rax
    mov     rax, [rdx + 96]         ; BootServices
    mov     [rel efi_boot_srv], rax

    ; Zera estrutura BootInfo em 0x5000 (64 bytes)
    mov     rdi, BOOTINFO_ADDR
    xor     eax, eax
    mov     ecx, 16
.zera_bi:
    mov     [rdi], eax
    add     rdi, 4
    loop    .zera_bi

    ; Preenche cabecalho BootInfo
    mov     rdi, BOOTINFO_ADDR
    mov     dword [rdi + 0], 0x46594442 ; Magic "FYDB"
    mov     dword [rdi + 4], 2          ; boot_mode = BOOT_MODE_UEFI (2)

    lea     rdx, [rel ustr_banner]
    call    uefi_print

    ; ========================================================================
    ; ETAPA 1: DETECTAR SECURE BOOT & SETUP MODE
    ; ========================================================================
    mov     qword [rel var_data_size], 1
    mov     byte  [rel var_secure_val], 0

    mov     rbx, [rel efi_runtime_srv]
    lea     rcx, [rel ustr_secure_boot]
    lea     rdx, [rel guid_global_var]
    xor     r8, r8
    lea     r9, [rel var_data_size]
    lea     rax, [rel var_secure_val]
    mov     [rsp + 32], rax
    call    [rbx + 72]              ; RuntimeServices->GetVariable

    test    rax, rax
    jnz     .sb_off
    cmp     byte [rel var_secure_val], 1
    jne     .sb_off

    mov     rdi, BOOTINFO_ADDR
    mov     dword [rdi + 8], 1      ; secure_boot = 1
    lea     rdx, [rel ustr_sb_on]
    call    uefi_print
    jmp     .check_setup

.sb_off:
    mov     rdi, BOOTINFO_ADDR
    mov     dword [rdi + 8], 0      ; secure_boot = 0
    lea     rdx, [rel ustr_sb_off]
    call    uefi_print

.check_setup:
    mov     qword [rel var_data_size], 1
    mov     byte  [rel var_setup_val], 0

    mov     rbx, [rel efi_runtime_srv]
    lea     rcx, [rel ustr_setup_mode]
    lea     rdx, [rel guid_global_var]
    xor     r8, r8
    lea     r9, [rel var_data_size]
    lea     rax, [rel var_setup_val]
    mov     [rsp + 32], rax
    call    [rbx + 72]

    test    rax, rax
    jnz     .etapa_gop
    movzx   eax, byte [rel var_setup_val]
    mov     rdi, BOOTINFO_ADDR
    mov     [rdi + 12], eax         ; setup_mode

    ; ========================================================================
    ; ETAPA 2: CAPTURAR FRAMEBUFFER LINEAR VIA UEFI GOP
    ; BootServices->LocateProtocol(&GOP_GUID, NULL, &gop_proto) -> offset 320
    ; ========================================================================
.etapa_gop:
    mov     rbx, [rel efi_boot_srv]
    lea     rcx, [rel guid_gop]
    xor     rdx, rdx
    lea     r8, [rel gop_proto]
    call    [rbx + 320]             ; BootServices->LocateProtocol
    test    rax, rax
    jnz     .erro_gop

    ; gop_proto->Mode (offset 24)
    mov     rsi, [rel gop_proto]
    mov     rsi, [rsi + 24]         ; EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *Mode
    mov     rdx, [rsi + 8]          ; EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *Info

    mov     rdi, BOOTINFO_ADDR
    mov     rax, [rsi + 24]         ; Mode->FrameBufferBase
    mov     [rdi + 16], rax         ; BootInfo.fb_addr (offset 16)

    mov     eax, [rdx + 4]          ; Info->HorizontalResolution
    mov     [rdi + 24], eax         ; BootInfo.fb_width (offset 24)

    mov     eax, [rdx + 8]          ; Info->VerticalResolution
    mov     [rdi + 28], eax         ; BootInfo.fb_height (offset 28)

    mov     eax, [rdx + 32]         ; Info->PixelsPerScanLine
    shl     eax, 2                  ; * 4 bytes por pixel (32 bpp)
    mov     [rdi + 32], eax         ; BootInfo.fb_pitch (offset 32)
    mov     dword [rdi + 36], 32    ; BootInfo.fb_bpp (offset 36)

    lea     rdx, [rel ustr_gop_ok]
    call    uefi_print

    ; ========================================================================
    ; ETAPA 3: LER KERNEL.BIN DO DISCO (LBA 4096, 256 KB -> 0x8000)
    ; BootServices->LocateHandleBuffer(ByProtocol=2, &BLOCK_IO_GUID, NULL, &Count, &Buffer)
    ; Offset LocateHandleBuffer em EFI_BOOT_SERVICES = 312
    ; ========================================================================
    mov     rbx, [rel efi_boot_srv]
    mov     rcx, 2                  ; ByProtocol
    lea     rdx, [rel guid_block_io]
    xor     r8, r8
    lea     r9, [rel blk_handle_cnt]
    lea     rax, [rel blk_handle_buf]
    mov     [rsp + 32], rax
    call    [rbx + 312]             ; BootServices->LocateHandleBuffer
    test    rax, rax
    jnz     .erro_disco

    xor     r12, r12                ; indice do handle atual
.loop_handles:
    cmp     r12, [rel blk_handle_cnt]
    jae     .erro_disco

    ; HandleProtocol(Handle, &BLOCK_IO_GUID, &blk_proto) -> offset 152
    mov     rsi, [rel blk_handle_buf]
    mov     rcx, [rsi + r12 * 8]
    lea     rdx, [rel guid_block_io]
    lea     r8, [rel blk_proto]
    mov     rbx, [rel efi_boot_srv]
    call    [rbx + 152]             ; BootServices->HandleProtocol
    test    rax, rax
    jnz     .prox_handle

    ; Verifica EFI_BLOCK_IO_MEDIA (offset 8 em EFI_BLOCK_IO_PROTOCOL)
    mov     rsi, [rel blk_proto]
    mov     rdx, [rsi + 8]          ; EFI_BLOCK_IO_MEDIA *Media

    ; Media->MediaPresent (offset 8, BOOLEAN) == 1?
    cmp     byte [rdx + 8], 1
    jne     .prox_handle

    ; Media->LogicalPartition (offset 10, BOOLEAN) == 0? (Queremos o disco fisico bruto!)
    cmp     byte [rdx + 10], 0
    jne     .prox_handle

    ; Media->LastBlock (offset 24, UINT64) >= 4608?
    cmp     qword [rdx + 24], KERNEL_START_LBA + 512
    jb      .prox_handle

    ; Tenta ler 256 KB do LBA 4096 diretamente para 0x8000
    ; BlockIo->ReadBlocks(This, MediaId, LBA, BufferSize, Buffer) -> offset 24
    mov     rcx, rsi                ; Arg1 (RCX): This (EFI_BLOCK_IO_PROTOCOL*)
    mov     edx, [rdx + 0]          ; Arg2 (EDX): Media->MediaId
    mov     r8, KERNEL_START_LBA    ; Arg3 (R8):  LBA = 4096
    mov     r9, KERNEL_READ_BYTES   ; Arg4 (R9):  BufferSize = 262144
    mov     qword [rsp + 32], KERNEL_LOAD_ADDR ; Arg5 (Stack): Buffer = 0x8000
    call    [rsi + 24]              ; BlockIo->ReadBlocks

    test    rax, rax                ; EFI_SUCCESS == 0?
    jz      .kernel_carregado

.prox_handle:
    inc     r12
    jmp     .loop_handles

.kernel_carregado:
    lea     rdx, [rel ustr_kern_ok]
    call    uefi_print

    ; ========================================================================
    ; ETAPA 4: GETMEMORYMAP + EXITBOOTSERVICES + SALTO PARA KERNEL (0x8000)
    ; ========================================================================
    mov     qword [rel mmap_size], 16384
    mov     rbx, [rel efi_boot_srv]
    lea     rcx, [rel mmap_size]
    lea     rdx, [rel mmap_buffer]
    lea     r8, [rel mmap_key]
    lea     r9, [rel mmap_desc_size]
    lea     rax, [rel mmap_desc_ver]
    mov     [rsp + 32], rax
    call    [rbx + 56]              ; BootServices->GetMemoryMap

    ; Salva ponteiro e contagem no BootInfo
    mov     rdi, BOOTINFO_ADDR
    lea     rax, [rel mmap_buffer]
    mov     [rdi + 48], rax         ; BootInfo.mmap_addr

    ; ExitBootServices(ImageHandle, MapKey) -> offset 232
    mov     rbx, [rel efi_boot_srv]
    mov     rcx, [rel efi_image_handle]
    mov     rdx, [rel mmap_key]
    call    [rbx + 232]             ; BootServices->ExitBootServices
    test    rax, rax
    jz      .entrar_kernel

    ; Segunda tentativa caso GetMemoryMap tenha mudado durante a chamada
    mov     qword [rel mmap_size], 16384
    mov     rbx, [rel efi_boot_srv]
    lea     rcx, [rel mmap_size]
    lea     rdx, [rel mmap_buffer]
    lea     r8, [rel mmap_key]
    lea     r9, [rel mmap_desc_size]
    lea     rax, [rel mmap_desc_ver]
    mov     [rsp + 32], rax
    call    [rbx + 56]

    mov     rbx, [rel efi_boot_srv]
    mov     rcx, [rel efi_image_handle]
    mov     rdx, [rel mmap_key]
    call    [rbx + 232]

.entrar_kernel:
    cli
    mov     rdi, BOOTINFO_ADDR      ; ABI System V: 1o argumento = BootInfo*
    mov     rax, KERNEL_LOAD_ADDR   ; Ponto de entrada do kernel em 0x8000
    jmp     rax

.erro_gop:
    lea     rdx, [rel ustr_err_gop]
    call    uefi_print
    jmp     .halt

.erro_disco:
    lea     rdx, [rel ustr_err_disk]
    call    uefi_print

.halt:
    cli
    hlt
    jmp     .halt

; Auxiliar: RDX = ponteiro string UTF-16LE
uefi_print:
    push    rcx
    sub     rsp, 32
    mov     rcx, [rel efi_con_out]
    call    [rcx + 8]
    add     rsp, 32
    pop     rcx
    ret

    align 0x200, db 0
text_end:

; ============================================================================
; DADOS UEFI (.data) — GUIDs, BUFFERS & STRINGS UTF-16LE
; ============================================================================
data_start:
efi_image_handle: dq 0
efi_system_table: dq 0
efi_con_out:      dq 0
efi_runtime_srv:  dq 0
efi_boot_srv:     dq 0

var_data_size:    dq 1
var_secure_val:   db 0
var_setup_val:    db 0

align 8
gop_proto:        dq 0
blk_handle_cnt:   dq 0
blk_handle_buf:   dq 0
blk_proto:        dq 0

mmap_size:        dq 16384
mmap_key:         dq 0
mmap_desc_size:   dq 0
mmap_desc_ver:    dd 0

; GUIDs oficiais da especificacao UEFI 2.x
align 8
; EFI_GLOBAL_VARIABLE = {8BE4DF61-93CA-11D2-AA0D-00E098032B8C}
guid_global_var:
    dd 0x8BE4DF61
    dw 0x93CA, 0x11D2
    db 0xAA, 0x0D, 0x00, 0xE0, 0x98, 0x03, 0x2B, 0x8C

; EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID = {9042A9DE-23DC-4A38-96FB-7ADED080516A}
guid_gop:
    dd 0x9042A9DE
    dw 0x23DC, 0x4A38
    db 0x96, 0xFB, 0x7A, 0xDE, 0xD0, 0x80, 0x51, 0x6A

; EFI_BLOCK_IO_PROTOCOL_GUID = {964E5B21-6459-11D2-8E39-00A0C969723B}
guid_block_io:
    dd 0x964E5B21
    dw 0x6459, 0x11D2
    db 0x8E, 0x39, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B

; Strings UTF-16LE
ustr_secure_boot: dw 'S','e','c','u','r','e','B','o','o','t', 0
ustr_setup_mode:  dw 'S','e','t','u','p','M','o','d','e', 0
ustr_banner:      dw 'F','y','d','e','l','i','s','T','e','c','h',' ','O','S',' ','[','U','E','F','I',' ','x','6','4',']', 13, 10, 0
ustr_sb_on:       dw '[','O','K',']',' ','S','e','c','u','r','e',' ','B','o','o','t',':',' ','H','A','B','I','L','I','T','A','D','O', 13, 10, 0
ustr_sb_off:      dw '[','!',']',' ','S','e','c','u','r','e',' ','B','o','o','t',':',' ','D','E','S','A','B','I','L','I','T','A','D','O', 13, 10, 0
ustr_gop_ok:      dw '[','O','K',']',' ','U','E','F','I',' ','G','O','P',' ','F','r','a','m','e','b','u','f','f','e','r',' ','c','a','p','t','u','r','a','d','o', 13, 10, 0
ustr_kern_ok:     dw '[','O','K',']',' ','K','e','r','n','e','l',' ','c','a','r','r','e','g','a','d','o',' ','d','o',' ','L','B','A',' ','4','0','9','6', 13, 10, 0
ustr_err_gop:     dw '[','E','R','R',']',' ','F','a','l','h','a',' ','a','o',' ','o','b','t','e','r',' ','G','O','P', 13, 10, 0
ustr_err_disk:    dw '[','E','R','R',']',' ','F','a','l','h','a',' ','a','o',' ','l','e','r',' ','L','B','A',' ','4','0','9','6', 13, 10, 0

align 16
mmap_buffer:      times 16384 db 0

    align 0x200, db 0
data_end:
image_end:
