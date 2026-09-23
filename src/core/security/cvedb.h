#ifndef CVEDB_H
#define CVEDB_H

#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QDateTime>

class CVEDB : public QObject {
    Q_OBJECT
public:
    static CVEDB& instancia();
    
    // ✅ Abre e cria TUDO automaticamente
    bool inicializar();
    
    // ✅ Insere registro — só chamar
    bool registrar(const QString& cveId, const QString& risco,
                   const QString& modulo, const QString& detalhes,
                   const QString& acao);
    
    // ✅ Consultas simples
    int totalPorNivel(const QString& risco);
    QList<QVariantMap> listar(int limite = 50);

private:
    explicit CVEDB();
    QSqlDatabase m_db;
};

#endif // CVEDB_H