#include "cvemonitor.h"
#include <QSqlError>
#include <QDebug>

CVEMonitor& CVEMonitor::instancia() {
    static CVEMonitor inst;
    return inst;
}

CVEMonitor::CVEMonitor() : QObject(nullptr) {}

bool CVEMonitor::inicializar() {
    m_db = QSqlDatabase::addDatabase("QSQLITE", "cve_auditoria");
    m_db.setDatabaseName("FydelisSystem/database/config.db");  // ✅ Mesmo banco do sistema

    if (!m_db.open()) {
        qCritical() << "Banco auditoria não aberto:" << m_db.lastError().text();
        return false;
    }

    criarTabela();
    qInfo() << "🛡️ Auditoria de Segurança — Ativa";
    return true;
}

void CVEMonitor::criarTabela() {
    QSqlQuery q(m_db);
    q.exec(R"(
        CREATE TABLE IF NOT EXISTS auditoria_seguranca (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data_hora TEXT NOT NULL DEFAULT (DATETIME('now', 'localtime')),
            cve_id TEXT NOT NULL,
            risco TEXT NOT NULL,
            modulo_origem TEXT NOT NULL,
            detalhes TEXT NOT NULL,
            acao_tomada TEXT NOT NULL
        )
    )");
}

// ✅ MÉTODO PRINCIPAL — IGUAL AO GEMINI, MAS INTEGRADO COM SINAIS QT
bool CVEMonitor::registrarEvento(const QString& cveId, const QString& risco,
                                   const QString& modulo, const QString& detalhes,
                                   const QString& acao)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO auditoria_seguranca (cve_id, risco, modulo_origem, detalhes, acao_tomada)
        VALUES (?, ?, ?, ?, ?)
    )");
    q.addBindValue(cveId);
    q.addBindValue(risco);
    q.addBindValue(modulo);
    q.addBindValue(detalhes);
    q.addBindValue(acao);

    if (!q.exec()) {
        qCritical() << "Falha ao registrar:" << q.lastError().text();
        return false;
    }

    // 🔔 SE FOR CRÍTICO → DISPARA ALERTA NA TELA AGORA!
    if (risco == "CRITICO") {
        QString mensagem = QString("🚨 AMEAÇA CRÍTICA DETECTADA!\n"
                                   "CVE: %1\n"
                                   "Módulo: %2\n"
                                   "Ação: %3")
            .arg(cveId, modulo, acao);

        emit alertaCritico(cveId, mensagem);
        qCritical() << mensagem;
    }

    emit estatisticasAtualizadas(
        totalPorNivel("CRITICO"),
        totalPorNivel("ALTO"),
        ultimosEventos(1).size()
    );

    return true;
}

int CVEMonitor::totalPorNivel(const QString& risco) const {
    QSqlQuery q(m_db);
    q.prepare("SELECT COUNT(*) FROM auditoria_seguranca WHERE risco = ?");
    q.addBindValue(risco);
    q.exec();
    q.next();
    return q.value(0).toInt();
}

QList<QVariantMap> CVEMonitor::ultimosEventos(int limite) const {
    QList<QVariantMap> lista;
    QSqlQuery q(m_db);
    q.prepare("SELECT data_hora, cve_id, risco, modulo_origem, acao_tomada "
              "FROM auditoria_seguranca ORDER BY id DESC LIMIT ?");
    q.addBindValue(limite);
    q.exec();

    while (q.next()) {
        QVariantMap reg;
        reg["data"] = q.value(0).toString();
        reg["cve"] = q.value(1).toString();
        reg["risco"] = q.value(2).toString();
        reg["modulo"] = q.value(3).toString();
        reg["acao"] = q.value(4).toString();
        lista.append(reg);
    }
    return lista;
}