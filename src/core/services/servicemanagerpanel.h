#ifndef SERVICEMANAGERPANEL_H
#define SERVICEMANAGERPANEL_H
#include <QDialog>
#include <QListWidget>
#include <QPushButton>
#include <QLabel>
#include "fydelisservices.h"

class ServicoManagerPanel : public QDialog {
    Q_OBJECT
public:
    explicit ServicoManagerPanel(QWidget* parent = nullptr);

private slots:
    void atualizarLista();
    void iniciarSelecionado();
    void pararSelecionado();
    void reiniciarSelecionado();
    void alterarStatusServico(const QString& id, ServicoStatus novo);

private:
    QListWidget* m_lista;
    QLabel* m_lblDetalhes;
    QPushButton* m_btnIniciar;
    QPushButton* m_btnParar;
    QPushButton* m_btnReiniciar;
    
    QString statusParaTexto(ServicoStatus s);
    QString statusParaCor(ServicoStatus s);
};
#endif