#ifndef FG_REPUTATION_H
#define FG_REPUTATION_H

#include "fg_packet.h"
#include <QHostAddress>
#include <QMap>
#include <QDateTime>
#include <QSet>

// ==========================================
// ⭐ FG_REPUTATION — Banco de Reputação
// ==========================================

class ReputationDB {
public:
    static ReputationDB& instancia();

    // ⭐ Pontuação: 100 = confiança máxima, 0 = neutro, -100 = bloqueado
    int pontuacaoIP(const QHostAddress& ip) const;

    // 📊 Atualizar reputação
    void registrarAcessoBom(const QHostAddress& ip);
    void registrarAcessoRuim(const QHostAddress& ip, FGBlockReason motivo);
    void definirPontuacaoManual(const QHostAddress& ip, int valor);

    // ⚙️ Limiares
    static constexpr int LIMIAR_BLOQUEIO = -50;
    static constexpr int LIMIAR_ALERTA = -20;
    static constexpr int LIMIAR_CONFIANCA = 50;

    // 💾 Persistência
    bool carregar(const QString& caminho);
    bool salvar(const QString& caminho);

private:
    ReputationDB();
    struct RegistroReputacao {
        int pontuacao = 0;
        int acessosBons = 0;
        int acessosRuins = 0;
        QDateTime ultimaAtividade;
        QSet<FGBlockReason> motivos;
    };

    QMap<QHostAddress, RegistroReputacao> m_dados;
    mutable QMutex m_mutex;
};

#endif // FG_REPUTATION_H