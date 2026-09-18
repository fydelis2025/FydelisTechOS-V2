; ==========================================
; FYDELIS TECH OS — memmap.asm
; Detecção e Gerenciamento de Memória
; De Salvador • Bahia 🇧🇷
; ==========================================
bits 64

section .data
mem_total       dq 0        ; Memória total em bytes
mem_usado       dq 0        ; Em uso pelo kernel
mem_livre       dq 0        ; Disponível para programas

section .text
global mem_detect_e820
global mem_get_total
global mem_get_free

; ==========================================
; 🔍 LER MAPA DE MEMÓRIA (E820 — da BIOS/UEFI)
; ==========================================
mem_detect_e820:
    ; No modo longo (64 bits), assumimos que bootloader já passou o mapa
    ; Aqui apenas processamos e calculamos totais
    push rbx
    push rcx
    push rdx

    ; Percorrer tabela E820 passada pelo bootloader
    ; Endereço padrão: 0x100000 (ajuste conforme seu bootloader)
    mov rsi, 0x100000
    xor rcx, rcx
    xor rdx, rdx        ; Total livre

mem_loop:
    cmp rcx, 0x100      ; Máximo 256 entradas
    jae mem_done

    ; Ler entrada: endereço, tamanho, tipo
    mov rax, [rsi + 16] ; Tipo: 1 = Livre, 2 = Reservado
    cmp rax, 1
    jne mem_next

    ; Área livre — somar
    mov rax, [rsi + 8]  ; Tamanho
    add rdx, rax

mem_next:
    add rsi, 32         ; Próxima entrada
    inc rcx
    cmp dword [rsi], 0  ; Fim da lista
    jne mem_loop

mem_done:
    mov [mem_livre], rdx
    mov rax, 0x80000000 ; Estimativa: 2GB mínima (ajuste com valores reais)
    mov [mem_total], rax
    mov [mem_usado], rax
    sub [mem_usado], rdx

    pop rdx
    pop rcx
    pop rbx
    ret

; ==========================================
; 📋 RETORNAR TOTAIS
; ==========================================
mem_get_total:
    mov rax, [mem_total]
    ret

mem_get_free:
    mov rax, [mem_livre]
    ret