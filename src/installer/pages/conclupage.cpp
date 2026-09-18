#include "conclupage.h"
#include <QVBoxLayout>
#include <QProcess>
#include <QMessageBox>

ConcluPage::ConcluPage(QWidget *parent) : QWizardPage(parent) {
    setTitle("✅ Instalação Concluída!");
    setSubTitle("O FydelisTech OS foi instalado com sucesso.");

    m_texto = new QLabel(
        "<h2 style='color:#2563eb; text-align:center;'>🎉 Instalação Concluída!</h2>"
        "<p style='font-size:14px; text-align:center; line-height:1.7;'>"
        "O FydelisTech OS foi instalado no seu computador.<br><br>"
        "📋 Usuário criado com sucesso<br>"
        "🔒 Banco de dados protegido e criptografado<br>"
        "🚀 Sistema pronto para uso<br><br>"
        "Clique em <b>Concluir</b> e o computador será reiniciado.<br>"
        "Remova o pendrive de instalação e o sistema vai iniciar.<br><br>"
        "<b>Seja bem-vindo ao FydelisTech OS! 🇧🇷💪</b>"
        "</p>"
    );
    m_texto->setWordWrap(true);
    m_texto->setAlignment(Qt::AlignCenter);

    auto *lay = new QVBoxLayout;
    lay->addSpacing(30);
    lay->addWidget(m_texto);
    lay->addStretch();
    setLayout(lay);
}