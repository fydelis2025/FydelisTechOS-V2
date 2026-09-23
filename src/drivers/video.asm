; ======================================
; Video Driver FydelTerm (Corrigido)
; Modo Texto 80×25 · Acesso Direto VRAM
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

section .bss
cursor_pos     resq 1
input_base_pos resq 1   ; Trava para impedir apagar o prompt

section .text
global clear_screen, print_string, print_char, print_newline, set_input_base, move_cursor, update_cursor

; --- Imprime AL ---
print_char:
    push      rax
    push      rbx
    push      rcx
    push      rdi
    push      rdx

    cmp       al, KEY_ENTER
    je        .nova_linha
    cmp       al, KEY_BACKSPACE
    je        .apaga

    mov       rdi, [cursor_pos]
    mov       rbx, VIDEO_TEXT_BASE
    shl       rdi, 1
    mov       ah, DEF_ATTR  
    mov       [rbx + rdi], ax
    inc       qword [cursor_pos]
    jmp       .verifica_rolagem

.apaga:
    ; Impede apagar se o cursor estiver na base do prompt ou antes
    mov       rax, [input_base_pos]
    cmp       qword [cursor_pos], rax
    jle       .fim
    
    dec       qword [cursor_pos]
    mov       rbx, VIDEO_TEXT_BASE
    mov       rdi, [cursor_pos]
    shl       rdi, 1
    mov       word [rbx + rdi], ' ' | (DEF_ATTR << 8)
    jmp       .atualiza_cursor_fim

.nova_linha:
    mov       rax, [cursor_pos]
    xor       rdx, rdx
    mov       rcx, 80
    div       rcx            ; RAX = linha atual, RDX = coluna atual
    inc       rax            ; Próxima linha
    mul       rcx            ; RAX = Nova posição (Linha * 80)
    mov       [cursor_pos], rax
    jmp       .verifica_rolagem

.verifica_rolagem:
    cmp       qword [cursor_pos], 80*25
    jl        .atualiza_cursor_fim
    call      scroll_up
    mov       qword [cursor_pos], 80*24

.atualiza_cursor_fim:
    call      update_cursor

.fim:
    pop       rdx
    pop       rdi
    pop       rcx
    pop       rbx
    pop       rax
    ret

; --- Define onde o usuário pode apagar (fim do prompt) ---
set_input_base:
    mov       rax, [cursor_pos]
    mov       [input_base_pos], rax
    ret

; --- Alias para satisfazer o editor.asm ---
move_cursor:
    call      update_cursor
    ret

; --- Atualiza o Cursor Físico da VGA ---
update_cursor:
    push      rax
    push      rbx
    push      rdx

    ; Envia byte baixo do cursor
    mov       dx, 0x3D4
    mov       al, 0x0F
    out       dx, al
    mov       dx, 0x3D5
    mov       al, [cursor_pos]
    out       dx, al

    ; Envia byte alto do cursor
    mov       dx, 0x3D4
    mov       al, 0x0E
    out       dx, al
    mov       dx, 0x3D5
    mov       rax, [cursor_pos]
    shr       rax, 8
    out       dx, al

    pop       rdx
    pop       rbx
    pop       rax
    ret

; --- Imprime string RSI ---
print_string:
    push      rax
    push      rsi
.prox:
    lodsb
    test      al, al
    jz        .fim_str
    call      print_char
    jmp       .prox
.fim_str:
    pop       rsi
    pop       rax
    ret

; --- Nova Linha ---
print_newline:
    push      rax
    mov       al, KEY_ENTER
    call      print_char
    pop       rax
    ret

; --- Limpa Tela ---
clear_screen:
    push      rax
    push      rcx
    push      rdi
    mov       rdi, VIDEO_TEXT_BASE
    mov       rcx, 80*25
    mov       rax, ' ' | (DEF_ATTR << 8)
    rep       stosw
    mov       qword [cursor_pos], 0
    mov       qword [input_base_pos], 0
    call      update_cursor
    pop       rdi
    pop       rcx
    pop       rax
    ret

; --- Rola tela 1 linha ---
scroll_up:
    push      rcx
    push      rsi
    push      rdi
    mov       rsi, VIDEO_TEXT_BASE + 80*2
    mov       rdi, VIDEO_TEXT_BASE
    mov       rcx, 80*24
    rep       movsw
    mov       rcx, 80
    mov       rax, ' ' | (DEF_ATTR << 8)
    rep       stosw
    pop       rdi
    pop       rsi
    pop       rcx
    ret
