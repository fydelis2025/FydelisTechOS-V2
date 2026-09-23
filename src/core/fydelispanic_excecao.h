#ifndef FYDELISPANIC_EXCECAO_H
#define FYDELISPANIC_EXCECAO_H

// ==========================================
// FYDELISPANIC_EXCECAO — Cabeçalho
// Conecta Assembly → Tela de Erro Visual
// FydelisTech OS v2.0 · Salvador • Bahia 🇧🇷
// ==========================================

#ifdef __cplusplus
extern "C" {
#endif

// Estrutura recebida do Assembly (isr_comum)
struct RegsContexto {
    unsigned long long rax, rbx, rcx, rdx;
    unsigned long long rsi, rdi, rbp, rsp;
    unsigned long long r8, r9, r10, r11;
    unsigned long long r12, r13, r14, r15;
    unsigned long long rip;
    unsigned long long rflags;
    unsigned long long error_code;
    unsigned long long vetor_excecao;
};

// Chamado diretamente do Assembly em idt.asm
void fydelis_panic_excecao(struct RegsContexto* registros);

#ifdef __cplusplus
}
#endif

#endif // FYDELISPANIC_EXCECAO_H