#include "splashscreen.h"
#include <QPixmap>
#include <QScreen>
#include <QApplication>

SplashScreen::SplashScreen(QWidget *parent) : QWidget(parent), m_porcentagem(0) {
    // Janela sem bordas, sempre no topo
    setWindowFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);
    setAttribute(Qt::WA_TranslucentBackground);
    setFixedSize(600, 400);

    // Centralizar na tela
    QScreen *tela = QApplication::primaryScreen();
    move(tela->geometry().center() - rect().center());

    // 🎨 Layout
    auto *fundo = new QWidget(this);
    fundo->setStyleSheet(R"(
        QWidget {
            background: qlineargradient(x1:0,y1:0, x2:0,y2:1,
                stop:0 #0f172a, stop:1 #1e293b);
            border-radius: 16px;
        }
    )");
    fundo->setGeometry(0, 0, 600, 400);

    m_logo = new QLabel(fundo);
    m_logo->setPixmap(QPixmap(":/images/logo.png").scaled(140, 140, Qt::KeepAspectRatio, Qt::SmoothTransformation));
    m_logo->setAlignment(Qt::AlignCenter);

    m_titulo = new QLabel("FydelisTech OS", fundo);
    m_titulo->setStyleSheet("font-size: 32px; font-weight: bold; color: white;");
    m_titulo->setAlignment(Qt::AlignCenter);

    m_status = new QLabel("Inicializando...", fundo);
    m_status->setStyleSheet("font-size: 14px; color: #94a3b8;");
    m_status->setAlignment(Qt::AlignCenter);

    m_progresso = new QProgressBar(fundo);
    m_progresso->setRange(0, 100);
    m_progresso->setValue(0);
    m_progresso->setTextVisible(false);
    m_progresso->setStyleSheet(R"(
        QProgressBar {
            border-radius: 8px;
            background: #334155;
            height: 12px;
            margin: 0 40px;
        }
        QProgressBar::chunk {
            border-radius: 8px;
            background: qlineargradient(x1:0,y1:0, x2:1,y2:0,
                stop:0 #2563eb, stop:1 #8b5cf6);
        }
    )");

    // Posicionar elementos
    auto *lay = new QVBoxLayout(fundo);
    lay->setContentsMargins(20, 40, 20, 30);
    lay->addWidget(m_logo);
    lay->addSpacing(15);
    lay->addWidget(m_titulo);
    lay->addSpacing(8);
    lay->addWidget(m_status);
    lay->addSpacing(25);
    lay->addWidget(m_progresso);
    lay->addStretch();

    // ⏱️ Simular inicialização
    m_timer = new QTimer(this);
    connect(m_timer, &QTimer::timeout, this, &SplashScreen::atualizarProgresso);
    m_timer->start(40); // 40ms por passo
}

void SplashScreen::atualizarProgresso() {
    m_porcentagem += 2;
    m_progresso->setValue(m_porcentagem);

    // Mensagens conforme avança
    if (m_porcentagem < 20) m_status->setText("Carregando kernel...");
    else if (m_porcentagem < 40) m_status->setText("Inicializando sistema seguro...");
    else if (m_porcentagem < 60) m_status->setText("Verificando banco de dados...");
    else if (m_porcentagem < 80) m_status->setText("Preparando interface...");
    else if (m_porcentagem < 100) m_status->setText("Quase pronto...");
    else {
        m_timer->stop();
        m_status->setText("✅ Sistema pronto!");
        QTimer::singleShot(600, this, [this](){ emit pronto(); close(); });
    }
}