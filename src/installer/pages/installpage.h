#ifndef INSTALLPAGE_H
#define INSTALLPAGE_H

#include <QWizardPage>
#include <QProgressBar>
#include <QLabel>
#include <QPushButton>
#include "../slideshow.h"
#include "../../core/securevault.h"

class InstallPage : public QWizardPage {
    Q_OBJECT
public:
    explicit InstallPage(QWidget *parent = nullptr);
    void initializePage() override;
    bool isComplete() const override { return m_concluido; }

private slots:
    void iniciarInstalacao();
    void avancarProgresso(int porcentagem, const QString &etapa);
    void finalizarInstalacao();

private:
    QProgressBar *m_progresso;
    QLabel *m_etapa;
    SlideShow *m_slideshow;
    bool m_concluido;
    SecureVault *m_cofre;
    
    // 🗄️ Cria banco + usuário no SQLite
    bool criarSistemaUsuario(const QString &usuario, const QString &senha);
    bool copiarArquivosSistema();
    bool configurarBootloader();
};

#endif // INSTALLPAGE_H