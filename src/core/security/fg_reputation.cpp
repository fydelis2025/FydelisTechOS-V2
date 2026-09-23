#include "fg_reputation.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

ReputationDB& ReputationDB::instancia() {
    static ReputationDB inst;
    return inst;
}

ReputationDB::ReputationDB() {}

int ReputationDB::pontuacaoIP(const QHostAddress& ip) const {
    QMutexLocker locker(&m_mutex);
    if (!m_dados.contains(ip)) return 0;
    return m_dados[ip].pontuacao;
}

void ReputationDB::registrarAcessoBom(const QHostAddress& ip) {
    QMutexLocker locker(&m_mutex);
    RegistroReputacao& reg = m_dados[ip];
    reg.acessosBons++;
    reg.pontuacao = qBound(-100, reg.pontuacao + 2, 100);
    reg.ultimaAtividade = QDateTime::currentDateTime();
}

void ReputationDB::registrarAcessoRuim(const QHostAddress& ip, FGBlockReason motivo) {
    QMutexLocker locker(&m_mutex);
    RegistroReputacao& reg = m_dados[ip];
    reg.acessosRuins++;
    reg.motivos.insert(motivo);
    reg.pontuacao = qBound(-100, reg.pontuacao - 10, 100);
    reg.ultimaAtividade = QDateTime::currentDateTime();
}

void ReputationDB::definirPontuacaoManual(const QHostAddress& ip, int valor) {
    QMutexLocker locker(&m_mutex);
    m_dados[ip].pontuacao = qBound(-100, valor, 100);
}

bool ReputationDB::carregar(const QString& caminho) {
    QFile arq(caminho);
    if (!arq.open(QIODevice::ReadOnly)) return false;
    QJsonDocument doc = QJsonDocument::fromJson(arq.readAll());
    if (!doc.isObject()) return false;

    QMutexLocker locker(&m_mutex);
    m_dados.clear();
    QJsonObject obj = doc.object();
    for (const QString& ipStr : obj.keys()) {
        QHostAddress ip(ipStr);
        QJsonObject reg = obj[ipStr].toObject();
        RegistroReputacao& r = m_dados[ip];
        r.pontuacao = reg["pontuacao"].toInt();
        r.acessosBons = reg["acessosBons"].toInt();
        r.acessosRuins = reg["acessosRuins"].toInt();
    }
    return true;
}

bool ReputationDB::salvar(const QString& caminho) {
    QJsonObject obj;
    QMutexLocker locker(&m_mutex);
    for (auto it = m_dados.begin(); it != m_dados.end(); ++it) {
        QJsonObject reg;
        reg["pontuacao"] = it.value().pontuacao;
        reg["acessosBons"] = it.value().acessosBons;
        reg["acessosRuins"] = it.value().acessosRuins;
        obj[it.key().toString()] = reg;
    }
    QFile arq(caminho);
    if (!arq.open(QIODevice::WriteOnly)) return false;
    arq.write(QJsonDocument(obj).toJson());
    return true;
}