#include "userpage.h"
#include <QVBoxLayout>
#include <QWizard>

UserPage::UserPage(QWidget *parent) : QWizardPage(parent) {
    setTitle("👤 Conta de Usuário");
    setSubTitle("Crie sua conta para acessar o sistema.");

    m_usuario = new QLineEdit;
    m_usuario->setPlaceholderText("Nome de usuário (ex: Fydelis)");
    registerField("usuario*", m_usuario);

    m_senha = new QLineEdit;
    m_senha->setPlaceholderText("Senha");
    m_senha->setEchoMode(QLineEdit::Password);
    registerField("senha", m_senha);

    m_confirmaSenha = new QLineEdit;
    m_confirmaSenha->setPlaceholderText("Confirmar senha");
    m_confirmaSenha->setEchoMode(QLineEdit::Password);

    m_loginAuto = new QCheckBox("🚀 Iniciar sistema sem pedir senha (login automático)");
    registerField("loginAutomatico", m_loginAuto);

    m_erro = new QLabel;
    m_erro->setStyleSheet("color: red;");
    m_erro->hide();

    auto *lay = new QVBoxLayout;
    lay->addWidget(new QLabel("Nome de usuário:"));
    lay->addWidget(m_usuario);
    lay->addSpacing(10);
    lay->addWidget(new QLabel("Senha:"));
    lay->addWidget(m_senha);
    lay->addWidget(new QLabel("Confirmar senha:"));
    lay->addWidget(m_confirmaSenha);
    lay->addSpacing(15);
    lay->addWidget(m_loginAuto);
    lay->addWidget(m_erro);
    lay->addStretch();
    setLayout(lay);
}

bool UserPage::validatePage() {
    if (m_senha->text() != m_confirmaSenha->text()) {
        m_erro->setText("❌ As senhas não coincidem!");
        m_erro->show();
        return false;
    }
    if (m_senha->text().length() < 4 && !m_senha->text().isEmpty()) {
        m_erro->setText("⚠️ Senha muito curta (mínimo 4 caracteres)");
        m_erro->show();
        return false;
    }
    m_erro->hide();
    return true;
}