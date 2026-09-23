; ==========================================
; FS.ASM — FAT32 + VFS
; Leitura de Arquivos do Disco
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

; Estrutura do Boot Sector FAT
FAT_BPB_JUMP          equ 0
FAT_BPB_OEM           equ 3
FAT_BPB_BYTES_SETOR   equ 11
FAT_BPB_SETORES_CLUSTER equ 13
FAT_BPB_RESERVADOS    equ 14
FAT_BPB_NUM_FATS      equ 16
FAT_BPB_ENTRADAS_RAIZ equ 17
FAT_BPB_SETOROS_TOTAIS equ 19
FAT_BPB_TIPO          equ 36

; Entrada de Diretório
FAT_ENTRADA_NOME      equ 0
FAT_ENTRADA_ATRIB     equ 11
FAT_ENTRADA_CLUSTER_ALTO equ 20
FAT_ENTRADA_CLUSTER_BAIXO equ 26
FAT_ENTRADA_TAMANHO   equ 28

FAT_ATRIB_ARQUIVO     equ 0x20
FAT_ATRIB_DIRETORIO   equ 0x10

section .bss
align 512
setor_buffer:  resb 512
fat_buffer:    resb 4096
raiz_buffer:   resb 4096

fat_inicializado: resb 1
bytes_setor:      resw 1
setores_cluster:  resb 1
num_fats:         resb 1
cluster_raiz:     resd 1
setor_dados:      resd 1

section .text
global fs_inicializar
global fs_ler_arquivo
global fs_procurar_arquivo

; ==========================================
; INICIALIZAR FAT32
; ==========================================
fs_inicializar:
    cmp byte [fat_inicializado], 1
    je .pronto

    ; Ler setor 0 (BPB)
    mov rdi, 0
    mov rsi, setor_buffer
    call disco_ler_setor
    test rax, rax
    jz .erro

    ; Extrair parâmetros
    mov ax, [setor_buffer + FAT_BPB_BYTES_SETOR]
    mov [bytes_setor], ax
    mov al, [setor_buffer + FAT_BPB_SETORES_CLUSTER]
    mov [setores_cluster], al
    mov al, [setor_buffer + FAT_BPB_NUM_FATS]
    mov [num_fats], al

    ; Calcular região de dados
    movzx eax, word [setor_buffer + FAT_BPB_RESERVADOS]
    movzx ecx, byte [num_fats]
    movzx edx, word [setor_buffer + FAT_BPB_SETOROS_TOTAIS]
    mul ecx
    add eax, edx
    mov [setor_dados], eax

    mov byte [fat_inicializado], 1
.pronto:
    mov rax, 1
    ret
.erro:
    xor rax, rax
    ret

; ==========================================
; CONVERTER CLUSTER → NÚMERO DE SETOR
; ==========================================
cluster_para_setor:
    ; rdi = número do cluster
    sub rdi, 2                  ; Cluster 2 = primeiro de dados
    movzx rax, byte [setores_cluster]
    mul rdi
    add rax, [setor_dados]
    ret

; ==========================================
; LER ENTRADA DE ARQUIVO NO DIRETÓRIO RAIZ
; ==========================================
fs_procurar_arquivo:
    ; rdi = ponteiro para nome (8.3)
    push rbx
    push rbp
    mov rbp, rdi

    ; Posicionar no diretório raiz
    mov rdi, [cluster_raiz]
    call cluster_para_setor
    mov rdi, rax
    mov rsi, raiz_buffer
    mov rdx, 8                  ; 8 setores = diretório raiz
    call disco_ler_multiplo

    ; Percorrer entradas
    mov rcx, 512 * 8 / 32       ; Máximo entradas
    mov rsi, raiz_buffer
.procurar_loop:
    cmp byte [rsi], 0           ; Fim da lista
    je .nao_encontrado
    cmp byte [rsi], 0xE5        ; Apagado
    je .proxima

    ; Comparar nome
    mov rdi, rbp
    mov rdx, rsi
    mov r8, 11
    call comparar_nome
    test rax, rax
    jz .encontrado

.proxima:
    add rsi, 32
    dec rcx
    jnz .procurar_loop

.nao_encontrado:
    xor rax, rax
    jmp .fim

.encontrado:
    ; Retornar cluster e tamanho
    mov eax, [rsi + FAT_ENTRADA_CLUSTER_ALTO]
    shl rax, 16
    mov ax, [rsi + FAT_ENTRADA_CLUSTER_BAIXO]
    mov rdx, [rsi + FAT_ENTRADA_TAMANHO]
    ; rax = cluster, rdx = tamanho
.fim:
    pop rbp
    pop rbx
    ret

; ==========================================
; LER CONTEÚDO DO ARQUIVO
; rdi = cluster inicial, rsi = buffer destino, rdx = tamanho
; ==========================================
fs_ler_arquivo:
    push rbx
    push rbp
    mov rbp, rsi
    mov rbx, rdx
    mov r12, rdi                ; Cluster atual
    xor r13, r13                ; Bytes lidos

.ler_bloco:
    cmp r13, rbx
    jae .concluido

    ; Calcular endereço do cluster
    mov rdi, r12
    call cluster_para_setor
    mov rdi, rax
    mov rsi, rbp
    add rsi, r13
    movzx rdx, byte [setores_cluster]
    mov rcx, [bytes_setor]
    mul rcx
    sub rdx, rax
    cmp rdx, rbx
    jb .ler
    mov rdx, rbx
    sub rdx, r13
.ler:
    call disco_ler_setor
    test rax, rax
    jz .erro

    ; Avançar para próximo cluster
    mov rdi, r12
    call ler_proximo_cluster
    mov r12, rax
    cmp rax, 0x0FFFFFF8         ; Fim do arquivo
    jae .concluido

    movzx rax, byte [setores_cluster]
    movzx rcx, word [bytes_setor]
    mul rcx
    add r13, rax
    jmp .ler_bloco

.concluido:
    mov rax, r13
    jmp .fim
.erro:
    xor rax, rax
.fim:
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; ==========================================
; FUNÇÕES AUXILIARES
; ==========================================
comparar_nome:
    ; rdi = nome procurado, rdx = entrada, r8 = tamanho
    xor rax, rax
.compara_loop:
    mov al, [rdi + rcx]
    cmp al, [rdx + rcx]
    jne .diferente
    inc rcx
    cmp rcx, r8
    jb .compara_loop
    mov rax, 1
.diferente:
    ret

ler_proximo_cluster:
    ; rdi = cluster atual → rax = próximo
    mov rax, rdi
    shr rax, 2                  ; × 4 bytes por entrada
    mov rcx, [bytes_setor]
    xor rdx, rdx
    div rcx
    ; rax = setor da FAT, rdx = deslocamento
    mov rsi, fat_buffer
    call disco_ler_setor
    mov eax, [fat_buffer + rdx]
    and eax, 0x0FFFFFFF         ; Máscara FAT32
    ret

; ==========================================
; FUNÇÃO EXTERNA — Implementada no driver de disco
; ==========================================
disco_ler_setor:
    ; rdi = setor, rsi = buffer → rax = 1 sucesso, 0 falha
    extern disco_ler_setor_impl
    jmp disco_ler_setor_impl

disco_ler_multiplo:
    ; rdi = setor inicial, rsi = buffer, rdx = quantidade
    extern disco_ler_multiplo_impl
    jmp disco_ler_multiplo_impl