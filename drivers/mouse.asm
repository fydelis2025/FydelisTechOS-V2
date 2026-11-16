; ==========================================
; 🖱️ MOUSE.ASM — DRIVER PS/2 · v4.2 (VESA Framebuffer)
; À Prova de Falhas · Máquina de Estado 3 Bytes
; FydelisTech OS · Salvador • Bahia
; ==========================================
BITS 64
default rel
%include "fydelterm.inc"

extern fb_largura
extern fb_altura

; ========== PORTAS E COMANDOS ==========
MOUSE_DATA_PORT      equ 0x60
MOUSE_CMD_PORT       equ 0x64
MOUSE_WRITE_AUX      equ 0xD4
MOUSE_ENABLE_DEV2    equ 0xA8
MOUSE_READ_CONFIG    equ 0x20
MOUSE_WRITE_CONFIG   equ 0x60
MOUSE_SET_SAMPLE     equ 0xF3
MOUSE_ENABLE         equ 0xF4
MOUSE_SET_DEFAULTS   equ 0xF6
MOUSE_ACK            equ 0xFA

; ========== BOTÕES ==========
MOUSE_ESQ            equ 0b00000001
MOUSE_DIR            equ 0b00000010
MOUSE_MEIO           equ 0b00000100

; ========== LIMITE DE SEGURANÇA ==========
MAX_TENTATIVAS       equ 50000

; ========== DADOS ==========
section .bss
align 16
mouse_x:             resd 1
mouse_y:             resd 1
mouse_botoes:        resd 1
mouse_ciclo:         resb 1      ; 0, 1 ou 2
mouse_pacote:        resb 3
mouse_inicializado:  resb 1

section .text
global mouse_detectar
global mouse_inicializar
global mouse_ler_posicao
global mouse_ler_botoes
global mouse_definir_posicao
global mouse_tratar_irq

; ==========================================
; 📤 ENVIAR COMANDO AO MOUSE (com prefixo 0xD4)
; Entrada: AL = comando | Saída: CF=1 se erro, AL = resposta
; ==========================================
mouse_enviar_comando:
    push    rbx
    mov     bl, al

    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_escrita_seguro
    jc      .falha
    mov     al, MOUSE_WRITE_AUX
    out     MOUSE_CMD_PORT, al

    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_escrita_seguro
    jc      .falha
    mov     al, bl
    out     MOUSE_DATA_PORT, al

    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_leitura_seguro
    jc      .falha
    in      al, MOUSE_DATA_PORT
    clc
    pop     rbx
    ret

.falha:
    stc
    pop     rbx
    ret

; ==========================================
; 🔍 DETECTAR — com limite de segurança
; ==========================================
mouse_detectar:
    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_escrita_seguro
    jc      .nao_encontrado
    mov     al, MOUSE_ENABLE_DEV2
    out     MOUSE_CMD_PORT, al

    mov     al, MOUSE_SET_DEFAULTS
    call    mouse_enviar_comando
    jc      .nao_encontrado
    cmp     al, MOUSE_ACK
    jne     .nao_encontrado

    mov     rax, 1
    ret
.nao_encontrado:
    xor     rax, rax
    ret

; ==========================================
; ✅ INICIALIZAR — seguro e completo
; ==========================================
mouse_inicializar:
    push    rbx

    ; 1. Habilita segunda porta PS/2 (Auxiliar)
    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_escrita_seguro
    jc      .erro
    mov     al, MOUSE_ENABLE_DEV2
    out     MOUSE_CMD_PORT, al

    ; 2. Lê configuração do controlador 8042 e ativa IRQ12 + clock do mouse
    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_escrita_seguro
    jc      .erro
    mov     al, MOUSE_READ_CONFIG
    out     MOUSE_CMD_PORT, al

    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_leitura_seguro
    jc      .erro
    in      al, MOUSE_DATA_PORT
    mov     bl, al
    or      bl, 0x02            ; Habilita IRQ12
    and     bl, ~0x20           ; Habilita clock auxiliar

    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_escrita_seguro
    jc      .erro
    mov     al, MOUSE_WRITE_CONFIG
    out     MOUSE_CMD_PORT, al

    mov     ecx, MAX_TENTATIVAS
    call    io_esperar_escrita_seguro
    jc      .erro
    mov     al, bl
    out     MOUSE_DATA_PORT, al

    ; 3. Restaura padrões e define taxa de amostragem (100 Hz)
    mov     al, MOUSE_SET_DEFAULTS
    call    mouse_enviar_comando
    jc      .erro

    mov     al, MOUSE_SET_SAMPLE
    call    mouse_enviar_comando
    jc      .erro
    mov     al, 100
    call    mouse_enviar_comando
    jc      .erro

    ; 4. Ativa envio contínuo de pacotes (Data Reporting)
    mov     al, MOUSE_ENABLE
    call    mouse_enviar_comando
    jc      .erro

    ; Posição inicial no centro da resolução VESA atual
    mov     eax, [fb_largura]
    test    eax, eax
    jnz     .larg_ok
    mov     eax, 800
.larg_ok:
    shr     eax, 1
    mov     [mouse_x], eax

    mov     eax, [fb_altura]
    test    eax, eax
    jnz     .alt_ok
    mov     eax, 600
.alt_ok:
    shr     eax, 1
    mov     [mouse_y], eax

    mov     dword [mouse_botoes], 0
    mov     byte [mouse_ciclo], 0
    mov     byte [mouse_inicializado], 1

    mov     rax, 1
    pop     rbx
    ret
.erro:
    xor     rax, rax
    pop     rbx
    ret

; ==========================================
; 📍 LER POSIÇÃO — EDI=X, ESI=Y, EAX=Botões
; ==========================================
mouse_ler_posicao:
    call    mouse_tratar_irq        ; Drena qualquer byte pendente no buffer 8042
    mov     edi, [mouse_x]
    mov     esi, [mouse_y]
    mov     eax, [mouse_botoes]
    ret

; ==========================================
; 🖱️ LER BOTÕES — máscara em EAX
; ==========================================
mouse_ler_botoes:
    mov     eax, [mouse_botoes]
    ret

; ==========================================
; ✏️ DEFINIR POSIÇÃO — limitado à resolução VESA
; ==========================================
mouse_definir_posicao:
    mov     [mouse_x], edi
    mov     [mouse_y], esi

    cmp     dword [mouse_x], 0
    jge     .x1
    mov     dword [mouse_x], 0
.x1:
    mov     eax, [fb_largura]
    dec     eax
    cmp     [mouse_x], eax
    jle     .x2
    mov     [mouse_x], eax
.x2:
    cmp     dword [mouse_y], 0
    jge     .y1
    mov     dword [mouse_y], 0
.y1:
    mov     eax, [fb_altura]
    dec     eax
    cmp     [mouse_y], eax
    jle     .y2
    mov     [mouse_y], eax
.y2:
    ret

; ==========================================
; ⚡ PROCESSAR PACOTES PS/2 (IRQ12 ou Polling)
; ==========================================
mouse_tratar_irq:
    push    rax
    push    rbx
    push    rcx
    push    rdx

.proximo_byte:
    in      al, MOUSE_CMD_PORT
    test    al, 0x01                ; Bit 0: buffer de saída cheio?
    jz      .fim
    test    al, 0x20                ; Bit 5: dado veio da porta auxiliar (mouse)?
    jz      .fim

    in      al, MOUSE_DATA_PORT
    movzx   ecx, byte [mouse_ciclo]

    ; Byte 0 sempre possui bit 3 = 1 (garante sincronia)
    test    ecx, ecx
    jnz     .guardar_byte
    test    al, 0x08
    jz      .proximo_byte

.guardar_byte:
    lea     rdx, [mouse_pacote]
    mov     [rdx + rcx], al
    inc     ecx
    cmp     ecx, 3
    jl      .atualizar_ciclo

    ; Pacote de 3 bytes completo!
    mov     byte [mouse_ciclo], 0
    movzx   ebx, byte [mouse_pacote]

    ; Atualiza máscara de botões (bits 0..2)
    mov     eax, ebx
    and     eax, 0b00000111
    mov     [mouse_botoes], eax

    ; Descarta pacote se houver overflow X ou Y
    test    bl, 0xC0
    jnz     .proximo_byte

    ; Delta X com extensão de sinal (bit 4 do Byte 0)
    movzx   eax, byte [mouse_pacote + 1]
    test    bl, 0x10
    jz      .dx_ok
    or      eax, 0xFFFFFF00
.dx_ok:
    add     [mouse_x], eax
    cmp     dword [mouse_x], 0
    jge     .x_max
    mov     dword [mouse_x], 0
.x_max:
    mov     edx, [fb_largura]
    dec     edx
    cmp     [mouse_x], edx
    jle     .calc_y
    mov     [mouse_x], edx

.calc_y:
    ; Delta Y com extensão de sinal (bit 5 do Byte 0, eixo invertido)
    movzx   eax, byte [mouse_pacote + 2]
    test    bl, 0x20
    jz      .dy_ok
    or      eax, 0xFFFFFF00
.dy_ok:
    sub     [mouse_y], eax
    cmp     dword [mouse_y], 0
    jge     .y_max
    mov     dword [mouse_y], 0
.y_max:
    mov     edx, [fb_altura]
    dec     edx
    cmp     [mouse_y], edx
    jle     .proximo_byte
    mov     [mouse_y], edx
    jmp     .proximo_byte

.atualizar_ciclo:
    mov     [mouse_ciclo], cl
    jmp     .proximo_byte

.fim:
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

; ==========================================
; ⏳ ESPERA COM SEGURANÇA — NÃO TRAVA!
; ==========================================
io_esperar_escrita_seguro:
    in      al, MOUSE_CMD_PORT
    test    al, 0b00000010
    jz      .pronto
    pause
    dec     ecx
    jnz     io_esperar_escrita_seguro
    stc
    ret
.pronto:
    clc
    ret

io_esperar_leitura_seguro:
    in      al, MOUSE_CMD_PORT
    test    al, 0b00000001
    jnz     .pronto
    pause
    dec     ecx
    jnz     io_esperar_leitura_seguro
    stc
    ret
.pronto:
    clc
    ret
