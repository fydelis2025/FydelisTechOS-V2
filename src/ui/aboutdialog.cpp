#include "aboutdialog.h"
#include <QDesktopServices>
#include <QUrl>

AboutDialog::AboutDialog(QWidget *parent) : QDialog(parent) {
    setWindowTitle("ℹ️ Sobre o FydelisTech OS");
    resize(520, 480);
    setModal(true);

    setStyleSheet(R"(
        QDialog {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #0f172a, stop:1 #1e293b);
            color: #f1f5f9;
        }
        QLabel#titulo { font-size: 22px; font-weight: bold; color: #00FF88; }
        QLabel#versao { font-size: 13px; color: #94a3b8; }
        QLabel#texto { font-size: 13px; line-height: 1.6; }
        QPushButton {
            background: #1e40af;
            border: none;
            border-radius: 6px;
            padding: 10px 16px;
            color: white;
            font-weight: bold;
            min-width: 100px;
        }
        QPushButton:hover { background: #3b82f6; }
        QPushButton#fechar { background: #334155; }
        QPushButton#fechar:hover { background: #475569; }
    )");

    QVBoxLayout* principal = new QVBoxLayout(this);
    principal->setSpacing(18);
    principal->setContentsMargins(30, 30, 30, 30);

    // 🟣 Título
    QLabel* lblTitulo = new QLabel("FydelisTech OS", this);
    lblTitulo->setObjectName("titulo");
    lblTitulo->setAlignment(Qt::AlignCenter);
    principal->addWidget(lblTitulo);

    // 🏷️ Versão
    QLabel* lblVersao = new QLabel("Versão 2.1 — CVE Shield • Segurança Integrada", this);
    lblVersao->setObjectName("versao");
    lblVersao->setAlignment(Qt::AlignCenter);
    principal->addWidget(lblVersao);

    principal->addSpacing(10);

    // 📝 Texto principal
    QLabel* lblTexto = new QLabel(this);
    lblTexto->setObjectName("texto");
    lblTexto->setWordWrap(true);
    lblTexto->setAlignment(Qt::AlignJustify);
    lblTexto->setText(R"(
<p style='text-align:center;'>
🇧🇷 <b>Desenvolvido com paixão em Salvador, Bahia</b><br><br>
Sistema operacional completo — do kernel à interface gráfica,<br>
com foco em segurança, privacidade e liberdade digital.<br><br>
<b>👤 Idealizador & Desenvolvedor Principal:</b><br>
Adiel Santos Fontes<br><br>
<b>🤝 Agradecimentos Especiais:</b><br>
• À comunidade de tecnologia livre<br>
• Aos amigos e familiares que apoiaram<br>
• À Bahia e sua cultura que inspira<br>
• A todos que acreditam no conhecimento compartilhado<br><br>
🛡️ CVE Shield — Módulo de auditoria e proteção em tempo real<br>
🔒 SQLCipher AES-256 — Dados sempre protegidos<br>
💻 FydelTerm — Terminal nativo do sistema
</p>
    )");
    principal->addWidget(lblTexto);

    principal->addStretch();

    // 🔗 Botões
    QHBoxLayout* botoes = new QHBoxLayout;
    botoes->setSpacing(12);

    QPushButton* btnGitHub = new QPushButton("🐙 GitHub", this);
    connect(btnGitHub, &QPushButton::clicked, this, &AboutDialog::abrirGitHub);

    QPushButton* btnSite = new QPushButton("🌐 Projeto", this);
    connect(btnSite, &QPushButton::clicked, this, &AboutDialog::abrirSite);

    QPushButton* btnFechar = new QPushButton("Fechar", this);
    btnFechar->setObjectName("fechar");
    connect(btnFechar, &QPushButton::clicked, this, &QDialog::accept);

    botoes->addWidget(btnGitHub);
    botoes->addWidget(btnSite);
    botoes->addStretch();
    botoes->addWidget(btnFechar);

    principal->addLayout(botoes);
}

void AboutDialog::abrirGitHub() {
    QDesktopServices::openUrl(QUrl("https://github.com/fydelis2025"));
}

void AboutDialog::abrirSite() {
    QDesktopServices::openUrl(QUrl("https://www.fydelistechos.com.br"));
}