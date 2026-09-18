#include "bemvindopage.h"
#include <QPixmap>

BemVindoPage::BemVindoPage(QWidget *parent) : QWizardPage(parent) {
    setTitle("Bem-vindo ao FydelisTech OS");
    setSubTitle("O sistema operacional brasileiro — alternativo ao Windows");

    // Logo + Título
    auto *lblLogo = new QLabel;
    lblLogo->setPixmap(QPixmap(":/images/logo.png").scaled(120, 120, Qt::KeepAspectRatio, Qt::SmoothTransformation));
    lblLogo->setAlignment(Qt::AlignCenter);

    auto *lblTitulo = new QLabel("<h1 style='text-align:center; color:#2563eb;'>FydelisTech OS</h1>");
    lblTitulo->setAlignment(Qt::AlignCenter);

    auto *lblTexto = new QLabel(
        "<p style='font-size:14px; text-align:center; line-height:1.6;'>"
        "Olá! Este é o instalador do FydelisTech OS,<br>"
        "o sistema operacional feito do zero, em Salvador, Bahia 🇧🇷.<br><br>"
        "Ele vai guiá-lo passo a passo para instalar o sistema no seu computador.<br><br>"
        "<b>Antes de continuar:</b> salve seus arquivos e feche outros programas.<br>"
        "A instalação levará alguns minutos."
        "</p>"
    );
    lblTexto->setWordWrap(true);
    lblTexto->setAlignment(Qt::AlignCenter);

    auto *lay = new QVBoxLayout;
    lay->addSpacing(20);
    lay->addWidget(lblLogo);
    lay->addWidget(lblTitulo);
    lay->addSpacing(15);
    lay->addWidget(lblTexto);
    lay->addStretch();
    setLayout(lay);
}

int BemVindoPage::nextId() const {
    return 1; // Vai para Idioma
}