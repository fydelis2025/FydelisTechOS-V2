; ==========================================
; FYDELIS TECH OS — PCI.asm
; Detecção Automática de Hardware
; De Salvador • Bahia 🇧🇷
; ==========================================
bits 64

section .data
pci_bus_count       db 0
pci_device_count    dq 0
pci_header_buf      times 256 db 0   ; Buffer para ler cabeçalho

; Portas de E/S do PCI
PCI_CONFIG_ADDR     equ 0xCF8
PCI_CONFIG_DATA     equ 0xCFC

section .text
global pci_init
global pci_enumerate_all
global pci_read_device_name

; ==========================================
; 🔧 INICIALIZAR — Limpa contadores
; ==========================================
pci_init:
    xor eax, eax
    mov [pci_bus_count], al
    mov [pci_device_count], rax
    ret

; ==========================================
; 🔍 LER REGISTRO DE CONFIGURAÇÃO
; Entrada: ebx = endereço (bus:dev:fun), ecx = registro
; Saída: eax = valor lido
; ==========================================
pci_read_config:
    push rdx
    mov eax, 0x80000000             ; Bit 31 = habilitar
    or eax, ebx                     ; Endereço Bus:Dev:Fun
    or eax, ecx                     ; Registro (0-252)
    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx
    pop rdx
    ret

; ==========================================
; 🔍 ESCREVER REGISTRO DE CONFIGURAÇÃO
; ==========================================
pci_write_config:
    push rdx
    mov eax, 0x80000000
    or eax, ebx
    or eax, ecx
    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    mov eax, edx
    mov dx, PCI_CONFIG_DATA
    out dx, eax
    pop rdx
    ret

; ==========================================
; 🔍 VARRER TODOS OS DISPOSITIVOS
; Percorre: 256 barramentos × 32 dispositivos × 8 funções
; ==========================================
pci_enumerate_all:
    push rbx
    push rcx
    push rdx

    mov byte [pci_bus_count], 0
    mov qword [pci_device_count], 0

bus_loop:
    xor edi, edi        ; Dispositivo = 0..31
dev_loop:
    xor esi, esi        ; Função = 0..7
fun_loop:
    ; Montar endereço: Bus(16b) << 8 | Dev(5b) << 3 | Fun(3b)
    mov ebx, [pci_bus_count]
    shl ebx, 16
    mov ax, di
    shl eax, 11
    or ebx, eax
    mov eax, esi
    shl eax, 8
    or ebx, eax

    ; Ler Vendor ID + Device ID (registro 0x00)
    mov ecx, 0x00
    call pci_read_config
    cmp ax, 0xFFFF      ; Se 0xFFFF = dispositivo ausente
    je skip_device

    ; ✅ Dispositivo encontrado!
    inc qword [pci_device_count]

    ; Salvar dados do dispositivo
    mov ecx, 0x00
    call pci_read_config
    mov edx, eax        ; edx = Vendor(16b) | Device(16b)

    ; Ler Classe/Subclasse (registro 0x08)
    mov ecx, 0x08
    call pci_read_config
    shr eax, 24         ; Classe principal
    mov r8d, eax
    shr eax, 8
    mov r9d, eax        ; Subclasse

    ; Aqui você chama o driver correspondente
    ; r8 = Classe, r9 = Subclasse, dx = Vendor, dx+2 = Device
    call pci_match_driver

skip_device:
    inc esi
    cmp esi, 8
    jl fun_loop

    inc edi
    cmp edi, 32
    jl dev_loop

    inc byte [pci_bus_count]
    cmp byte [pci_bus_count], 255
    jbe bus_loop

    pop rdx
    pop rcx
    pop rbx
    ret

; ==========================================
; 🔍 ASSOCIAR DISPOSITIVO AO DRIVER
; Tabela de classes padrão PCI
; ==========================================
pci_match_driver:
    push rax
    push rbx

    cmp r8d, 0x01       ; Controlador de Massa (Disco)
    je .disk
    cmp r8d, 0x02       ; Controlador de Rede
    je .network
    cmp r8d, 0x03       ; Controlador de Vídeo
    je .video
    cmp r8d, 0x04       ; Dispositivo de Áudio
    je .audio
    cmp r8d, 0x06       ; Ponte (PCI-PCI, etc)
    je .bridge
    jmp .unknown

.disk:
    ; Aqui inicializa driver de disco
    jmp .done
.network:
    ; Aqui inicializa driver de rede
    jmp .done
.video:
    ; Aqui inicializa driver de vídeo
    jmp .done
.audio:
    ; Aqui inicializa driver de áudio
    jmp .done
.bridge:
    ; Ponte = pode ter mais dispositivos, não ignorar
    jmp .done
.unknown:
    ; Dispositivo sem driver conhecido — registrar e ignorar
.done:
    pop rbx
    pop rax
    ret

; ==========================================
; 📊 RETORNAR CONTAGEM DE DISPOSITIVOS
; ==========================================
pci_get_device_count:
    mov rax, [pci_device_count]
    ret
