; ==========================================
; DRIVER BLUETOOTH NATIVO — FYDELIS TECH OS
; De Salvador • Bahia 🇧🇷
; Fala direto com o hardware — SEM Windows/Linux
; ==========================================
BITS 64
%include "../include/fydelterm.inc"

; --- Exporta para o sistema ---
global bt_detectar_placa
global bt_inicializar
global sys_bt_scan
global sys_bt_conectar
global sys_bt_desconectar
global sys_bt_enviar_dados
global sys_bt_receber_dados

; --- Registros do Controlador HCI ---
; Faixa padrão adaptável conforme chip detectado
BT_BASE_UNKNOWN  equ 0x00000000

; Registros HCI via I/O ou MMIO
HCI_CMD          equ 0x00   ; Registro de Comando
HCI_DATA_TX      equ 0x04   ; Buffer de Transmissão
HCI_DATA_RX      equ 0x08   ; Buffer de Recepção
HCI_STATUS       equ 0x0C   ; Status do controlador
  HCI_OCUPADO    equ 1 << 0
  HCI_PRONTO     equ 1 << 1
  HCI_CONECTADO  equ 1 << 2

; Comandos HCI padrão
HCI_RESET        equ 0x0C03
HCI_READ_BDADDR  equ 0x1009
HCI_SET_NAME     equ 0x0C13
HCI_INQUIRY      equ 0x0401
HCI_CREATE_CONN  equ 0x0405
HCI_DISCONNECT   equ 0x0406

; Limites
MAX_DISPOSITIVOS equ 16
NOME_TAMANHO     equ 24
BDADDR_TAMANHO    equ 6

; --- Estrutura: Dispositivo Bluetooth ---
struc BtDispositivo
    bdaddr:     resb BDADDR_TAMANHO   ; Endereço do dispositivo
    nome:       resb NOME_TAMANHO + 1 ; Nome amigável
    classe:     resd 1                ; Classe do dispositivo
    sinal:      resb 1                ; Força do sinal (0-100%)
    conectado:  resb 1                ; 1 = conectado
    proximo:    resq 1                ; Próximo da lista
endstruc

section .bss
align 16
bt_base:           resq 1        ; Endereço base do controlador
bt_placa_ok:       resb 1        ; 1 = placa detectada
bt_inicializada:   resb 1        ; 1 = driver pronto
bt_conectado:      resb 1        ; 1 = conectado a um dispositivo
bt_nome_local:     resb NOME_TAMANHO + 1
bt_lista_dispositivos: resb (BtDispositivo_size * MAX_DISPOSITIVOS)
bt_contador:       resd 1

section .text

; ==========================================
; DETECTAR PLACA — Busca na barra PCI
; Retorna: rax = 1 se encontrou, 0 se não
; ==========================================
bt_detectar_placa:
    push    rcx
    push    rdx

    ; Percorre dispositivos PCI
    xor     rcx, rcx
.pci_proximo:
    ; Ler Vendor/Device ID
    call    pci_ler_dispositivo
    cmp     rax, 0xFFFFFFFF
    je      .proximo

    ; Verificar classe: 02 80 00 = Comunicação → Sem Fio → Bluetooth
    call    pci_ler_classe
    cmp     eax, 0x00800200
    je      .encontrada

    ; Também pode aparecer como classe genérica USB no controlador
    cmp     eax, 0x0C030000        ; USB Controller
    je      .verificar_usb_bt

.proximo:
    inc     rcx
    cmp     rcx, 256
    jl      .pci_proximo

    mov     byte [bt_placa_ok], 0
    xor     rax, rax
    jmp     .fim

.encontrada:
    ; Mapear BAR0
    call    pci_ler_bar0
    mov     [bt_base], rax
    mov     byte [bt_placa_ok], 1
    mov     rax, 1
    jmp     .fim

.verificar_usb_bt:
    ; Controladores Bluetooth via USB — verificação simplificada
    ; Em implementação completa: percorrer dispositivos USB
    mov     byte [bt_placa_ok], 0
    xor     rax, rax

.fim:
    pop     rdx
    pop     rcx
    ret

; ==========================================
; INICIALIZAR — Reset e configuração HCI
; ==========================================
bt_inicializar:
    cmp     byte [bt_placa_ok], 1
    jne     .sem_placa

    ; Enviar RESET ao controlador HCI
    mov     rax, [bt_base]
    mov     dword [rax + HCI_CMD], HCI_RESET
    call    bt_espera_pronto

    ; Definir nome do dispositivo local
    mov     rsi, nome_fydelis
    mov     rdi, bt_nome_local
    mov     rcx, NOME_TAMANHO
    rep     movsb
    mov     byte [rdi], 0

    ; Ler endereço BD_ADDR do controlador
    mov     rax, [bt_base]
    mov     dword [rax + HCI_CMD], HCI_READ_BDADDR
    call    bt_espera_pronto

    ; Pronto!
    mov     byte [bt_inicializada], 1
    mov     dword [bt_contador], 0
    mov     rax, 1
    ret

.sem_placa:
    xor     rax, rax
    ret

; ==========================================
; sys_bt_scan — Escanear dispositivos próximos
; Retorna: rax = ponteiro para lista BtDispositivo
; Chamado por: comando "bt scan" no terminal
; ==========================================
sys_bt_scan:
    cmp     byte [bt_inicializada], 1
    jne     .nao_pronto

    ; Limpar lista
    mov     dword [bt_contador], 0

    ; Enviar comando de investigação (inquiry)
    mov     rax, [bt_base]
    mov     dword [rax + HCI_CMD], HCI_INQUIRY
    call    bt_espera_pronto

    ; Parsear resultados recebidos
    call    bt_parse_resultados

    ; Retornar lista
    mov     rax, bt_lista_dispositivos
    ret

.nao_pronto:
    xor     rax, rax
    ret

; ==========================================
; sys_bt_conectar — Conectar a dispositivo
; Entrada: rdi = ponteiro para BD_ADDR (6 bytes)
; Retorna: rax = 1 sucesso, 0 falha
; ==========================================
sys_bt_conectar:
    push    rsi
    push    rdi

    cmp     byte [bt_inicializada], 1
    jne     .falha

    ; Copiar endereço de destino
    mov     rsi, rdi
    mov     rdi, bt_endereco_alvo
    mov     rcx, BDADDR_TAMANHO
    rep     movsb

    ; Enviar comando de conexão
    mov     rax, [bt_base]
    mov     dword [rax + HCI_CMD], HCI_CREATE_CONN
    call    bt_espera_pronto

    ; Verificar status
    mov     rax, [bt_base]
    mov     edx, [rax + HCI_STATUS]
    test    edx, HCI_CONECTADO
    jz      .falha

    mov     byte [bt_conectado], 1
    mov     rax, 1
    jmp     .fim

.falha:
    xor     rax, rax
.fim:
    pop     rdi
    pop     rsi
    ret

; ==========================================
; sys_bt_desconectar — Encerrar conexão
; ==========================================
sys_bt_desconectar:
    cmp     byte [bt_inicializada], 1
    jne     .nao_pronto

    mov     rax, [bt_base]
    mov     dword [rax + HCI_CMD], HCI_DISCONNECT
    call    bt_espera_pronto

    mov     byte [bt_conectado], 0
    mov     rax, 1
    ret

.nao_pronto:
    xor     rax, rax
    ret

; ==========================================
; sys_bt_enviar_dados — Transmitir dados
; Entrada: rsi=dados, rdx=tamanho
; ==========================================
sys_bt_enviar_dados:
    cmp     byte [bt_conectado], 1
    jne     .nao_conectado

    mov     rax, [bt_base]
    ; Copiar dados para buffer de transmissão
    mov     rcx, rdx
    mov     rdi, [rax + HCI_DATA_TX]
    rep     movsb
    ; Confirmar envio
    mov     dword [rax + HCI_STATUS], 0
    call    bt_espera_pronto
    mov     rax, 1
    ret

.nao_conectado:
    xor     rax, rax
    ret

; ==========================================
; sys_bt_receber_dados — Ler dados recebidos
; ==========================================
sys_bt_receber_dados:
    cmp     byte [bt_conectado], 1
    jne     .sem_dados

    mov     rax, [bt_base]
    mov     rsi, [rax + HCI_DATA_RX]
    mov     rax, 1
    ret

.sem_dados:
    xor     rax, rax
    ret

; ==========================================
; AUXILIARES
; ==========================================
bt_espera_pronto:
    push    rax
    push    rdx
    mov     rax, [bt_base]
.loop:
    mov     edx, [rax + HCI_STATUS]
    test    edx, HCI_OCUPADO
    jz      .pronto
    pause
    jmp     .loop
.pronto:
    pop     rdx
    pop     rax
    ret

bt_parse_resultados:
    ; Converte pacotes HCI recebidos em estruturas BtDispositivo
    ; Formato depende do controlador — exemplo genérico:
    ; [BDADDR(6)][NOME(24)][CLASSE(4)][SINAL(1)]
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi

    mov     rsi, [bt_base + HCI_DATA_RX]
    mov     rdi, bt_lista_dispositivos
    mov     rcx, 0

.proximo:
    cmp     rcx, MAX_DISPOSITIVOS
    jge     .fim

    ; Verificar se há dispositivo válido
    cmp     byte [rsi], 0
    jz      .fim

    ; Copiar BD_ADDR
    mov     rdx, rdi
    mov     rcx, BDADDR_TAMANHO
    rep     movsb

    ; Copiar nome
    mov     rcx, NOME_TAMANHO
    rep     movsb
    mov     byte [rdi], 0

    ; Avançar para próxima entrada
    inc     dword [bt_contador]
    add     rdi, BtDispositivo_size
    inc     rcx
    jmp     .proximo

.fim:
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; --- Dados Constantes ---
section .data
nome_fydelis: db "FydelisTech-Device",0
bt_endereco_alvo: resb BDADDR_TAMANHO