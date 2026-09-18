#ifndef FYDELISSERVICES_H
#define FYDELISSERVICES_H
#include "servicemodel.h"
#include <QList>
#include <QTimer>

class FydelisServices : public QObject {
    Q_OBJECT
public:
    static FydelisServices& instancia();

    // 📋 Lista de todos os serviços
    QList<ServicoModel*> todosServicos();
    ServicoModel* obterServico(const QString& id);

    // ⚙️ Controles
    bool iniciarServico(const QString& id);
    bool pararServico(const QString& id);
    bool reiniciarServico(const QString& id);
    bool definirModoInicio(const QString& id, Inicializacao modo);

signals:
    void servicoStatusAlterado(const QString& id, ServicoStatus novoStatus);

private:
    FydelisServices();
    void inicializarListaServicos();
    QList<ServicoModel*> m_servicos;
    QTimer* m_timerMonitor;
};
#endif