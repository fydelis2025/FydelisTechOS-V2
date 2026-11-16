; ==========================================
; CPU.ASM — Detecção e Inicialização da CPU
; Verifica 64 bits, recursos e suportes
; FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
; ==========================================
bits 64

section .text
global cpu_verificar
global cpu_tem_64bits
global cpu_tem_apic
global cpu_tem_sse
global cpu_tem_avx
global cpu_nome

; ==========================================
; 🔍 VERIFICAR SUPORTE BÁSICO
; ==========================================
cpu_verificar:
    push rbx

    ; Verificar se CPUID está disponível
    pushfq
    pushfq
    xor qword [rsp], 1 << 21    ; Alternar bit ID
    popfq
    pushfq
    pop rax
    xor rax, [rsp]
    jz .sem_cpuid

    ; Máximo nível de CPUID
    xor rax, rax
    cpuid
    cmp rax, 1
    jb .erro

    ; Recursos padrão (função 1)
    mov rax, 1
    cpuid
    mov dword [cpu_features_edx], edx
    mov dword [cpu_features_ecx], ecx

    ; Nome do fornecedor
    mov rax, 0
    cpuid
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx

    ; Recursos estendidos
    mov rax, 0x80000000
    cpuid
    cmp rax, 0x80000008
    jb .sem_extended
    mov dword [cpu_max_ext], eax

    ; Verificar 64 bits
    mov rax, 0x80000001
    cpuid
    mov dword [cpu_ext_features], edx

.sem_extended:
    pop rbx
    mov rax, 1       ; ✅ CPU compatível
    ret

.sem_cpuid:
.erro:
    pop rbx
    xor rax, rax     ; ❌ CPU incompatível
    ret

; ==========================================
; ✅ TEM SUPORTE A 64 BITS?
; ==========================================
cpu_tem_64bits:
    mov rax, [cpu_ext_features]
    bt rax, 29       ; Bit 29 = LM (Long Mode)
    jc .sim
    xor rax, rax
    ret
.sim:
    mov rax, 1
    ret

; ==========================================
; ✅ TEM APIC?
; ==========================================
cpu_tem_apic:
    mov rax, [cpu_features_edx]
    bt rax, 9        ; Bit 9 = APIC presente
    jc .sim
    xor rax, rax
    ret
.sim:
    mov rax, 1
    ret

; ==========================================
; ✅ TEM SSE / SSE2?
; ==========================================
cpu_tem_sse:
    mov rax, [cpu_features_edx]
    bt rax, 25       ; SSE
    jc .sse2
    xor rax, rax
    ret
.sse2:
    bt rax, 26       ; SSE2
    jc .sim
    xor rax, rax
    ret
.sim:
    mov rax, 1
    ret

; ==========================================
; ✅ TEM AVX?
; ==========================================
cpu_tem_avx:
    mov rax, [cpu_features_ecx]
    bt rax, 28       ; AVX
    jc .sim
    xor rax, rax
    ret
.sim:
    mov rax, 1
    ret

; ==========================================
; ✅ RETORNAR NOME DO FORNECEDOR
; Ponteiro para 12 bytes: "GenuineIntel" ou "AuthenticAMD"
; ==========================================
cpu_nome:
    mov rax, cpu_vendor
    ret

; ==========================================
; 📋 DADOS INTERNOS
; ==========================================
section .bss
align 4
cpu_features_edx: resd 1
cpu_features_ecx: resd 1
cpu_ext_features: resq 1
cpu_max_ext:      resd 1
cpu_vendor:       resb 12