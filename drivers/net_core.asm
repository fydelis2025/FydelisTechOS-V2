; ============================================================================
; RECEBER QUADRO ETHERNET BRUTO DO ANEL RX DO HARDWARE E1000
; Entrada: rdi = buffer de destino (>= 1518 bytes)
; Saida:   rax = quantidade de bytes lidos (0 se nenhum quadro pronto)
; ============================================================================
BITS 64
DEFAULT REL

; Constantes do controlador Intel 82540EM (e1000)
PKT_BUF_SIZE    equ 2048
NUM_RX_DESC     equ 32
E1000_REG_RDT   equ 0x2818

; Símbolos exportados pelo driver e1000 (rede.asm / pci.asm)
extern nic_presente
extern e1000_mmio_base
extern rx_cur_idx
extern rx_descs
extern rx_buffers
extern rx_total_bytes

global e1000_enviar_quadro, e1000_receber_quadro, mac_bytes

section .text

e1000_receber_quadro:
    push    rbx
    push    rcx
    push    rdx
    push    rsi

    cmp     byte [rel nic_presente], 1
    jne     .vazio

    mov     edx, [rel rx_cur_idx]
    mov     eax, edx
    shl     eax, 4
    lea     rbx, [rel rx_descs]
    add     rbx, rax

    test    byte [rbx + 12], 1      ; Descriptor Done (DD)?
    jz      .vazio

    movzx   ecx, word [rbx + 8]     ; tamanho recebido
    cmp     ecx, 1518
    jbe     .tam_ok
    mov     ecx, 1518
.tam_ok:
    mov     eax, edx
    imul    eax, PKT_BUF_SIZE
    lea     rsi, [rel rx_buffers]
    add     rsi, rax

    mov     eax, ecx                ; guarda retorno em RAX
    rep     movsb

    add     [rel rx_total_bytes], rax
    mov     byte [rbx + 12], 0      ; limpa status DD

    ; Devolve descritor ao hardware (RDT)
    mov     rsi, [rel e1000_mmio_base]
    mov     [rsi + E1000_REG_RDT], edx
    inc     edx
    and     edx, NUM_RX_DESC - 1
    mov     [rel rx_cur_idx], edx
    jmp     .fim

.vazio:
    xor     rax, rax

.fim:
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret
