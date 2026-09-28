; ==================================================
; FydelisTechOS — Tratador #VMEXIT (Intel VT-x)
; Processa eventos da VM e decide o que fazer
; ==================================================
bits 64

; Offsets VMCS (reutilizados)
VMCS_EXIT_REASON        equ 0x00004402
VMCS_EXIT_QUALIFICATION equ 0x00006400
VMCS_GUEST_RIP          equ 0x00006818
VMCS_GUEST_RSP          equ 0x0000681c
VMCS_GUEST_RFLAGS       equ 0x00006820
VMCS_IDT_VECTORING      equ 0x00004404

; Códigos de saída mais comuns
EXIT_EXCECAO_NMI        equ  2
EXIT_EXCECAO_INTERRUPCAO equ 3
EXIT_INSTRUCAO_CPUID    equ 10
EXIT_INSTRUCAO_RDTSC    equ 16
EXIT_ERRO_PAGINACAO     equ 28
EXIT_INSTRUCAO_VMCALL   equ 18
EXIT_INSTRUCAO_UD2      equ 46

section .text
global vmx_handle_exit

; ─────────────────────────────────────
; Processar saída da VM (Intel)
; Entrada: rdx = código do motivo de saída
; Retorno: rax = 1 → continuar VM, 0 → encerrar
; ─────────────────────────────────────
vmx_handle_exit:
    ; Salvar contexto do hospedeiro
    push rdi
    push rsi
    push rbx

    ; Ler motivo da saída
    mov  rcx, VMCS_EXIT_REASON
    vmread rdx, rcx

    ; ── Analisar motivo ──
    cmp  rdx, EXIT_INSTRUCAO_UD2
    je   .solicitou_parada

    cmp  rdx, EXIT_INSTRUCAO_VMCALL
    je   .chamada_sistema

    cmp  rdx, EXIT_INSTRUCAO_CPUID
    je   .instrucao_cpuid

    cmp  rdx, EXIT_ERRO_PAGINACAO
    je   .falha_pagina

    cmp  rdx, EXIT_EXCECAO_INTERRUPCAO
    je   .interrupcao

    ; Motivo desconhecido — logar e encerrar
    jmp  .erro_desconhecido

; ═══ Caso 1: Convidado pediu para parar ═══
.solicitou_parada:
    mov  rax, 0                  ; Encerrar VM
    jmp  .fim

; ═══ Caso 2: Chamada do convidado para o hospedeiro ═══
.chamada_sistema:
    ; VMCALL: número da chamada em RAX
    mov  rcx, 0
    vmread rax, 0x6800           ; Ler RAX do convidado

    cmp  rax, 1
    je   .vmcall_escrever_tela
    cmp  rax, 2
    je   .vmcall_ler_disco
    cmp  rax, 3
    je   .vmcall_sair

    ; Chamada inválida
    jmp  .continuar

.vmcall_escrever_tela:
    ; RSI = ponteiro, RDI = cor
    vmread rsi, 0x6806           ; RSI convidado
    vmread rdi, 0x6807           ; RDI convidado
    call escrever_tela_vm
    jmp  .continuar

.vmcall_ler_disco:
    ; Implementar acesso a disco
    jmp  .continuar

.vmcall_sair:
    mov  rax, 0
    jmp  .fim

; ═══ Caso 3: CPUID — emular instrução ═══
.instrucao_cpuid:
    ; Ler registradores do convidado
    vmread rcx, 0x6804           ; RAX
    vmread rdx, 0x6805           ; RBX
    vmread rsi, 0x6806           ; RSI
    vmread rdi, 0x6807           ; RDI

    mov  eax, ecx
    mov  ecx, edi
    cpuid

    ; Devolver resultado para a VM
    vmwrite 0x6804, rax          ; RAX
    vmwrite 0x6805, rbx          ; RBX
    vmwrite 0x6802, rcx          ; RCX
    vmwrite 0x6803, rdx          ; RDX

    ; Avançar RIP — instrução concluída
    mov  rcx, VMCS_GUEST_RIP
    vmread rax, rcx
    add  rax, 2                  ; Tamanho aproximado de CPUID
    vmwrite rcx, rax
    jmp  .continuar

; ═══ Caso 4: Falha de página — mapear sob demanda ═══
.falha_pagina:
    vmread rdi, VMCS_EXIT_QUALIFICATION
    mov  rsi, cr2                ; Endereço que causou falha
    call tratar_falha_pagina
    test rax, rax
    jz   .erro_mapeamento
    jmp  .continuar

; ═══ Caso 5: Interrupção — repassar ═══
.interrupcao:
    ; Interrupção de hardware — processar e voltar
    jmp  .continuar

.continuar:
    mov  rax, 1                  ; ✅ Voltar para a VM
    jmp  .fim

.erro_mapeamento:
.erro_desconhecido:
    mov  rax, 0                  ; ❌ Encerrar

.fim:
    pop  rbx
    pop  rsi
    pop  rdi
    ret

; ── Funções auxiliares ──
escrever_tela_vm:
    ; rsi = texto, rdi = cor
    mov  rcx, 80*25*2
    mov  rbx, 0xB8000
.loop:
    lodsb
    test al, al
    jz   .escrito
    mov  [rbx], al
    mov  [rbx+1], dil
    add  rbx, 2
    dec  rcx
    jnz  .loop
.escrito:
    ret

tratar_falha_pagina:
    ; rsi = endereço, rdi = código
    ; Aqui você aloca quadro físico e mapeia
    ; Retornar rax=1 se conseguiu
    mov  rax, 1
    ret
; No .chamada_sistema de vmexit_handler.asm:

.chamada_sistema:
    mov  rax, [vmcb + VMCB_GUEST_RAX]  ; ou vmread para Intel

    cmp  rax, 1
    je   .escrever_tela
    cmp  rax, 10
    je   .disco_criar
    cmp  rax, 11
    je   .disco_ler
    cmp  rax, 3
    je   .sair

.disco_criar:
    ; Ler registradores do convidado
    vmread rbx, 0x6801   ; RBX = nome
    vmread rcx, 0x6802   ; RCX = dados
    vmread rdx, 0x6803   ; RDX = tamanho
    call fs_criar_arquivo
    jmp  .continuar

.disco_ler:
    vmread rbx, 0x6801   ; nome
    vmread rcx, 0x6802   ; buffer
    call fs_ler_arquivo
    vmwrite 0x6800, rax  ; Devolver tamanho
    jmp  .continuar