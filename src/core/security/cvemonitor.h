#ifndef CVEMONITOR_H
#define CVEMONITOR_H

#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QDateTime>

class CVEMonitor : public QObject {
    Q_OBJECT
public:
    static CVEMonitor& instancia();
    bool inicializar();

    // ✅ Método unificado — exatamente como o Gemini sugeriu
    bool registrarEvento(const QString& cveId, const QString& risco,
                         const QString& modulo, const QString& detalhes,
                         const QString& acao);

    // Consultas
    int totalPorNivel(const QString& risco) const;
    QList<QVariantMap> ultimosEventos(int limite = 50) const;

signals:
    void alertaCritico(const QString& cveId, const QString& mensagem);  // 🔔 Para tela
    void estatisticasAtualizadas(int critico, int alto, int total);

private:
    explicit CVEMonitor();
    QSqlDatabase m_db;
    bool abrirBanco();
    void criarTabela();
};

#endif // CVEMONITOR_H