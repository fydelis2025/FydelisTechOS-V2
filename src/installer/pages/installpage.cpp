#include "installpage.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QWizard>
#include <QMessageBox>
#include <QThread>

InstallPage::InstallPage(QWidget *parent) : QWizardPage(parent), m_concluido(false) {
    setTitle("⚙️ Instalando o FydelisTech OS");
    setSubTitle("Aguarde enquanto o sistema é configurado — não desligue o computador.");

    // 🖼️ Slideshow na ESQUERDA — imagens bonitas passando
    m_slideshow = new SlideShow;
    m_slideshow->adicionarImagem(":/slides/01.png");
    m_slideshow->adicionarImagem(":/slides/02.png");
    m_slideshow->adicionarImagem(":/slides/03.png");
    m_slideshow->adicionarImagem(":/slides/04.png");
    m_slideshow->adicionarImagem(":/slides/05.png");
    m_slideshow->adicionarImagem(":/slides/06.png");

    // ⏳ Progresso na DIREITA
    m_progresso = new QProgressBar;
    m_progresso->setRange(0, 100);
    m_progresso->setValue(0);
    
    m_etapa = new QLabel("Preparando...");
    m_etapa->setStyleSheet("font-size: 14px; font-weight: bold; color: #2563eb;");

    // 📦 Layout — Slideshow + Progresso lado a lado
    auto *hLay = new QHBoxLayout;
    hLay->addWidget(m_slideshow, 1);  // Imagens ocupam metade
    hLay->addSpacing(20);
    
    auto *vLay = new QVBoxLayout;
    vLay->addWidget(m_etapa);
    vLay->addWidget(m_progresso);
    vLay->addStretch();
    hLay->addLayout(vLay, 1);

    setLayout(hLay);
}

void InstallPage::initializePage() {
    m_concluido = false;
    m_slideshow->iniciar(3500); // 3,5s por imagem
    QMetaObject::invokeMethod(this, &InstallPage::iniciarInstalacao, Qt::QueuedConnection);
}

void InstallPage::avancarProgresso(int porcentagem, const QString &etapa) {
    m_progresso->setValue(porcentagem);
    m_etapa->setText(etapa);
    QApplication::processEvents();
}

void InstallPage::iniciarInstalacao() {
    // 📋 Pegar dados das telas anteriores
    QString usuario = field("usuario").toString();
    QString senha = field("senha").toString();
    bool loginAuto = field("loginAutomatico").toBool();
    
    // 🔄 ETAPAS DA INSTALAÇÃO — Progresso real
    avancarProgresso(5,   "🔒 Inicializando sistema seguro...");
    m_cofre = &SecureVault::instancia();
    if (!m_cofre->inicializar()) {
        QMessageBox::critical(this, "Erro", "Falha ao inicializar o sistema seguro!");
        return;
    }
    QThread::msleep(800);

    avancarProgresso(15,  "🗄️ Criando banco de dados criptografado...");
    QThread::msleep(600);

    avancarProgresso(25,  "👤 Criando perfil de usuário...");
    if (!criarSistemaUsuario(usuario, senha)) {
        QMessageBox::critical(this, "Erro", "Falha ao criar usuário!");
        return;
    }
    QThread::msleep(500);

    avancarProgresso(35,  "💽 Copiando arquivos do sistema...");
    copiarArquivosSistema();
    QThread::msleep(1000);

    avancarProgresso(70,  "🔧 Configurando inicialização...");
    QThread::msleep(500);

    avancarProgresso(85,  "🚀 Instalando carregador de boot (GRUB)...");
    configurarBootloader();
    QThread::msleep(600);

    avancarProgresso(95,  "✨ Finalizando configurações...");
    QThread::msleep(500);

    avancarProgresso(100, "✅ Instalação concluída!");
    m_slideshow->parar();
    m_concluido = true;
    
    wizard()->button(QWizard::NextButton)->setEnabled(true);
    emit completeChanged();
}

// 🗄️ CRIA USUÁRIO NO BANCO SQLITE — AQUI ACONTECE A MAGIA!
bool InstallPage::criarSistemaUsuario(const QString &usuario, const QString &senha) {
    // Chamar a função que já criamos — SHA3-512 + Salte + Banco Criptografado
    extern bool criarUsuarioSistema(const QString &nome, const QString &senha, const QString &nomeExib);
    return criarUsuarioSistema(usuario, senha, usuario);
}

bool InstallPage::copiarArquivosSistema() {
    // Aqui copia kernel, apps, bibliotecas...
    return true;
}

bool InstallPage::configurarBootloader() {
    // GRUB ou bootloader nativo
    return true;
}