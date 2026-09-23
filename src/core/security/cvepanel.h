#ifndef CVEPANEL_H
#define CVEPANEL_H

#include <QDialog>
#include <QLabel>
#include <QListWidget>
#include <QPushButton>
#include <QTimer>

class CVEPanel : public QDialog {
    Q_OBJECT
public:
    explicit CVEPanel(QWidget* parent = nullptr);

private slots:
    void atualizarPainel();
    void novaAmeaca(const QString& tipo, const QString& mensagem);
    void carregarHistorico();
    void limparHistorico();

private:
    QLabel* m_lblStatus;
    QLabel* m_lblBloqueios;
    QLabel* m_lblTentativas;
    QLabel* m_lblUltimo;
    QListWidget* m_listaHistorico;
    QPushButton* btnLimpar;
    QPushButton* btnAtualizar;
    QTimer* m_timerAtualiza;
};

#endif // CVEPANEL_H