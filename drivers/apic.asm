; ==========================================
; APIC.ASM — Controlador de Interrupções
; Local APIC + IOAPIC
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================

; ✅ Funções exportadas
global apic_detect
global apic_inicializar
global ioapic_redirecionar_irq
global apic_enviar_eoi
global apic_get_ok

BITS 64
%include "fydelterm.inc"   ; ✅ Puxa todas as constantes automaticamente


; Variáveis
section .bss
align 4096
apic_ptr:          resq 1
ioapic_ptr:        resq 1
apic_ok:           resd 1

; Código
section .text

; ==========================================
; 🔍 DETECTAR SUPORTE AO APIC NA CPU
; Retorna: rax = 1 se tem, 0 se não
; ==========================================
apic_detect:
    push   rcx
    push   rdx

    mov    ecx, 1
    cpuid
    test   edx, 1 << 9       ; Bit 9 = APIC disponível
    jz     .nao_tem

    pop    rdx
    pop    rcx
    mov    rax, 1
    ret

.nao_tem:
    pop    rdx
    pop    rcx
    xor    rax, rax
    ret

; ==========================================
; ⚡ HABILITAR APIC
; Desativa PIC legado → ativa APIC → configura SVR
; ==========================================
apic_inicializar:
    push   rax
    push   rcx
    push   rdx
    push   rdi

    ; Desligar PIC legado (8259A) — mascara todas IRQs
    mov    al, 0xFF
    out    0xA1, al
    out    0x21, al

    ; Ler e ativar APIC no MSR
    mov    ecx, 0x1B         ; IA32_APIC_BASE
    rdmsr
    bts    edx, 8            ; Bit 8 = APIC Global Enable
    wrmsr

    ; Salvar endereços base
    mov    rax, APIC_BASE_PHYS
    mov    [apic_ptr], rax
    mov    rax, IOAPIC_BASE_PHYS
    mov    [ioapic_ptr], rax
    mov    dword [apic_ok], 1

    ; Habilitar APIC no SVR (Spurious Vector Register)
    mov    rdi, [apic_ptr]
    mov    dword [rdi + APIC_SVR], 0x1000 | 0xFF

    pop    rdi
    pop    rdx
    pop    rcx
    pop    rax
    ret

; ==========================================
; 🔄 REDIRECIONAR IRQ PARA VETOR
; Entrada: rdi = IRQ (0-23), rsi = vetor (32-255)
; Saída: rax = 1 sucesso, 0 falha
; ==========================================
ioapic_redirecionar_irq:
    push   rdx
    push   r8
    push   r9
    push   rdi

    ; Verificar se APIC está ativo
    cmp    dword [apic_ok], 1
    jne    .falha

    ; Validar faixa de IRQ
    cmp    rdi, 24
    jae    .falha

    ; Calcular: registrador = IRQ × 2
    mov    rax, rdi
    shl    rax, 1
    mov    r9, rax

    ; Escrever entrada BAIXA (vetor + flags)
    mov    rdi, [ioapic_ptr]
    mov    edx, r9d
    mov    [rdi + IOAPIC_REG_SEL], edx
    mov    r8, rsi
    and    r8, 0xFF
    mov    [rdi + IOAPIC_REG_DATA], r8d

    ; Escrever entrada ALTA = CPU 0
    inc    edx
    mov    [rdi + IOAPIC_REG_SEL], edx
    mov    [rdi + IOAPIC_REG_DATA], dword 0

    pop    rdi
    pop    r9
    pop    r8
    pop    rdx
    mov    rax, 1
    ret

.falha:
    pop    rdi
    pop    r9
    pop    r8
    pop    rdx
    xor    rax, rax
    ret

; ==========================================
; ✅ ENVIAR FIM DE INTERRUPÇÃO (EOI)
; ==========================================
apic_enviar_eoi:
    cmp    dword [apic_ok], 1
    jne    .picoi

    mov    rax, [apic_ptr]
    mov    dword [rax + APIC_EOI], 0
    ret

.picoi:
    ; Fallback para PIC legado
    push   rax
    mov    al, 0x20
    out    0x20, al
    out    0xA0, al
    pop    rax
    ret

; ==========================================
; ✅ VERIFICAR SE APIC ESTÁ ATIVO
; ==========================================
apic_get_ok:
    mov    eax, [apic_ok]
    ret
