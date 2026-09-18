#include "loginscreen.h"
#include "../core/auth/usuario.h"

#include <QMessageBox>
#include <QScreen>
#include <QApplication>
#include <QShortcut>

// Declaração da função de autenticação (implementada em auth/usuario.cpp)
extern bool validarLogin(const QString &usuario, const QString &senha);

LoginScreen::LoginScreen(QWidget *parent) : QWidget(parent) {
    setWindowFlags(Qt::FramelessWindowHint);
    setAttribute(Qt::WA_TranslucentBackground);
    resize(420, 380);

    // Centralizar
    QScreen *tela = QApplication::primaryScreen();
    move(tela->geometry().center() - rect().center());

    // 🎨 Interface
    auto *fundo = new QWidget(this);
    fundo->setStyleSheet(R"(
        QWidget {
            background: qlineargradient(x1:0,y1:0, x2:0,y2:1,
                stop:0 #0f172a, stop:1 #1e293b);
            border-radius: 16px;
        }
        QLabel { color: white; }
        QLineEdit {
            padding: 10px 12px;
            border-radius: 8px;
            border: 1px solid #475569;
            background: #1e293b;
            color: white;
            font-size: 14px;
        }
        QPushButton {
            padding: 10px;
            border-radius: 8px;
            background: #2563eb;
            color: white;
            font-size: 15px;
            font-weight: bold;
        }
        QPushButton:hover { background: #3b82f6; }
    )");
    fundo->setGeometry(0, 0, 420, 380);

    auto *lblTitulo = new QLabel("🔒 Fazer Login", fundo);
    lblTitulo->setStyleSheet("font-size: 22px; font-weight: bold;");
    lblTitulo->setAlignment(Qt::AlignCenter);

    m_usuario = new QLineEdit(fundo);
    m_usuario->setPlaceholderText("Nome de usuário");

    m_senha = new QLineEdit(fundo);
    m_senha->setPlaceholderText("Senha");
    m_senha->setEchoMode(QLineEdit::Password);

    m_erro = new QLabel("", fundo);
    m_erro->setStyleSheet("color: #f87171; font-size: 13px;");
    m_erro->setAlignment(Qt::AlignCenter);

    m_btnEntrar = new QPushButton("Entrar", fundo);
    connect(m_btnEntrar, &QPushButton::clicked, this, &LoginScreen::tentarLogin);

    // Atalho: Enter = Entrar
    new QShortcut(Qt::Key_Return, this, this, &LoginScreen::tentarLogin);
    new QShortcut(Qt::Key_Enter, this, &LoginScreen::tentarLogin);

    // Layout
    auto *lay = new QVBoxLayout(fundo);
    lay->setContentsMargins(40, 40, 40, 40);
    lay->addWidget(lblTitulo);
    lay->addSpacing(25);
    lay->addWidget(new QLabel("Usuário:"));
    lay->addWidget(m_usuario);
    lay->addSpacing(12);
    lay->addWidget(new QLabel("Senha:"));
    lay->addWidget(m_senha);
    lay->addSpacing(10);
    lay->addWidget(m_erro);
    lay->addSpacing(15);
    lay->addWidget(m_btnEntrar);
    lay->addStretch();

    m_usuario->setFocus();
}

void LoginScreen::tentarLogin() {
    QString usuario = m_usuario->text().trimmed();
    QString senha = m_senha->text();

    if (usuario.isEmpty()) {
        m_erro->setText("⚠️ Digite o nome de usuário");
        return;
    }

    // 🔐 Validar usando a classe correta
    if (GerenciadorUsuarios::validarLogin(usuario, senha)) {
        m_erro->setText("✅ Entrando...");
        m_erro->setStyleSheet("color: #4ade80;");
        QTimer::singleShot(800, this, [this, usuario](){
            // Carregar perfil antes de abrir a área de trabalho
            Usuario u = GerenciadorUsuarios::carregarPerfil(usuario);
            qDebug() << "👤 Usuário:" << u.nomeExibicao 
                     << "| Tipo:" << (u.tipo == TipoConta::Admin ? "Admin" : "Padrão");
            emit loginConcluido();
            close();
        });
    } else {
        m_erro->setText("❌ Usuário ou senha incorretos");
        m_senha->clear();
        m_senha->setFocus();
    }
}