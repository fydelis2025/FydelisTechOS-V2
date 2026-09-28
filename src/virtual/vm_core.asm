; ==================================================
; FydelisTechOS — VM Mínima / VMCS v2.2
; Executa código convidado no modo de virtualização
; ==================================================
bits 64
align 4096

; ========== Estruturas e Offsets VMCS ==========
; Definições oficiais da Intel — não mudar!
VMCS_VOID               equ 0
VMCS_GUEST_RIP          equ 0x00006818
VMCS_GUEST_RSP          equ 0x0000681c
VMCS_GUEST_CR3          equ 0x0000680c
VMCS_GUEST_CR0          equ 0x00006804
VMCS_GUEST_CR4          equ 0x00006824
VMCS_CTRL_EXEC          equ 0x00004000
VMCS_CTRL_EXEC_HI       equ 0x00004001
VMCS_CTRL_PIN           equ 0x00004002
VMCS_CTRL_PROC          equ 0x00004004
VMCS_CTRL_ENTRY         equ 0x0000400e
VMCS_EXIT_REASON        equ 0x00004402
VMCS_EXIT_QUALIFICATION equ 0x00006400

; Máscaras de bits obrigatórias
CR0_MUST_ON  equ 0x80000000  ; PG = paginação ligada
CR0_MUST_OFF equ 0x1F        ; Bits 0-4 desligados
CR4_MUST_ON  equ 0x00000200  ; PAE
CR4_MUST_OFF equ 0xFFFFF800

; ========== Dados da VM ==========
section .bss
align 4096
global vmcs_region
global vm_guest_rip
global vm_guest_rsp

vmcs_region:        resb 4096   ; Área de controle VMCS
vm_guest_stack:     resb 8192   ; 8KB de pilha para convidado
vm_guest_rip:       resq 1      ; Endereço de entrada do convidado
vm_guest_rsp:       resq 1      ; Ponteiro de pilha do convidado
vm_guest_cr3:       resq 1      ; CR3 do convidado

section .text

; ==================================================
; Passo 1 — Inicializar VMCS
; ==================================================
global vmcs_init
vmcs_init:
    ; Carregar endereço físico da VMCS
    mov  rax, vmcs_region
    vmclear [rax]
    jc   .vmcs_erro

    ; Apontar VMCS para a região atual
    mov  rax, vmcs_region
    vmptrld [rax]
    jc   .vmcs_erro

    ; ── Configurar registradores de controle ──
    ; CR0 convidado: ativar PG e desligar bits proibidos
    mov  rax, CR0_MUST_ON
    bts  rax, 0                  ; PE = modo protegido
    vmwrite VMCS_GUEST_CR0, rax

    ; CR4 convidado: ativar PAE e bits mínimos
    mov  rax, CR4_MUST_ON
    vmwrite VMCS_GUEST_CR4, rax

    ; CR3 convidado → usa tabelas próprias ou compartilhada
    mov  rax, [vm_guest_cr3]
    test rax, rax
    jnz  .usar_cr3_proprio
    mov  rax, pml4_table         ; Reutiliza do kernel se não definido
.usar_cr3_proprio:
    vmwrite VMCS_GUEST_CR3, rax

    ; ── Campos de execução ──
    ; Controles de execução primários
    mov  rax, 0x1                ; Ativar interrupções
    vmwrite VMCS_CTRL_EXEC, rax

    ; Controles de entrada
    mov  rax, 0x11               ; Ativar IA-32e modo + carregar CS
    vmwrite VMCS_CTRL_ENTRY, rax

    ; ── Estado do convidado ──
    ; RIP = ponto de entrada do código convidado
    mov  rax, [vm_guest_rip]
    vmwrite VMCS_GUEST_RIP, rax

    ; RSP = topo da pilha do convidado
    mov  rax, vm_guest_stack + 8192
    mov  [vm_guest_rsp], rax
    vmwrite VMCS_GUEST_RSP, rax

    mov  rax, 1                  ; ✅ VMCS pronta
    ret

.vmcs_erro:
    xor  rax, rax
    ret

; ==================================================
; Passo 2 — Executar a VM
; ==================================================
global vm_launch
vm_launch:
    ; Salvar contexto do hospedeiro
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    ; ⚡ Aqui o processador SALTA para o convidado
    vmlaunch

    ; ─────────────────────────────────────────────
    ; O código abaixo só executa APÓS a VM sair
    ; ─────────────────────────────────────────────
    jc   .falha_vmlaunch

    ; Sucesso — VM retornou por exit
    mov  rax, 1
    jmp  .fim

.falha_vmlaunch:
    ; Ler motivo da saída
    vmread rax, VMCS_EXIT_REASON
    mov  rdx, rax                ; Código do motivo em rdx
    xor  rax, rax                ; Falha

.fim:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbp
    pop  rbx
    ret

; ==================================================
; Passo 3 — Carregar código convidado na memória
; ==================================================
global vm_load_guest
vm_load_guest:
    ; Entradas:
    ;   rsi = ponteiro para código do convidado
    ;   rdi = endereço físico onde carregar
    ;   rcx = tamanho do código
    mov  r8, rdi                 ; Salvar endereço destino
    rep movsb                    ; Copiar código para memória

    ; Definir RIP de entrada = endereço onde carregou
    mov  [vm_guest_rip], r8
    ret

; ==================================================
; Exemplo de código convidado (teste)
; ==================================================
section .rodata
align 16
global vm_test_guest_code
global vm_test_guest_len

vm_test_guest_code:
    bits 64
    ; Este código roda DENTRO da VM
    mov  al, 'V'
    mov  ah, 0x0F                ; Cor branco sobre preto
    mov  [0xB8000], ax           ; Escrever na tela VGA (modo texto)

    ; Sair da VM — instrução de parada gera VM-exit
    ud2                          ; Forçar saída controlada
vm_test_guest_len equ $ - vm_test_guest_code