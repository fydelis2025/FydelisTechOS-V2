; ============================================================================
; BOOT_UEFI.ASM — EFI_APPLICATION x86_64 Puro em NASM (Sem EDK2/GNU-EFI)
; Detecta UEFI + Estado Real do Secure Boot (EFI_GLOBAL_VARIABLE "SecureBoot")
; Compilar: nasm -f bin boot_uefi.asm -o BOOTX64.EFI
; ============================================================================
BITS 64
ORG 0x100000

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
    dd 0                            ; TimeDateStamp
    dd 0                            ; PointerToSymbolTable
    dd 0                            ; NumberOfSymbols
    dw optional_header_end - optional_header
    dw 0x0206                       ; Characteristics: EXECUTABLE_IMAGE | DEBUG_STRIPPED

optional_header:
    dw 0x020B                       ; Magic: PE32+ (64-bit)
    db 1, 0                         ; Linker version
    dd text_end - text_start        ; SizeOfCode
    dd data_end - data_start        ; SizeOfInitializedData
    dd 0                            ; SizeOfUninitializedData
    dd efi_main - dos_header        ; AddressOfEntryPoint
    dd text_start - dos_header      ; BaseOfCode
    dq 0x100000                     ; ImageBase
    dd 0x1000                       ; SectionAlignment
    dd 0x200                        ; FileAlignment
    dw 0, 0, 0, 0, 0, 0
    dd 0                            ; Win32VersionValue
    dd image_end - dos_header       ; SizeOfImage
    dd headers_end - dos_header     ; SizeOfHeaders
    dd 0                            ; CheckSum
    dw 10                           ; Subsystem: EFI_APPLICATION (10)
    dw 0                            ; DllCharacteristics
    dq 0x100000, 0x10000            ; StackReserve, StackCommit
    dq 0x100000, 0x10000            ; HeapReserve, HeapCommit
    dd 0                            ; LoaderFlags
    dd 16                           ; NumberOfRvaAndSizes
    times 16 dq 0                   ; DataDirectories
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
; CODIGO UEFI (.text)
; Entrada UEFI ABI (Microsoft x64):
;   RCX = EFI_HANDLE ImageHandle
;   RDX = EFI_SYSTEM_TABLE *SystemTable
; ============================================================================
text_start:
efi_main:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 96                 ; shadow space (32B) + argumentos pilha + locais

    mov     [rel efi_image_handle], rcx
    mov     [rel efi_system_table], rdx

    ; Obtem ConOut (offset 64 em EFI_SYSTEM_TABLE) e RuntimeServices (offset 88)
    mov     rax, [rdx + 64]
    mov     [rel efi_con_out], rax
    mov     rbx, [rdx + 88]
    mov     [rel efi_runtime_srv], rbx
    mov     rax, [rdx + 96]
    mov     [rel efi_boot_srv], rax

    ; Preenche BootInfo base em 0x5000
    mov     rdi, 0x5000
    mov     dword [rdi + 0], 0x46594442 ; Magic "FYDB"
    mov     dword [rdi + 4], 2          ; boot_mode = BOOT_MODE_UEFI
    mov     dword [rdi + 8], 0          ; secure_boot = 0 (padrao)
    mov     dword [rdi + 12], 0         ; setup_mode = 0

    ; Imprime banner inicial UEFI
    lea     rdx, [rel ustr_banner]
    call    uefi_print

    ; ------------------------------------------------------------------------
    ; CONSULTA VARIAVEL UEFI "SecureBoot" (EFI_GLOBAL_VARIABLE)
    ; GetVariable(VariableName, VendorGuid, Attributes, DataSize, Data)
    ; Offset em EFI_RUNTIME_SERVICES = 72
    ; ------------------------------------------------------------------------
    mov     qword [rel var_data_size], 1
    mov     byte  [rel var_secure_val], 0

    mov     rbx, [rel efi_runtime_srv]
    lea     rcx, [rel ustr_secure_boot] ; Arg1 (RCX): L"SecureBoot"
    lea     rdx, [rel guid_global_var]  ; Arg2 (RDX): EFI_GLOBAL_VARIABLE
    xor     r8, r8                      ; Arg3 (R8):  Attributes = NULL
    lea     r9, [rel var_data_size]     ; Arg4 (R9):  &DataSize (1 byte)
    lea     rax, [rel var_secure_val]
    mov     [rsp + 32], rax             ; Arg5 (Stack): &Data
    call    [rbx + 72]                  ; RuntimeServices->GetVariable

    test    rax, rax                    ; EFI_SUCCESS == 0?
    jnz     .sb_desabilitado

    cmp     byte [rel var_secure_val], 1
    jne     .sb_desabilitado

    ; Secure Boot ATIVO!
    mov     rdi, 0x5000
    mov     dword [rdi + 8], 1          ; BootInfo.secure_boot = 1
    lea     rdx, [rel ustr_sb_on]
    call    uefi_print
    jmp     .verificar_setup_mode

.sb_desabilitado:
    mov     rdi, 0x5000
    mov     dword [rdi + 8], 0          ; BootInfo.secure_boot = 0
    lea     rdx, [rel ustr_sb_off]
    call    uefi_print

.verificar_setup_mode:
    ; Consulta tambem "SetupMode" para saber se chaves PK estao instaladas
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
    jnz     .seguir_boot
    movzx   eax, byte [rel var_setup_val]
    mov     rdi, 0x5000
    mov     [rdi + 12], eax             ; BootInfo.setup_mode

.seguir_boot:
    ; Aqui segue: LocateProtocol(GOP) -> preencher fb_addr -> ExitBootServices -> jmp kernel_main
    lea     rdx, [rel ustr_pronto]
    call    uefi_print

    xor     eax, eax                    ; EFI_SUCCESS
    mov     rsp, rbp
    pop     rbp
    ret

; Auxiliar: RDX = ponteiro string UTF-16LE
uefi_print:
    push    rcx
    sub     rsp, 32
    mov     rcx, [rel efi_con_out]
    call    [rcx + 8]                   ; ConOut->OutputString(ConOut, String)
    add     rsp, 32
    pop     rcx
    ret

    align 0x200, db 0
text_end:

; ============================================================================
; DADOS UEFI (.data) — GUIDs & STRINGS UTF-16LE
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

; EFI_GLOBAL_VARIABLE = {8BE4DF61-93CA-11D2-AA0D-00E098032B8C}
align 8
guid_global_var:
    dd 0x8BE4DF61
    dw 0x93CA
    dw 0x11D2
    db 0xAA, 0x0D, 0x00, 0xE0, 0x98, 0x03, 0x2B, 0x8C

; Strings UTF-16LE (cada caractere seguido de 0x00)
ustr_secure_boot: dw 'S','e','c','u','r','e','B','o','o','t', 0
ustr_setup_mode:  dw 'S','e','t','u','p','M','o','d','e', 0
ustr_banner:      dw 'F','y','d','e','l','i','s','T','e','c','h',' ','O','S',' ','[','U','E','F','I',' ','x','6','4',']', 13, 10, 0
ustr_sb_on:       dw '[','O','K',']',' ','S','e','c','u','r','e',' ','B','o','o','t',':',' ','H','A','B','I','L','I','T','A','D','O', 13, 10, 0
ustr_sb_off:      dw '[','!','}',']',' ','S','e','c','u','r','e',' ','B','o','o','t',':',' ','D','E','S','A','B','I','L','I','T','A','D','O', 13, 10, 0
ustr_pronto:      dw 'T','r','a','n','s','f','e','r','i','n','d','o',' ','B','o','o','t','I','n','f','o',' ','p','a','r','a',' ','K','e','r','n','e','l','.','.','.', 13, 10, 0

    align 0x200, db 0
data_end:
image_end:
