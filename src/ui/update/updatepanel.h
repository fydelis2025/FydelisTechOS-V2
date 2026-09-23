#ifndef UPDATEPANEL_H
#define UPDATEPANEL_H
#include <QDialog>
#include <QLabel>
#include <QPushButton>
#include <QProgressBar>
#include "core/update/fydelisupdater.h"

class UpdatePanel : public QDialog {
    Q_OBJECT
public:
    explicit UpdatePanel(QWidget* parent = nullptr);

private slots:
    void aoVerificarConcluida(const UpdateInfo& info);
    void aoProgresso(qint64 recebido, qint64 total);
    void aoDownloadConcluido(const QString& caminho);
    void aoErro(const QString& mensagem);
    void verificarAgora();
    void baixarEInstalar();

private:
    QLabel* m_lblVersaoAtual;
    QLabel* m_lblStatus;
    QLabel* m_lblMudancas;
    QProgressBar* m_barraProgresso;
    QPushButton* m_btnVerificar;
    QPushButton* m_btnInstalar;
    
    void atualizarInterface(const UpdateInfo& info);
};
#endif