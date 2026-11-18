; ======================================
; CVE GUARD — INTERCEPTADOR EM TEMPO REAL
; FydelisTech OS v4.2 (x86_64 Kernel Module)
; De Salvador • Bahia
; ======================================
BITS 64
default rel

; Funcoes exportadas para o Kernel C e Assembly (System V AMD64 ABI)
global cve_guard_iniciar
global cve_guard_verificar_padrao
global cve_guard_adicionar_regra
global cve_guard_inspecionar_comando
global cve_guard_total_alertas

; Funcoes externas do Kernel C (stubs_kernel.c / texto.c / fydlog.c)
extern fydlog_registrar

section .data
msg_guard_iniciado:  db '[CVE-GUARD] Interceptacao de memoria e syscalls ativa', 0
msg_alerta:          db '[CVE-GUARD] ALERTA: Assinatura de vulnerabilidade detectada!', 0

max_regras:          equ 32
tamanho_regra:       equ 448       ; 32 (id) + 128 (padrao) + 32 (acao) + 256 (msg)

num_regras:          dq 0
total_alertas:       dq 0
guard_ativo:         db 0

section .bss
; Tabela estruturada em memoria alinhada para 32 regras
; Offset +0:   id (32 bytes)
; Offset +32:  padrao (128 bytes)
; Offset +160: acao (32 bytes)
; Offset +192: mensagem (256 bytes)
tabela_regras:       resb (max_regras * tamanho_regra)

section .text

; ======================================
; void cve_guard_iniciar(void)
; Inicializa a tabela de regras e ativa o interceptador
; ======================================
cve_guard_iniciar:
    push    rbp
    mov     rbp, rsp

    mov     qword [num_regras], 0
    mov     qword [total_alertas], 0
    mov     byte [guard_ativo], 1

    ; Registra no log interno do kernel (1o arg em RDI)
    lea     rdi, [rel msg_guard_iniciado]
    call    fydlog_registrar

    pop     rbp
    ret

; ======================================
; int cve_guard_verificar_padrao(const char *texto, const char *padrao)
; ABI C: RDI = texto a verificar, RSI = padrao (com suporte a curinga '*')
; Retorno: RAX = 1 (match), 0 (limpo)
; ======================================
cve_guard_verificar_padrao:
    push    rbx
    push    rcx
    push    rdx
    push    r8
    push    r9

    xor     rax, rax                ; Retorno padrao = 0
    test    rdi, rdi
    jz      .fim_nao
    test    rsi, rsi
    jz      .fim_nao

    mov     r8, rdi                 ; Salva inicio do texto
    mov     r9, rsi                 ; Salva inicio do padrao

.loop_comparar:
    mov     al, [rsi]               ; Caractere atual do padrao
    cmp     al, 0
    je      .encontrado             ; Fim do padrao = match completo

    cmp     al, '*'
    je      .curinga

    mov     bl, [rdi]               ; Caractere atual do texto
    cmp     bl, 0
    je      .fim_nao                ; Texto acabou antes do padrao

    cmp     al, bl
    jne     .avancar_texto          ; Tenta proxima posicao no texto

    inc     rdi
    inc     rsi
    jmp     .loop_comparar

.curinga:
    inc     rsi                     ; Avanca alem do '*'
    cmp     byte [rsi], 0
    je      .encontrado             ; '*' no final casa com qualquer resto

.busca_pos_curinga:
    mov     bl, [rdi]
    cmp     bl, 0
    je      .fim_nao
    cmp     bl, [rsi]
    je      .loop_comparar
    inc     rdi
    jmp     .busca_pos_curinga

.avancar_texto:
    inc     r8
    mov     rdi, r8
    mov     rsi, r9                 ; Reinicia comparacao do padrao
    cmp     byte [rdi], 0
    je      .fim_nao
    jmp     .loop_comparar

.encontrado:
    mov     rax, 1
    jmp     .sair

.fim_nao:
    xor     rax, rax

.sair:
    pop     r9
    pop     r8
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ======================================
; int cve_guard_adicionar_regra(const char *id, const char *padrao, const char *msg)
; ABI C: RDI = id, RSI = padrao, RDX = mensagem
; Retorno: RAX = indice da regra ou -1 se tabela cheia
; ======================================
cve_guard_adicionar_regra:
    push    rbx
    push    rcx
    push    rdi
    push    rsi

    mov     rax, [num_regras]
    cmp     rax, max_regras
    jge     .cheia

    ; Calcula endereco base: tabela_regras + (num_regras * 448)
    imul    rbx, rax, tamanho_regra
    lea     rcx, [rel tabela_regras]
    add     rcx, rbx

    ; Copia ID (offset +0, max 31 bytes)
    push    rcx
    mov     rbx, 31
.cp_id:
    mov     al, [rdi]
    mov     [rcx], al
    test    al, al
    jz      .fim_cp_id
    inc     rdi
    inc     rcx
    dec     rbx
    jnz     .cp_id
    mov     byte [rcx], 0
.fim_cp_id:
    pop     rcx

    ; Copia Padrao (offset +32, max 127 bytes)
    push    rcx
    add     rcx, 32
    mov     rbx, 127
.cp_pad:
    mov     al, [rsi]
    mov     [rcx], al
    test    al, al
    jz      .fim_cp_pad
    inc     rsi
    inc     rcx
    dec     rbx
    jnz     .cp_pad
    mov     byte [rcx], 0
.fim_cp_pad:
    pop     rcx

    ; Copia Mensagem (offset +192, max 255 bytes)
    add     rcx, 192
    mov     rbx, 255
.cp_msg:
    mov     al, [rdx]
    mov     [rcx], al
    test    al, al
    jz      .fim_cp_msg
    inc     rdx
    inc     rcx
    dec     rbx
    jnz     .cp_msg
    mov     byte [rcx], 0
.fim_cp_msg:

    mov     rax, [num_regras]
    inc     qword [num_regras]
    jmp     .ret_add

.cheia:
    mov     rax, -1

.ret_add:
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rbx
    ret

; ======================================
; int cve_guard_inspecionar_comando(const char *buffer)
; Varre todas as regras carregadas contra o buffer passado em RDI
; Retorno: RAX = 1 (BLOQUEADO/ALERTA), 0 (SEGURO)
; ======================================
cve_guard_inspecionar_comando:
    push    rbx
    push    rcx
    push    r12
    push    r13

    cmp     byte [guard_ativo], 1
    jne     .seguro

    mov     r12, rdi                ; Guarda ponteiro do buffer a inspecionar
    xor     r13, r13                ; Indice i = 0

.loop_regras:
    cmp     r13, [num_regras]
    jge     .seguro

    ; Calcula offset do padrao: tabela_regras + (i * 448) + 32
    imul    rbx, r13, tamanho_regra
    lea     rsi, [rel tabela_regras]
    add     rsi, rbx
    add     rsi, 32                 ; Aponta para regra[i].padrao

    mov     rdi, r12                ; Restaura buffer no 1o argumento
    call    cve_guard_verificar_padrao
    cmp     rax, 1
    je      .ameaca_detectada

    inc     r13
    jmp     .loop_regras

.ameaca_detectada:
    inc     qword [total_alertas]
    lea     rdi, [rel msg_alerta]
    call    fydlog_registrar
    mov     rax, 1
    jmp     .fim_insp

.seguro:
    xor     rax, rax

.fim_insp:
    pop     r13
    pop     r12
    pop     rcx
    pop     rbx
    ret

; ======================================
; uint64_t cve_guard_total_alertas(void)
; ======================================
cve_guard_total_alertas:
    mov     rax, [total_alertas]
    ret
