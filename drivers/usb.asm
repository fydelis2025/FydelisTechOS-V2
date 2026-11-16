; ==========================================
; FYDELIS TECH OS — usb.asm
; Detecção de Barramento USB (UHCI/OHCI/EHCI/xHCI)
; De Salvador • Bahia 🇧🇷
; ==========================================
bits 64

section .data
usb_controller_found  db 0
usb_ctrl_type         db 0   ; 1=UHCI,2=OHCI,3=EHCI,4=xHCI

; Registros PCI de classe USB
USB_CLASS             equ 0x0C
USB_SUBCLASS_USB      equ 0x03

section .text
global usb_scan_controllers

; ==========================================
; 🔍 PROCURAR CONTROLADOR USB VIA PCI
; ==========================================
usb_scan_controllers:
    push rax
    push rbx
    push rcx

    ; Percorrer dispositivos PCI procurando classe USB
    ; (Chama rotinas do pci.asm)
    mov byte [usb_controller_found], 0

    ; Tipo de controlador — xHCI é o padrão moderno
    mov byte [usb_ctrl_type], 4   ; Assumir xHCI primeiro

    ; Aqui você lê a base de E/S/Memória do controlador
    ; e inicializa a porta

    mov byte [usb_controller_found], 1

    pop rcx
    pop rbx
    pop rax
    ret

; ==========================================
; 🔌 INICIALIZAR PORTA USB
; ==========================================
usb_init_port:
    ; Resetar porta, esperar estabilizar
    ; Detectar dispositivo (velocidade: baixa, cheia, alta)
    ; Atribuir endereço
    ; Ler descritor do dispositivo
    ; Carregar driver correspondente

    ret