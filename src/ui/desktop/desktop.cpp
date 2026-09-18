#include "desktop.h"
#include "controlpanel.h"
#include "fileexplorer.h"   // ✅ EXPLORADOR DE ARQUIVOS
#include "thememanager.h"
#include <QApplication>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QPushButton>
#include <QSpacerItem>
#include <QTimer>
#include <QMessageBox>
#include <QIcon>
#include <QGraphicsDropShadowEffect>
#include <QDateTime>
// ==========================================
// 🪟 ÁREA DE TRABALHO — COM TEMA DINÂMICO
// + EXPLORADOR DE ARQUIVOS INTEGRADO
// De Salvador • Bahia 🇧🇷
// ==========================================
Desktop::Desktop(QWidget *parent) : QMainWindow(parent) {
    setWindowTitle("FydelisTech OS — Área de Trabalho");
    resize(1280, 720);
    showMaximized();

    // 🎨 CARREGAR TEMA DO JSON AUTOMATICAMENTE
    auto &tema = ThemeManager::instancia();
    tema.carregarTema(":/themes/default.json");

    // 🎯 APLICAR CORES DO TEMA
    setStyleSheet(QString(R"(
        QMainWindow { background: %1; }
        QWidget { color: %2; font-family: Segoe UI, Roboto, sans-serif; }
        QPushButton {
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 8px 12px;
            font-size: 13px;
        }
        QPushButton:hover { background: rgba(100, 150, 255, 0.20); }
        QLabel { color: %3; }
    )").arg(tema.corFundo(), tema.corTextoPrimaria(), tema.corTextoSecundaria()));

    // 📦 Área central
    auto *central = new QWidget(this);
    setCentralWidget(central);
    auto *layCentral = new QVBoxLayout(central);
    layCentral->setContentsMargins(0, 0, 0, 0);

    // 🧭 Barra de Tarefas (embaixo)
    montarBarraTarefas();

    // 🪟 JANELA CENTRAL — VIDRO COM TEMA
    auto *janelaCentral = new QWidget(this);
    janelaCentral->setStyleSheet(QString("QWidget { %1 }").arg(tema.estiloJanelaVidro()));
    janelaCentral->setMaximumSize(540, 300);

    // ✨ BRILHO DINÂMICO DO TEMA
    auto *sombra = new QGraphicsDropShadowEffect(this);
    sombra->setBlurRadius(tema.brilhoIntensidade());
    sombra->setColor(QColor(tema.corBrilho()));
    sombra->setOffset(0, 0);
    janelaCentral->setGraphicsEffect(sombra);

    // 📋 Conteúdo da Janela Central
    auto *layJanela = new QVBoxLayout(janelaCentral);
    layJanela->setContentsMargins(40, 30, 40, 30);

    auto *lblEmoji = new QLabel("🙂", janelaCentral);
    lblEmoji->setAlignment(Qt::AlignCenter);
    lblEmoji->setStyleSheet("font-size: 64px; margin-bottom: 10px;");

    auto *lblMensagem = new QLabel(
        "<h1 style='text-align:center; font-size:42px; font-weight:bold; margin:0;'>"
        "BEM-VINDO<br>AO FYDELIS TECH OS!"
        "</h1>", janelaCentral);
    lblMensagem->setAlignment(Qt::AlignCenter);
    lblMensagem->setStyleSheet(QString("color: %1;").arg(tema.corTextoPrimaria()));

    layJanela->addWidget(lblEmoji);
    layJanela->addWidget(lblMensagem);

    // 📍 Centralizar a janela
    layCentral->addWidget(janelaCentral, 0, Qt::AlignCenter);
    layCentral->addStretch();

    // ⏰ Relógio na barra de status
    m_lblRelogio = new QLabel;
    statusBar()->addPermanentWidget(m_lblRelogio);
    atualizarRelogio();
    m_timerRelogio = new QTimer(this);
    connect(m_timerRelogio, &QTimer::timeout, this, &Desktop::atualizarRelogio);
    m_timerRelogio->start(1000);
}

// ==================================================
// 🧭 BARRA DE TAREFAS — ESTILO DO TEMA + EXPLORADOR
// ==================================================
void Desktop::montarBarraTarefas() {
    auto &tema = ThemeManager::instancia();
    QToolBar *barra = addToolBar("Barra de Tarefas");
    barra->setMovable(false);
    barra->setFixedHeight(58);
    barra->setIconSize(QSize(24, 24));

    // 🪟 Estilo da Barra
    barra->setStyleSheet(QString(R"(
        QToolBar { %1 }
        QToolBar::separator { margin: 0 10px; }
        QToolBar QToolButton {
            border-radius: 8px; padding: 4px 8px; color: %2;
        }
        QToolBar QToolButton:hover { background: rgba(100, 150, 255, 0.20); }
    )").arg(tema.estiloBarraTarefas(), tema.corTextoPrimaria()));

    // 🟣 MENU INICIAR
    barra->addAction(
        QIcon(":/fydelis/images/logo_splash.png"),
        "FydelisTech",
        [](){ QMessageBox::information(nullptr, "🟣 Menu Iniciar", "Abrindo Menu FydelisTech OS..."); }
    );
    barra->addSeparator();

    // 📁 EXPLORADOR DE ARQUIVOS — ✅ NOVO!
    barra->addAction(
        QIcon(":/fydelis/icons/sistema/icone_pasta.png"),
        "Arquivos",
        this, &Desktop::abrirExploradorArquivos
    );

    barra->addAction(
        QIcon(":/fydelis/icons/aplicativos/fydelis_web.png"),
        "Navegador",
        this, &Desktop::abrirNavegador
    );
    barra->addAction(
        QIcon(":/fydelis/icons/aplicativos/fydelis_editor.png"),
        "Editor",
        this, &Desktop::abrirEditor
    );
    barra->addAction(
        QIcon(":/fydelis/icons/sistema/icone_terminal.png"),
        "Terminal",
        this, &Desktop::abrirTerminal
    );
    barra->addAction(
        QIcon(":/fydelis/icons/sistema/icone_configuracao.png"),
        "Configurações",
        this, &Desktop::abrirConfiguracoes
    );
    barra->addSeparator();

    // 🧩 Aplicativos Extras
    barra->addAction(
        QIcon(":/fydelis/icons/aplicativos/fydelis_remote.png"),
        "FydelisRemote",
        [](){ QMessageBox::information(nullptr, "🖥️ Acesso Remoto", "Abrindo FydelisRemote..."); }
    );
    barra->addAction(
        QIcon(":/fydelis/icons/aplicativos/fydelis_paint.png"),
        "FydelisPaint",
        [](){ QMessageBox::information(nullptr, "🎨 Desenho", "Abrindo FydelisPaint..."); }
    );
    barra->addAction(
        QIcon(":/fydelis/icons/aplicativos/fydelis_disco.png"),
        "DiscoTools",
        [](){ QMessageBox::information(nullptr, "💿 Disco", "Abrindo FydelisTech-DiscoTools..."); }
    );
    barra->addSeparator();

    // 📡 Hardware / Sistema
    barra->addAction(
        QIcon(":/fydelis/icons/hardware/placa_rede.png"),
        "Rede",
        [](){ QMessageBox::information(nullptr, "📡 Rede", "Status da Placa de Rede"); }
    );
    barra->addAction(
        QIcon(":/fydelis/icons/hardware/som.png"),
        "Som",
        [](){ QMessageBox::information(nullptr, "🔊 Áudio", "Controles de Som e Áudio"); }
    );

    // Espaçador — empurra o restante para a direita
    auto *espaco = new QWidget(this);
    espaco->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);
    barra->addWidget(espaco);

    // 🎛️ PAINEL DE CONTROLE
    barra->addAction(
        QIcon(":/fydelis/icons/sistema/icone_configuracao.png"),
        "Painel",
        this, &Desktop::abrirPainelControle
    );
}

// ==================================================
// 📁 ABRIR EXPLORADOR DE ARQUIVOS — ✅ NOVO!
// ==================================================
void Desktop::abrirExploradorArquivos() {
    FileExplorer *explorador = new FileExplorer(this);
    explorador->setAttribute(Qt::WA_DeleteOnClose); // ✅ Fecha e limpa memória
    explorador->show();
}

// ⏰ Relógio
void Desktop::atualizarRelogio() {
    m_lblRelogio->setText(QDateTime::currentDateTime().toString("dd/MM/yyyy — HH:mm:ss"));
}

// 🧩 Ações dos botões
void Desktop::abrirNavegador() {
    QMessageBox::information(this, "🌐 Navegador", "Abrindo FydelisTech Web...");
}
void Desktop::abrirEditor() {
    QMessageBox::information(this, "✏️ Editor", "Abrindo Fydelis++...");
}
void Desktop::abrirTerminal() {
    QMessageBox::information(this, "💻 Terminal", "Abrindo FydelisShell...");
}
void Desktop::abrirConfiguracoes() {
    QMessageBox::information(this, "⚙️ Configurações", "Abrindo Configurações do Sistema...");
}
void Desktop::abrirPainelControle() {
    ControlPanel p;
    p.setModal(true);
    p.exec();
}