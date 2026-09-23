#include "fydelispanic_excecao.h"   // ✅ Adicionar esta linha!
#include "fydelispanic.h"
#include <QString>
#include <QStringList>

// ==========================================
// 📋 Nome amigável de cada exceção
// ==========================================
static const char* nomeExcecao(int vetor) {
    switch(vetor) {
        case 0:  return "Divisão por Zero (#DE)";
        case 1:  return "Exceção de Depuração (#DB)";
        case 2:  return "Interrupção Não Mascarável (NMI)";
        case 3:  return "Ponto de Parada (#BP)";
        case 4:  return "Estouro de Ponto Flutuante (#OF)";
        case 5:  return "Limite de Vetor Excedido (#BR)";
        case 6:  return "Instrução Inválida (#UD)";
        case 7:  return "Coprocessador Indisponível (#NM)";
        case 8:  return "Falha Dupla (#DF) — Sério!";
        case 10: return "Erro de Seletor de Tarefa (#TS)";
        case 11: return "Segmento Não Presente (#NP)";
        case 12: return "Falha na Pilha (#SS)";
        case 13: return "Violação de Proteção Geral (#GP)";
        case 14: return "Falha de Página (#PF)";
        case 16: return "Erro de Aritmética de Ponto Flutuante (#MF)";
        case 17: return "Verificação de Alinhamento (#AC)";
        case 18: return "Erro de Máquina (#MC)";
        case 19: return "Exceção SIMD/XMM (#XF)";
        default: return "Exceção Desconhecida";
    }
}

// ==========================================
// 🔔 PONTO DE ENTRADA — Chamado do Assembly
// ==========================================
extern "C" {
    void fydelis_panic_excecao(RegsContexto* regs) {
        QString codigo = QString("0x%1").arg(regs->vetor_excecao, 4, 16, QChar('0'));
        QString erro = QString::fromUtf8(nomeExcecao(static_cast<int>(regs->vetor_excecao)));

        // Detalhe especial para Falha de Página — endereço que causou o erro
        QString detalheExtra;
        if (regs->vetor_excecao == 14) {
            detalheExtra = QString(" — Endereço acessado: 0x%1").arg(regs->error_code, 0, 16);
        }

        // Montar dump completo dos registradores
        QStringList pilha;
        pilha << "=== REGISTRADORES DA CPU ===";
        pilha << QString("RAX=0x%1  RBX=0x%2  RCX=0x%3  RDX=0x%4")
            .arg(regs->rax, 0, 16).arg(regs->rbx, 0, 16)
            .arg(regs->rcx, 0, 16).arg(regs->rdx, 0, 16);
        pilha << QString("RSI=0x%1  RDI=0x%2  RBP=0x%3  RSP=0x%4")
            .arg(regs->rsi, 0, 16).arg(regs->rdi, 0, 16)
            .arg(regs->rbp, 0, 16).arg(regs->rsp, 0, 16);
        pilha << QString("R8 =0x%1  R9 =0x%2  R10=0x%3  R11=0x%4")
            .arg(regs->r8, 0, 16).arg(regs->r9, 0, 16)
            .arg(regs->r10, 0, 16).arg(regs->r11, 0, 16);
        pilha << QString("R12=0x%1  R13=0x%2  R14=0x%3  R15=0x%4")
            .arg(regs->r12, 0, 16).arg(regs->r13, 0, 16)
            .arg(regs->r14, 0, 16).arg(regs->r15, 0, 16);
        pilha << QString("RIP=0x%1  RFLAGS=0x%2  Código Erro=0x%3")
            .arg(regs->rip, 0, 16).arg(regs->rflags, 0, 16).arg(regs->error_code, 0, 16);

        // Disparar a tela visual de Panic!
        FydelisPanic::instancia().definirProcesso("Kernel — Exceção da CPU");
        FydelisPanic::instancia().disparar(
            codigo,
            erro + detalheExtra,
            "Núcleo do Sistema / CPU",
            QString("0x%1").arg(regs->rip, 0, 16),
            pilha
        );
    }
}