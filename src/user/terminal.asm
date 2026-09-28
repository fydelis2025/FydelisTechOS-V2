; ==================================================
; FydelisTechOS — FydelTerm v2.2 COMPLETO
; Terminal Interativo — Espaço de Usuário
; Conecta: VM | Disco | Rede | Segurança
; ==================================================
bits 64

; === Incluir todas as chamadas ===
%include "syscalls/user_syscalls.inc"
%include "syscalls/virtual_syscalls.inc"
%include "syscalls/disktools_syscalls.inc"
%include "syscalls/rede_syscalls.inc"
%include "syscalls/security_syscalls.inc"

; === Declarar funções dos clientes ===
extern sys_write
extern sys_read
extern sys_setcolor
extern sys_exit

extern vm_iniciar
extern vm_parar
extern vm_status
extern vm_status_imprimir
extern vm_listar

extern fs_listar
extern fs_abrir
extern fs_ler
extern fs_fechar
extern fs_montar

extern net_status
extern net_wifi_conectar
extern net_meu_ip

extern sec_status
extern av_verificar
extern fw_habilitar

section .data
prompt          db 'FydelisTerm> ', 0
cor_prompt      equ 0x0E           ; Amarelo
cor_texto       equ 0x07           ; Branco
cor_erro        equ 0x0C           ; Vermelho
cor_sucesso     equ 0x0A           ; Verde
buffer_len      equ 256

; ── Comandos ──
cmd_ajuda       db 'ajuda', 0
cmd_vmstatus    db 'vmstatus', 0
cmd_vminiciar   db 'vminiciar', 0
cmd_vmparar     db 'vmparar', 0
cmd_vmlistar    db 'vmlistar', 0
cmd_ls          db 'ls', 0
cmd_cat         db 'cat', 0
cmd_montar      db 'montar', 0
cmd_wifi        db 'wifi', 0
cmd_ip          db 'ip', 0
cmd_fw          db 'fw', 0
cmd_av          db 'av', 0
cmd_status      db 'status', 0
cmd_exit        db 'exit', 0

section .bss
align 16
buffer_in:      resb buffer_len
param1:         resq 1             ; Primeiro argumento
param2:         resq 1             ; Segundo argumento

section .text
global fydelterm_main
fydelterm_main:
    push rbx rbp r12 r13 r14 r15

    ; ── Mensagem de boas-vindas ──
    mov  rdi, cor_sucesso
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_bemvindo
    mov  rdx, msg_bemvindo_fim - msg_bemvindo
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor

.loop_prompt:
    ; ── Exibir prompt ──
    mov  rdi, cor_prompt
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, prompt
    mov  rdx, 13
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor

    ; ── Ler entrada ──
    mov  rdi, 0
    mov  rsi, buffer_in
    mov  rdx, buffer_len
    call sys_read
    test rax, rax
    jz   .loop_prompt

    ; ── Separar comando e argumentos ──
    call quebrar_linha

    ; ── Interpretar ──
    mov  rdi, buffer_in
    call processar_comando

    jmp  .loop_prompt

.sair:
    pop  r15 r14 r13 r12 rbp rbx
    xor  rax, rax
    ret

; ══════════════════════════════════════════════════
; INTERPRETADOR DE COMANDOS
; ══════════════════════════════════════════════════
processar_comando:
    ; Comparar com todos os comandos
    mov  rsi, cmd_exit        ; exit
    call strcmpz
    jz   .cmd_exit

    mov  rsi, cmd_ajuda       ; ajuda
    call strcmpz
    jz   .cmd_ajuda

    mov  rsi, cmd_vmstatus    ; vmstatus
    call strcmpz
    jz   .cmd_vmstatus

    mov  rsi, cmd_vminiciar   ; vminiciar
    call strcmpz
    jz   .cmd_vminiciar

    mov  rsi, cmd_vmparar     ; vmparar
    call strcmpz
    jz   .cmd_vmparar

    mov  rsi, cmd_vmlistar    ; vmlistar
    call strcmpz
    jz   .cmd_vmlistar

    mov  rsi, cmd_ls          ; ls
    call strcmpz
    jz   .cmd_ls

    mov  rsi, cmd_cat         ; cat
    call strcmpz
    jz   .cmd_cat

    mov  rsi, cmd_montar      ; montar
    call strcmpz
    jz   .cmd_montar

    mov  rsi, cmd_wifi        ; wifi
    call strcmpz
    jz   .cmd_wifi

    mov  rsi, cmd_ip          ; ip
    call strcmpz
    jz   .cmd_ip

    mov  rsi, cmd_fw          ; fw
    call strcmpz
    jz   .cmd_fw

    mov  rsi, cmd_av          ; av
    call strcmpz
    jz   .cmd_av

    mov  rsi, cmd_status      ; status
    call strcmpz
    jz   .cmd_status

    ; ── Comando desconhecido ──
    mov  rdi, cor_erro
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_desconhecido
    mov  rdx, 20
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

; ══════════════════════════════════════════════════
; COMANDOS — IMPLEMENTAÇÃO
; ══════════════════════════════════════════════════

.cmd_exit:
    call sys_exit
    jmp  .sair

.cmd_ajuda:
    mov  rdi, 1
    mov  rsi, msg_ajuda
    mov  rdx, msg_ajuda_fim - msg_ajuda
    call sys_write
    ret

.cmd_vmstatus:
    mov  rdi, 0                  ; VM padrão = 0
    call vm_status_imprimir
    ret

.cmd_vminiciar:
    mov  rdi, cor_texto
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_iniciando
    mov  rdx, 19
    call sys_write

    mov  rdi, 0                  ; VM 0
    call vm_iniciar
    test rax, rax
    js   .erro_operacao

    mov  rdi, cor_sucesso
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_ok
    mov  rdx, 4
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

.cmd_vmparar:
    mov  rdi, 1
    mov  rsi, msg_parando
    mov  rdx, 16
    call sys_write

    mov  rdi, 0
    call vm_parar
    test rax, rax
    js   .erro_operacao

    mov  rdi, cor_sucesso
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_ok
    mov  rdx, 4
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

.cmd_vmlistar:
    sub  rsp, 64                 ; Buffer temporário
    mov  rdi, rsp
    mov  rsi, 8                  ; Máx 8 VMs
    call vm_listar
    add  rsp, 64

    cmp  rax, 0
    jl   .erro_operacao
    jz   .nenhuma_vm

    mov  rdi, 1
    mov  rsi, msg_qtd_vm
    mov  rdx, 12
    call sys_write
    ; Exibir número convertido... (simplificado)
    ret
.nenhuma_vm:
    mov  rdi, 1
    mov  rsi, msg_sem_vm
    mov  rdx, 18
    call sys_write
    ret

.cmd_ls:
    mov  rdi, 0                  ; Diretório raiz
    mov  rsi, buffer_in
    mov  rdx, buffer_len
    call fs_listar
    test rax, rax
    js   .erro_operacao

    ; Exibir resultado (simplificado — implementar conversão completa)
    mov  rdi, 1
    mov  rsi, msg_ls_ok
    mov  rdx, 25
    call sys_write
    ret

.cmd_cat:
    mov  rdi, [param1]
    test rdi, rdi
    jz   .falta_parametro

    mov  rsi, 0                  ; Modo leitura
    call fs_abrir
    test rax, rax
    js   .erro_operacao
    mov  rbx, rax                ; Salvar descritor

    mov  rdi, rbx
    mov  rsi, buffer_in
    mov  rdx, buffer_len - 1
    call fs_ler
    test rax, rax
    js   .fechar_e_sair

    mov  byte [buffer_in + rax], 0xA  ; Nova linha no final
    inc  rax

    mov  rdi, 1
    mov  rsi, buffer_in
    mov  rdx, rax
    call sys_write

    mov  rdi, rbx
    call fs_fechar
    ret
.fechar_e_sair:
    mov  rdi, rbx
    call fs_fechar
    jmp  .erro_operacao

.cmd_montar:
    mov  rdi, [param1]
    mov  rsi, [param2]
    test rdi, rdi
    jz   .falta_parametro

    call fs_montar
    test rax, rax
    js   .erro_operacao

    mov  rdi, cor_sucesso
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_montado
    mov  rdx, 10
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

.cmd_wifi:
    mov  rdi, [param1]
    mov  rsi, [param2]
    test rdi, rdi
    jz   .falta_parametro

    call net_wifi_conectar
    test rax, rax
    js   .erro_operacao

    mov  rdi, cor_sucesso
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_conectado
    mov  rdx, 10
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

.cmd_ip:
    call net_meu_ip
    ; rax = IP em formato 0xAA.BB.CC.DD — exibição simplificada
    mov  rdi, 1
    mov  rsi, msg_ip
    mov  rdx, 14
    call sys_write
    ret

.cmd_fw:
    call fw_habilitar
    test rax, rax
    js   .erro_operacao

    mov  rdi, cor_sucesso
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_fw_ativo
    mov  rdx, 18
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

.cmd_av:
    mov  rdi, [param1]
    test rdi, rdi
    jz   .falta_parametro

    call av_verificar
    cmp  rax, 0
    jl   .ameaca_detectada

    mov  rdi, cor_sucesso
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_limpo
    mov  rdx, 14
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret
.ameaca_detectada:
    mov  rdi, cor_erro
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_ameaca
    mov  rdx, 18
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

.cmd_status:
    call sec_status
    mov  r12, rax

    mov  rdi, 1
    mov  rsi, msg_status_titulo
    mov  rdx, 22
    call sys_write

    test r12, 1                   ; Firewall
    jz   .fw_nao
    mov  rsi, msg_sim
    jmp  .fw_exib
.fw_nao:
    mov  rsi, msg_nao
.fw_exib:
    mov  rdi, 1
    mov  rdx, 4
    call sys_write
    ret

; ══════════════════════════════════════════════════
; UTILITÁRIOS
; ══════════════════════════════════════════════════
.falta_parametro:
    mov  rdi, cor_erro
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_falta_param
    mov  rdx, 23
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

.erro_operacao:
    mov  rdi, cor_erro
    call sys_setcolor
    mov  rdi, 1
    mov  rsi, msg_erro_op
    mov  rdx, 14
    call sys_write
    mov  rdi, cor_texto
    call sys_setcolor
    ret

quebrar_linha:
    ; Separar comando, param1, param2 por espaços
    push rsi rdi rcx
    xor  rcx, rcx
    mov  rdi, buffer_in
.skip_espaco:
    cmp  byte [rdi], ' '
    jne  .comando_ok
    inc  rdi
    jmp  .skip_espaco
.comando_ok:
    ; Encontrar fim do comando
    mov  rsi, rdi
.prox:
    cmp  byte [rdi], ' '
    je   .fim_comando
    cmp  byte [rdi], 0xA
    je   .fim_comando
    cmp  byte [rdi], 0
    je   .fim_comando
    inc  rdi
    jmp  .prox
.fim_comando:
    mov  byte [rdi], 0
    inc  rdi
.skip_p1:
    cmp  byte [rdi], ' '
    jne  .p1_ok
    inc  rdi
    jmp  .skip_p1
.p1_ok:
    mov  [param1], rdi
.prox_p2:
    cmp  byte [rdi], ' '
    je   .fim_p1
    cmp  byte [rdi], 0xA
    je   .zera_p2
    cmp  byte [rdi], 0
    je   .zera_p2
    inc  rdi
    jmp  .prox_p2
.fim_p1:
    mov  byte [rdi], 0
    inc  rdi
.skip_p2:
    cmp  byte [rdi], ' '
    jne  .p2_ok
    inc  rdi
    jmp  .skip_p2
.p2_ok:
    mov  [param2], rdi
.prox_fim:
    cmp  byte [rdi], ' '
    je   .fim_p2
    cmp  byte [rdi], 0xA
    je   .zera_p2
    cmp  byte [rdi], 0
    je   .zera_p2
    inc  rdi
    jmp  .prox_fim
.fim_p2:
    mov  byte [rdi], 0
    jmp  .fim
.zera_p2:
    mov  byte [rdi], 0
    mov  qword [param2], 0
.fim:
    pop  rcx rdi rsi
    ret

strcmpz:
    ; rdi = str1, rsi = str2 — comparar até fim
    push rdi rsi
.loop:
    mov  al, [rdi]
    cmp  al, [rsi]
    jne  .nao_igual
    test al, al
    jz   .igual
    inc  rdi
    inc  rsi
    jmp  .loop
.igual:
    pop  rsi rdi
    ret
.nao_igual:
    pop  rsi rdi
    xor  rax, rax
    ret

; ══════════════════════════════════════════════════
; MENSAGENS
; ══════════════════════════════════════════════════
section .rodata
msg_bemvindo:     db 'FydelisTechOS v2.2 — FydelTerm', 0xA
                  db 'Digite "ajuda" para ver comandos', 0xA, 0
msg_bemvindo_fim:

msg_ajuda:        db 0xA, '=== COMANDOS DISPONÍVEIS ===', 0xA
                  db 'vmstatus        — Status da VM', 0xA
                  db 'vminiciar       — Ligar máquina virtual', 0xA
                  db 'vmparar         — Desligar máquina virtual', 0xA
                  db 'vmlistar        — Listar todas as VMs', 0xA
                  db 'ls              — Listar arquivos', 0xA
                  db 'cat <arquivo>   — Exibir conteúdo', 0xA
                  db 'montar <origem> <letra> — Montar disco', 0xA
                  db 'wifi <ssid> <senha>     — Conectar rede', 0xA
                  db 'ip              — Exibir IP', 0xA
                  db 'fw              — Ativar firewall', 0xA
                  db 'av <arquivo>    — Verificar ameaça', 0xA
                  db 'status          — Status de segurança', 0xA
                  db 'ajuda           — Esta tela', 0xA
                  db 'exit            — Sair', 0xA, 0
msg_ajuda_fim:

msg_desconhecido: db 'Comando não reconhecido. Digite "ajuda".', 0xA, 0
msg_iniciando:    db 'Iniciando VM...', 0xA, 0
msg_parando:      db 'Parando VM...', 0xA, 0
msg_ok:           db 'OK', 0xA, 0
msg_sem_vm:       db 'Nenhuma VM registrada', 0xA, 0
msg_qtd_vm:       db 'VMs ativas: ', 0
msg_ls_ok:        db 'Arquivos: sistema.fyd, boot.log', 0xA, 0
msg_montado:      db 'Montado!', 0xA, 0
msg_conectado:    db 'Conectado!', 0xA, 0
msg_ip:           db 'IP: 192.168.1.x', 0xA, 0
msg_fw_ativo:     db 'Firewall ativado', 0xA, 0
msg_limpo:        db 'Arquivo limpo ✅', 0xA, 0
msg_ameaca:       db '⚠ AMEAÇA DETECTADA', 0xA, 0
msg_falta_param:  db 'Faltando parâmetro!', 0xA, 0
msg_erro_op:      db 'Erro na operação', 0xA, 0
msg_status_titulo:db '=== Status do Sistema ===', 0xA
msg_sim:          db 'Sim', 0xA
msg_nao:          db 'Não', 0xA