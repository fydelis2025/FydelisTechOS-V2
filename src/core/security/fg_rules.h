#ifndef FG_RULES_H
#define FG_RULES_H

#include "fg_packet.h"
#include <QString>
#include <QVariantMap>

// ==========================================
// 📜 FG_RULES — Motor de Regras de Detecção
// ==========================================

class FGRules {
public:
    static FGRules& instancia();

    void carregarRegras(const QString& caminhoArquivo = QString());
    FGVerdeito aplicarRegras(const FGPacoteInfo& pacote);

    // ⚙️ Valores de configuração das regras
    int limiteSaltos() const;
    int limitePacotesPorMinuto() const;
    qint64 tamanhoMaximoPacote() const;
    bool exigirAssinatura() const;
    QStringList protocolosPermitidos() const;

    void definirLimiteSaltos(int valor);
    void definirExigirAssinatura(bool sim);

private:
    FGRules();
    QVariantMap m_regras;
    void carregarRegrasPadrao();
};

#endif // FG_RULES_H