#include "resumopage.h"
#include <QVBoxLayout>
#include <QMessageBox>

ResumoPage::ResumoPage(QWidget *parent) : QWizardPage(parent) {
    setTitle("Resumo da Instalação");
    setSubTitle("Revise as configurações antes de começar.");

    m_textoResumo = new QLabel;
    m_textoResumo->setWordWrap(true);
    m_textoResumo->setStyleSheet("padding:15px; background:#1e293b; border-radius:8px; font-size:13px; line-height:1.8;");

    auto *lay = new QVBoxLayout;
    lay->addWidget(new QLabel("<b>Confira abaixo tudo antes de instalar:</b>"));
    lay->addSpacing(10);
    lay->addWidget(m_textoResumo);
    lay->addStretch();
    setLayout(lay);
}

void ResumoPage::initializePage() {
    QString idioma = field("idioma").toString();
    QString disco = field("dispositivo").toString();
    bool discoInteiro = field("usarDiscoInteiro").toBool();
    QString usuario = field("usuario").toString();
    bool loginAuto = field("loginAutomatico").toBool();

    QString resumo = QString(
        "<b>🌐 Idioma:</b> %1<br>"
        "<b>💽 Disco de instalação:</b> %2<br>"
        "<b>📦 Particionamento:</b> %3<br>"
        "<b>👤 Usuário:</b> %4<br>"
        "<b>🔐 Login automático:</b> %5<br><br>"
        "<b>⚠️ Atenção:</b> A instalação vai copiar os arquivos do sistema e configurar o boot.<br>"
        "Clique em <b>Instalar</b> para começar."
    )
    .arg(idioma == "pt_BR" ? "Português (Brasil)" : idioma)
    .arg(disco)
    .arg(discoInteiro ? "Disco inteiro" : "Partição personalizada")
    .arg(usuario)
    .arg(loginAuto ? "Sim" : "Não");

    m_textoResumo->setText(resumo);
}