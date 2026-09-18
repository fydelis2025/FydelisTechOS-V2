; ======================================
; RealSoft OS — Driver de Áudio (Completo)
; Usa funções de vídeo do kernel (sem int 0x10)
; ======================================
BITS 64
%include "../inc/fydelterm.inc"

extern print_string, print_newline, print_char
extern argc, argv

AUDIO_BASE_AC97     equ 0x100000
AUDIO_BASE_HDA      equ 0x400000

AC97_RESET          equ 0x00
AC97_MASTER_VOL     equ 0x02
AC97_POWERDOWN      equ 0x26
HDA_GCTL            equ 0x08
HDA_CMD             equ 0x40

AUDIO_VOLUME_MAX    equ 31
AUDIO_VOLUME_DEF    equ 15

section .data
align 16
msg_audio_ok:   db 'Controlador de audio: ',0
msg_audio_no:   db 'Controlador de audio nao detectado',0
msg_vol_ok:     db 'Volume definido: ',0
msg_mute_on:    db 'Audio: MUDO',0
msg_mute_off:   db 'Audio: Ativo',0
msg_ac97:       db 'AC97 (Legado)',0
msg_hda:        db 'Intel HDA (HD Audio)',0
msg_playing:    db 'Reproduzindo...',0
msg_not_supp:   db 'Recurso em desenvolvimento',0
msg_bt_no:      db 'Bluetooth: Nao suportado',0
ajuda_vol:      db 'vol [0-31] - Ajusta volume',0

audio_type:     dd 0
audio_volume:   db AUDIO_VOLUME_DEF
audio_muted:    db 0
bt_present:     db 0

section .text
global audio_init, audio_status, audio_set_volume, audio_mute_toggle, bt_init
global do_audio, do_vol, do_mute, do_sound, do_bt, do_bt_scan, do_bt_pair
global print_dec, str_to_int

; --------------------------------------
; Inicialização
; --------------------------------------
audio_init:
    push rax
    push rdx

    mov eax, [VIDEO_TEXT_BASE + 0x4000]
    cmp eax, 0x44434148
    je  .init_hda

    mov dx, AUDIO_BASE_AC97 + AC97_RESET
    in  ax, dx
    cmp ax, 0
    je  .init_ac97

    mov byte [audio_type], 0
    jmp .fim

.init_ac97:
    mov byte [audio_type], 1
    mov dx, AUDIO_BASE_AC97 + AC97_POWERDOWN
    mov ax, 0x0000
    out dx, ax
    jmp .fim

.init_hda:
    mov byte [audio_type], 2
    mov eax, 1
    mov [AUDIO_BASE_HDA + HDA_GCTL], eax
.fim:
    pop rdx
    pop rax
    ret

; --------------------------------------
; Status
; --------------------------------------
audio_status:
    mov rsi, msg_audio_ok
    call print_string

    cmp byte [audio_type], 1
    je  .tipo_ac97
    cmp byte [audio_type], 2
    je  .tipo_hda
    mov rsi, msg_audio_no
    jmp .exibe
.tipo_ac97:
    mov rsi, msg_ac97
    jmp .exibe
.tipo_hda:
    mov rsi, msg_hda
.exibe:
    call print_string
    call print_newline

    cmp byte [audio_muted], 1
    je  .exibe_mudo
    mov rsi, msg_vol_ok
    call print_string
    movzx rdi, byte [audio_volume]
    call print_dec
    call print_newline
    ret
.exibe_mudo:
    mov rsi, msg_mute_on
    call print_string
    call print_newline
    ret

; --------------------------------------
; Volume (rdi = 0-31)
; --------------------------------------
audio_set_volume:
    cmp rdi, AUDIO_VOLUME_MAX
    jbe .aplica
    mov rdi, AUDIO_VOLUME_MAX
.aplica:
    mov [audio_volume], dil
    mov byte [audio_muted], 0
    ret

audio_mute_toggle:
    xor byte [audio_muted], 1
    ret

bt_init:
    mov byte [bt_present], 0
    ret

; --------------------------------------
; COMANDOS DO TERMINAL
; --------------------------------------
do_audio:
    call audio_status
    ret

do_vol:
    mov rax, [argc]
    cmp rax, 2
    jl  .uso
    mov rdi, [argv + 8]
    call str_to_int
    mov rdi, rax
    call audio_set_volume
    mov rsi, msg_vol_ok
    call print_string
    movzx rdi, byte [audio_volume]
    call print_dec
    call print_newline
    ret
.uso:
    mov rsi, ajuda_vol
    call print_string
    call print_newline
    ret

do_mute:
    call audio_mute_toggle
    cmp byte [audio_muted], 1
    je  .sim
    mov rsi, msg_mute_off
    jmp .fim
.sim:
    mov rsi, msg_mute_on
.fim:
    call print_string
    call print_newline
    ret

do_sound:
    mov rsi, msg_playing
    call print_string
    call print_newline
    mov rsi, msg_not_supp
    call print_string
    call print_newline
    ret

do_bt:
    mov rsi, msg_bt_no
    call print_string
    call print_newline
    ret

do_bt_scan:
    mov rsi, msg_not_supp
    call print_string
    call print_newline
    ret

do_bt_pair:
    mov rsi, msg_not_supp
    call print_string
    call print_newline
    ret

; ======================================
; AUXILIARES
; ======================================
str_to_int:
    ; RDI = string → RAX = inteiro
    xor rax, rax
    xor rcx, rcx
.loop:
    mov cl, [rdi]
    cmp cl, '0'
    jb  .fim
    cmp cl, '9'
    ja  .fim
    sub cl, '0'
    imul rax, 10
    add rax, rcx
    inc rdi
    jmp .loop
.fim:
    ret

print_dec:
    ; RDI = inteiro → imprime em decimal
    push rbx
    push rdx
    push rax
    mov rax, rdi
    mov rbx, 10
    push 10
.div:
    xor rdx, rdx
    div rbx
    add dl, '0'
    push rdx
    test rax, rax
    jnz .div
.imp:
    pop rdx
    cmp rdx, 10
    je  .fim
    mov al, dl
    call print_char
    jmp .imp
.fim:
    pop rax
    pop rdx
    pop rbx
    ret
