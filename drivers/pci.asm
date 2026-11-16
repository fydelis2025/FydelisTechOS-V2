; ==========================================
; DRIVER PCI — FydelisTech OS
; ==========================================
BITS 64
%define BUILDING_PCI_DRIVER

%include "fydelterm.inc"

global pci_ler_dispositivo
global pci_ler_classe
global pci_ler_bar0

section .text

; ==========================================
; Lê configuração PCI básica
; Entrada: RCX = Índice/Dispositivo (0 a 255)
; Retorna: RAX = Vendor/Device ID (ou 0xFFFFFFFF se vazio)
; ==========================================
pci_ler_dispositivo:
    push    rdx
    push    rbx

    ; Monta endereço CONFIG_ADDRESS (Bus 0, Device = RCX, Function 0, Offset 0)
    mov     rax, rcx
    shl     rax, 16
    or      eax, 0x80000000   ; Bit 32 habilitado (Enable bit)
    
    mov     dx, PCI_CONFIG_ADDR
    out     dx, eax

    mov     dx, PCI_CONFIG_DATA
    in      eax, dx

    pop     rbx
    pop     rdx
    ret

; ==========================================
; Lê a classe do dispositivo PCI atual
; Entrada: RCX = Índice do dispositivo
; Retorna: EAX = Classe e Subclasse
; ==========================================
pci_ler_classe:
    push    rdx

    mov     rax, rcx
    shl     rax, 16
    or      eax, 0x80000008   ; Offset 0x08 = Revision ID / Class Code
    
    mov     dx, PCI_CONFIG_ADDR
    out     dx, eax

    mov     dx, PCI_CONFIG_DATA
    in      eax, dx

    pop     rdx
    ret

; ==========================================
; Lê o BAR0 (Base Address Register)
; Entrada: RCX = Índice do dispositivo
; Retorna: RAX = Endereço base de MMIO
; ==========================================
pci_ler_bar0:
    push    rdx

    mov     rax, rcx
    shl     rax, 16
    or      eax, 0x80000010   ; Offset 0x10 = BAR0
    
    mov     dx, PCI_CONFIG_ADDR
    out     dx, eax

    mov     dx, PCI_CONFIG_DATA
    in      eax, dx

    ; Limpa os bits de flags do BAR (I/O vs Memory)
    and     eax, 0xFFFFFFF0
    mov     rax, rax

    pop     rdx
    ret
