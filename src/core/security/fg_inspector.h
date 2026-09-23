#ifndef FG_INSPECTOR_H
#define FG_INSPECTOR_H

#include "fg_packet.h"
#include <QString>

// ==========================================
// 🔍 FG_INSPECTOR — Inspetor de Protocolo
// ==========================================

class FGInspector {
public:
    static bool detectarSpoofing(const FGPacoteInfo& pacote);
    static bool protocoloAnomalo(const FGPacoteInfo& pacote);
    static bool certificadoInvalido(const FGPacoteInfo& pacote);
    static bool verificarAssinatura(const FGPacoteInfo& pacote);

    // 🧬 Impressão digital do protocolo
    static QString gerarImpressaoDigital(const FGPacoteInfo& pacote);

private:
    static bool ipPrivadoOuLocal(const QHostAddress& ip);
    static bool faixaSuspeita(const QHostAddress& ip);
};

#endif // FG_INSPECTOR_H