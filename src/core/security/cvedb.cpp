#include "cvedb.h"
#include <QSqlError>
#include <QDebug>

CVEDB& CVEDB::instancia() {
    static CVEDB inst;
    return inst;
}

CVEDB::CVEDB() : QObject(nullptr) {}

// ✅ Abre o banco — SE NÃO EXISTIR, CRIA AUTOMATICAMENTE
bool CVEDB::inicializar() {
    m_db = QSqlDatabase::addDatabase("QSQLITE", "cve_log");
    m_db.setDatabaseName("FydelisSystem/database/cve_log.db"); // 📄 Arquivo gerado aqui

    if (!m_db.open()) {
        qCritical() << "❌ Não foi possível abrir/criar o banco:" << m_db.lastError().text();
        return false;
    }

    // ✅ Cria a tabela se não existir
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

    qInfo() << "✅ Banco cve_log.db pronto — caminho:" << m_db.databaseName();
    return true;
}

// ✅ Registra um evento — data e hora preenche SOZINHO
bool CVEDB::registrar(const QString& cveId, const QString& risco,
                       const QString& modulo, const QString& detalhes,
                       const QString& acao) {
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
        qCritical() << "Erro ao registrar:" << q.lastError().text();
        return false;
    }
    return true;
}

int CVEDB::totalPorNivel(const QString& risco) {
    QSqlQuery q(m_db);
    q.prepare("SELECT COUNT(*) FROM auditoria_seguranca WHERE risco = ?");
    q.addBindValue(risco);
    q.exec();
    q.next();
    return q.value(0).toInt();
}

QList<QVariantMap> CVEDB::listar(int limite) {
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