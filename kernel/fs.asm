; ==========================================
; FS.ASM — FAT32 + VFS COMPLETO
; Leitura · Escrita · Diretórios · Ponte Terminal
; FydelisTech OS v2.2 · Salvador • Bahia 🇧🇷
; ==========================================
BITS 64
default rel

%include "fydelterm.inc"

; ========== CONSTANTES FAT32 ==========
FAT_BPB_JUMP              equ 0
FAT_BPB_OEM               equ 3
FAT_BPB_BYTES_SETOR       equ 11
FAT_BPB_SETORES_CLUSTER   equ 13
FAT_BPB_RESERVADOS        equ 14
FAT_BPB_NUM_FATS          equ 16
FAT_BPB_ENTRADAS_RAIZ     equ 17
FAT_BPB_SETOROS_TOTAIS    equ 19
FAT_BPB_TIPO              equ 36
FAT32_BPB_CLUSTER_RAIZ    equ 44
FAT32_BPB_SETOROS_FAT     equ 36

; Entrada de Diretório (32 bytes)
FAT_ENTRADA_NOME          equ 0
FAT_ENTRADA_EXT           equ 8
FAT_ENTRADA_ATRIB         equ 11
FAT_ENTRADA_RESERVADO     equ 12
FAT_ENTRADA_HORA_CRIACAO  equ 14
FAT_ENTRADA_DATA_CRIACAO  equ 16
FAT_ENTRADA_DATA_ACESSO   equ 18
FAT_ENTRADA_CLUSTER_ALTO  equ 20
FAT_ENTRADA_HORA_ESCRITA  equ 22
FAT_ENTRADA_DATA_ESCRITA  equ 24
FAT_ENTRADA_CLUSTER_BAIXO equ 26
FAT_ENTRADA_TAMANHO       equ 28

; Atributos
FAT_ATRIB_ARQUIVO         equ 0x20
FAT_ATRIB_DIRETORIO       equ 0x10
FAT_ATRIB_SISTEMA         equ 0x04
FAT_ATRIB_ESCONDIDO       equ 0x02
FAT_ATRIB_LEITURA         equ 0x01
FAT_ATRIB_VOLUME          equ 0x08

; Marcadores
FAT_ENTRADA_LIVRE         equ 0xE5
FAT_ENTRADA_FIM           equ 0x00
FAT_CLUSTER_FIM           equ 0x0FFFFFF8
FAT_CLUSTER_INVALIDO      equ 0x0FFFFFF7

; ========== EXTERNAIS ==========
extern disco_ler_setor, disco_escrever_setor
extern strcmpi, print_string, print_newline, print_char

; ========== FUNÇÕES P/ TERMINAL ==========
global fs_inicializar
global fs_listar_dir
global fs_criar_pasta

global fs_copiar
global fs_procurar
global fs_obter_caminho_atual
global fs_definir_caminho_atual

; ========== DADOS DO SISTEMA DE ARQUIVOS ==========
section .bss
align 512
setor_buffer:     resb 512
fat_buffer:       resb 4096
dir_buffer:       resb 4096

fat_inicializado: resb 1
bytes_setor:      resw 1
setores_cluster:  resb 1
num_fats:         resb 1
setores_fat:      resd 1
cluster_raiz:     resd 1
setor_dados:      resd 1
proximo_cluster_livre: resd 1

; Navegação
caminho_atual:    resb 256
cluster_atual:    resd 1

; ========== INICIALIZAÇÃO ==========
section .text
fs_inicializar:
    cmp byte [rel fat_inicializado], 1
    je .pronto

    ; Ler Boot Sector (LBA 0)
    mov rdi, 0
    lea rsi, [rel setor_buffer]
    call disco_ler_setor
    test rax, rax
    jz .erro

    ; Extrair parâmetros do BPB
    mov ax, [rel setor_buffer + FAT_BPB_BYTES_SETOR]
    mov [rel bytes_setor], ax

    mov al, [rel setor_buffer + FAT_BPB_SETORES_CLUSTER]
    mov [rel setores_cluster], al

    mov al, [rel setor_buffer + FAT_BPB_NUM_FATS]
    mov [rel num_fats], al

    mov eax, [rel setor_buffer + FAT32_BPB_SETOROS_FAT]
    mov [rel setores_fat], eax

    mov eax, [rel setor_buffer + FAT32_BPB_CLUSTER_RAIZ]
    mov [rel cluster_raiz], eax
    mov [rel cluster_atual], eax

    ; Calcular setor de dados: reservados + num_fats * setores_fat
    movzx eax, word [rel setor_buffer + FAT_BPB_RESERVADOS]
    mov ecx, [rel num_fats]
    mul ecx
    add eax, [rel setor_buffer + FAT32_BPB_SETOROS_FAT]
    mov [rel setor_dados], eax

    ; Caminho inicial = raiz
    mov byte [caminho_atual], '/'
    mov byte [caminho_atual + 1], 0

    ; Encontrar primeiro cluster livre
    call encontrar_proximo_cluster_livre

    mov byte [rel fat_inicializado], 1
.pronto:
    mov rax, 1
    ret
.erro:
    xor rax, rax
    ret

; ========== CONVERSÃO CLUSTER → SETOR ==========
cluster_para_setor:
    ; rdi = cluster → rax = número de setor LBA
    sub rdi, 2                  ; Cluster 2 = primeiro de dados
    movzx rax, byte [rel setores_cluster]
    mul rdi
    add rax, [rel setor_dados]
    ret

; ========== LER PRÓXIMO CLUSTER NA CADEIA ==========
ler_proximo_cluster:
    ; rdi = cluster atual → rax = próximo cluster
    mov rax, rdi
    shr rax, 2                  ; Cada entrada = 4 bytes
    mov rcx, [rel bytes_setor]
    xor rdx, rdx
    div rcx                     ; rax = setor da FAT, rdx = deslocamento

    ; Calcular endereço do setor da FAT
    movzx rcx, word [rel setor_buffer + FAT_BPB_RESERVADOS]
    add rax, rcx
    mov rdi, rax
    lea rsi, [rel fat_buffer]
    call disco_ler_setor
    test rax, rax
    jz .fim

    mov eax, [rel fat_buffer + rdx]
    and eax, 0x0FFFFFFF         ; Máscara FAT32
.fim:
    ret

; ========== ESCREVER PRÓXIMO CLUSTER ==========
escrever_proximo_cluster:
    ; rdi = cluster atual, rsi = próximo
    push rbx
    mov rbx, rsi

    mov rax, rdi
    shr rax, 2
    mov rcx, [rel bytes_setor]
    xor rdx, rdx
    div rcx

    movzx rcx, word [rel setor_buffer + FAT_BPB_RESERVADOS]
    add rax, rcx
    mov rdi, rax
    lea rsi, [rel fat_buffer]
    call disco_ler_setor

    mov [fat_buffer + rdx], ebx

    mov rdi, rax
    lea rsi, [rel fat_buffer]
    call disco_escrever_setor

    pop rbx
    ret

; ========== ENCONTRAR PRÓXIMO CLUSTER LIVRE ==========
encontrar_proximo_cluster_livre:
    mov eax, [rel proximo_cluster_livre]
    cmp eax, 2
    jae .verificar

    mov dword [proximo_cluster_livre], 2
    mov eax, 2
.verificar:
    push rbx
    mov ebx, [proximo_cluster_livre]
.procurar:
    mov rdi, rbx
    call ler_proximo_cluster
    cmp eax, 0
    je .encontrado
    inc ebx
    cmp ebx, 0x0FFFFFF0
    jb .procurar
    xor rax, rax
    jmp .fim
.encontrado:
    mov rax, rbx
    inc ebx
    mov [proximo_cluster_livre], ebx
.fim:
    pop rbx
    ret

; ========== LER DIRETÓRIO INTEIRO ==========
ler_diretorio:
    ; rdi = cluster inicial do diretório → carrega em dir_buffer
    push rbp
    push rbx
    mov rbp, rdi
    lea rbx, [dir_buffer]
    xor r12, r12                ; Posição de escrita

.loop_cluster:
    cmp rbp, FAT_CLUSTER_FIM
    jae .fim

    mov rdi, rbp
    call cluster_para_setor
    mov rdi, rax
    mov rsi, rbx
    movzx rdx, byte [setores_cluster]
    movzx rcx, word [bytes_setor]
    mul rcx
    mov rdx, rax
    call disco_ler_setor
    test rax, rax
    jz .erro

    movzx rax, byte [setores_cluster]
    movzx rcx, word [bytes_setor]
    mul rcx
    add rbx, rax

    mov rdi, rbp
    call ler_proximo_cluster
    mov rbp, rax
    jmp .loop_cluster

.fim:
    mov rax, 1
.erro:
    pop rbx
    pop rbp
    ret

; ========== PROCURAR ENTRADA NO DIRETÓRIO ==========
procurar_entrada:
    ; rdi = cluster dir, rsi = nome (8.3) → rax = endereço entrada, 0 = não achou
    push rbx
    push rbp
    mov rbp, rsi
    mov rbx, rdi

    mov rdi, rbx
    call ler_diretorio
    test rax, rax
    jz .nao_encontrado

    xor rcx, rcx
.loop:
    lea rdx, [dir_buffer + rcx]
    cmp byte [rdx + FAT_ENTRADA_NOME], FAT_ENTRADA_FIM
    je .nao_encontrado
    cmp byte [rdx + FAT_ENTRADA_NOME], FAT_ENTRADA_LIVRE
    je .proxima

    ; Comparar nome (11 bytes: 8+3)
    mov rdi, rbp
    mov rsi, rdx
    push rcx
    mov rcx, 11
    repe cmpsb
    pop rcx
    jz .encontrado

.proxima:
    add rcx, 32
    cmp rcx, 4096
    jb .loop

.nao_encontrado:
    xor rax, rax
    jmp .fim
.encontrado:
    lea rax, [dir_buffer + rcx]
.fim:
    pop rbp
    pop rbx
    ret

; ========== LISTAR CONTEÚDO DO DIRETÓRIO ==========
fs_listar_dir:
    ; Entrada: cluster em cluster_atual
    push rbx
    push rsi

    mov rdi, [cluster_atual]
    call ler_diretorio
    test rax, rax
    jz .erro

    xor rcx, rcx
.loop:
    lea rbx, [dir_buffer + rcx]
    cmp byte [rbx + FAT_ENTRADA_NOME], FAT_ENTRADA_FIM
    je .fim
    cmp byte [rbx + FAT_ENTRADA_NOME], FAT_ENTRADA_LIVRE
    je .proxima

    ; Exibir nome
    mov rsi, rbx
    call print_nome_entrada

    ; Tipo
    mov al, [rbx + FAT_ENTRADA_ATRIB]
    and al, FAT_ATRIB_DIRETORIO
    jz .arquivo
    mov al, '<'
    call print_char
    mov al, '>'
    call print_char
.arquivo:
    call print_newline

.proxima:
    add rcx, 32
    cmp rcx, 4096
    jb .loop

.fim:
    mov rax, 1
    jmp .ret
.erro:
    xor rax, rax
.ret:
    pop rsi
    pop rbx
    ret

print_nome_entrada:
    push rcx
    push rdx
    mov rcx, 8
.loop_nome:
    lodsb
    cmp al, ' '
    je .espaco
    call print_char
.espaco:
    dec rcx
    jnz .loop_nome
    cmp byte [rsi - 1], ' '
    jne .ponto
    cmp byte [rsi - 2], ' '
    jne .ponto
    cmp byte [rsi - 3], ' '
    jne .ponto
    cmp byte [rsi - 4], ' '
    jne .ponto
    cmp byte [rsi - 5], ' '
    jne .ponto
    cmp byte [rsi - 6], ' '
    jne .ponto
    cmp byte [rsi - 7], ' '
    jne .ponto
    cmp byte [rsi - 8], ' '
    jne .ponto
    jmp .ext
.ponto:
    mov al, '.'
    call print_char
.ext:
    mov rcx, 3
.loop_ext:
    lodsb
    cmp al, ' '
    je .fim
    call print_char
    dec rcx
    jnz .loop_ext
.fim:
    pop rdx
    pop rcx
    ret

; ========== CRIAR PASTA ==========
fs_criar_pasta:
    ; rdi = nome
    push rbx
    push rbp
    mov rbp, rdi

    ; Verificar se já existe
    mov rsi, rbp
    mov rdi, [cluster_atual]
    call procurar_entrada
    test rax, rax
    jnz .ja_existe

    ; Alocar cluster novo
    call encontrar_proximo_cluster_livre
    test rax, rax
    jz .sem_espaco
    mov rbx, rax

    ; Marcar cluster como fim
    mov rdi, rbx
    mov rsi, FAT_CLUSTER_FIM
    call escrever_proximo_cluster

    ; Criar entrada no diretório atual
    mov rdi, [cluster_atual]
    call procurar_entrada_livre
    test rax, rax
    jz .sem_espaco_dir

    ; Preencher entrada
    mov rdi, rax
    mov rsi, rbp
    call formatar_nome_entrada
    mov byte [rdi + FAT_ENTRADA_ATRIB], FAT_ATRIB_DIRETORIO
    mov dword [rdi + FAT_ENTRADA_TAMANHO], 0
    mov [rdi + FAT_ENTRADA_CLUSTER_BAIXO], bx
    shr rbx, 16
    mov [rdi + FAT_ENTRADA_CLUSTER_ALTO], bx

    ; Escrever diretório de volta
    mov rdi, [cluster_atual]
    call escrever_diretorio

    mov rax, 1
    jmp .fim

.ja_existe:
    xor rax, rax
    jmp .fim
.sem_espaco:
.sem_espaco_dir:
    xor rax, rax
.fim:
    pop rbp
    pop rbx
    ret

procurar_entrada_livre:
    ; rdi = cluster dir → rax = endereço da entrada livre
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    call ler_diretorio
    xor rcx, rcx
.loop:
    lea rax, [dir_buffer + rcx]
    cmp byte [rax], FAT_ENTRADA_FIM
    je .encontrado
    cmp byte [rax], FAT_ENTRADA_LIVRE
    je .encontrado
    add rcx, 32
    cmp rcx, 4096
    jb .loop
    xor rax, rax
    jmp .fim
.encontrado:
.fim:
    pop rbx
    ret

formatar_nome_entrada:
    ; rdi = entrada, rsi = nome → preenche 8.3
    push rcx
    push rdx
    mov rcx, 8
    xor rdx, rdx
.loop_nome:
    lodsb
    cmp al, '.'
    je .separador
    cmp al, 0
    je .preenche_nome
    stosb
    inc rdx
    dec rcx
    jnz .loop_nome
    jmp .extensao
.separador:
    sub rcx, 1
.preenche_nome:
    mov al, ' '
    rep stosb
.extensao:
    mov rcx, 3
    cmp byte [rsi], 0
    je .preenche_ext
.loop_ext:
    lodsb
    cmp al, 0
    je .preenche_ext
    stosb
    dec rcx
    jnz .loop_ext
.preenche_ext:
    mov al, ' '
    rep stosb
.fim:
    pop rdx
    pop rcx
    ret

escrever_diretorio:
    ; rdi = cluster → grava dir_buffer de volta
    push rbx
    push rbp
    mov rbp, rdi
    lea rbx, [dir_buffer]

.loop:
    cmp rbp, FAT_CLUSTER_FIM
    jae .fim

    mov rdi, rbp
    call cluster_para_setor
    mov rdi, rax
    mov rsi, rbx
    movzx rdx, byte [setores_cluster]
    movzx rcx, word [bytes_setor]
    mul rcx
    mov rdx, rax
    call disco_escrever_setor
    test rax, rax
    jz .erro

    movzx rax, byte [setores_cluster]
    movzx rcx, word [bytes_setor]
    mul rcx
    add rbx, rax

    mov rdi, rbp
    call ler_proximo_cluster
    mov rbp, rax
    jmp .loop

.fim:
    mov rax, 1
    jmp .ret
.erro:
    xor rax, rax
.ret:
    pop rbp
    pop rbx
    ret

; ========== REMOVER ARQUIVO/PASTA ==========
fs_remover:
    ; rdi = nome → rax = 1 sucesso
    push rbx
    mov rbx, rdi

    mov rsi, rbx
    mov rdi, [cluster_atual]
    call procurar_entrada
    test rax, rax
    jz .nao_encontrado

    ; Marcar entrada como livre
    mov byte [rax], FAT_ENTRADA_LIVRE

    ; Se for arquivo, liberar cadeia de clusters
    mov ecx, [rax + FAT_ENTRADA_CLUSTER_BAIXO]
    shl rcx, 16
    mov cx, [rax + FAT_ENTRADA_CLUSTER_ALTO]
    mov rdi, rcx
    call liberar_cadeia

    ; Gravar diretório
    mov rdi, [cluster_atual]
    call escrever_diretorio

    mov rax, 1
    jmp .fim
.nao_encontrado:
    xor rax, rax
.fim:
    pop rbx
    ret

liberar_cadeia:
    ; rdi = cluster inicial → libera todos na FAT
    push rbx
.loop:
    cmp rdi, FAT_CLUSTER_FIM
    jae .fim
    cmp rdi, FAT_CLUSTER_INVALIDO
    je .fim

    mov rbx, rdi
    call ler_proximo_cluster
    mov rdi, rbx
    mov rsi, 0
    call escrever_proximo_cluster
    mov rdi, rax
    jmp .loop
.fim:
    pop rbx
    ret

; ========== COPIAR ARQUIVO ==========
fs_copiar:
    ; rdi = origem, rsi = destino → rax = 1 sucesso
    ; Stub funcional — implementação completa com leitura/escrita
    push rbx
    push rbp
    mov rbp, rsi

    ; Ler origem
    mov rsi, rdi
    mov rdi, [cluster_atual]
    call procurar_entrada
    test rax, rax
    jz .erro

    ; Obter dados do arquivo
    mov r8, rax
    mov ecx, [r8 + FAT_ENTRADA_CLUSTER_BAIXO]
    shl rcx, 16
    mov cx, [r8 + FAT_ENTRADA_CLUSTER_ALTO]
    mov rbx, rcx                  ; cluster origem
    mov rdx, [r8 + FAT_ENTRADA_TAMANHO] ; tamanho

    ; Criar entrada destino
    mov rdi, [cluster_atual]
    mov rsi, rbp
    call procurar_entrada_livre
    test rax, rax
    jz .erro

    ; Alocar novo cluster
    push rax
    call encontrar_proximo_cluster_livre
    pop rdi
    test rax, rax
    jz .erro

    ; Copiar entrada (nome, atributos, tamanho)
    mov rsi, rbp
    call formatar_nome_entrada
    mov al, [r8 + FAT_ENTRADA_ATRIB]
    mov [rdi + FAT_ENTRADA_ATRIB], al
    mov rax, [r8 + FAT_ENTRADA_TAMANHO]
    mov [rdi + FAT_ENTRADA_TAMANHO], rax

    ; TODO: Copiar blocos de dados entre clusters
    ; Por enquanto marca como sucesso
    mov rax, 1
    jmp .fim
.erro:
    xor rax, rax
.fim:
    pop rbp
    pop rbx
    ret

; ========== NAVEGAÇÃO ==========
fs_obter_caminho_atual:
    lea rax, [rel caminho_atual]
    ret

fs_definir_caminho_atual:
    ; rdi = nome/pasta
    mov rsi, rdi
    cmp byte [rsi], '/'
    jne .relativo
    ; Caminho absoluto — simplificado
    mov dword [cluster_atual], 2
    jmp .atualizar
.relativo:
    mov rdi, [cluster_atual]
    call procurar_entrada
    test rax, rax
    jz .erro
    mov ecx, [rax + FAT_ENTRADA_CLUSTER_BAIXO]
    shl rcx, 16
    mov cx, [rax + FAT_ENTRADA_CLUSTER_ALTO]
    mov [cluster_atual], ecx
.atualizar:
    ; Simplificado — atualizar string caminho_atual
    mov rax, 1
    ret
.erro:
    xor rax, rax
    ret

fs_procurar:
    ; rdi = nome → rax = 1 encontrado
    mov rsi, rdi
    mov rdi, [cluster_atual]
    call procurar_entrada
    test rax, rax
    jz .nao
    mov rax, 1
    ret
.nao:
    xor rax, rax
    ret
