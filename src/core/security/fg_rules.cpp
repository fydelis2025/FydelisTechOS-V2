#include "fg_rules.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

FGRules& FGRules::instancia() {
    static FGRules inst;
    return inst;
}

FGRules::FGRules() {
    carregarRegrasPadrao();
}

void FGRules::carregarRegrasPadrao() {
    m_regras["limiteSaltos"] = 3;
    m_regras["limitePacotesPorMinuto"] = 60;
    m_regras["tamanhoMaximoBytes"] = 1048576; // 1MB
    m_regras["exigirAssinatura"] = false;
    m_regras["protocolosPermitidos"] = QStringList() << "TCP" << "UDP" << "WebSocket" << "Fydelis";
    m_regras["limiteHorarioInicio"] = 6;  // 06:00
    m_regras["limiteHorarioFim"] = 23;    // 23:00
}

void FGRules::carregarRegras(const QString& caminhoArquivo) {
    if (caminhoArquivo.isEmpty()) {
        carregarRegrasPadrao();
        return;
    }
    QFile arq(caminhoArquivo);
    if (arq.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(arq.readAll());
        if (doc.isObject()) {
            m_regras = doc.object().toVariantMap();
            return;
        }
    }
    carregarRegrasPadrao();
}

FGVerdeito FGRules::aplicarRegras(const FGPacoteInfo& pacote) {
    if (pacote.saltos > limiteSaltos())
        return FGVerdeito::Desafiar;

    if (pacote.tamanhoBytes > tamanhoMaximoPacote())
        return FGVerdeito::Quarentena;

    if (exigirAssinatura() && !pacote.temAssinatura)
        return FGVerdeito::Bloquear;

    QStringList permitidos = protocolosPermitidos();
    if (!permitidos.contains(pacote.protocolo) && !pacote.protocolo.isEmpty())
        return FGVerdeito::Desafiar;

    return FGVerdeito::Permitir;
}

int FGRules::limiteSaltos() const { return m_regras["limiteSaltos"].toInt(); }
int FGRules::limitePacotesPorMinuto() const { return m_regras["limitePacotesPorMinuto"].toInt(); }
qint64 FGRules::tamanhoMaximoPacote() const { return m_regras["tamanhoMaximoBytes"].toLongLong(); }
bool FGRules::exigirAssinatura() const { return m_regras["exigirAssinatura"].toBool(); }
QStringList FGRules::protocolosPermitidos() const { return m_regras["protocolosPermitidos"].toStringList(); }

void FGRules::definirLimiteSaltos(int valor) { m_regras["limiteSaltos"] = valor; }
void FGRules::definirExigirAssinatura(bool sim) { m_regras["exigirAssinatura"] = sim; }