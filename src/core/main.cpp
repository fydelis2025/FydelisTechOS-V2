// ==========================================
// PONTO DE ENTRADA — FYDELIS TECH OS v2.0
// Com Tela de Exceção Estilo Hacker Integrada
// De Salvador • Bahia 🇧🇷
// ==========================================
#include <QApplication>
#include <QMessageBox>
#include <QDir>
#include <QTimer>
#include <QDebug>

// ✅ SEUS MÓDULOS — NADA ALTERADO
#include "securevault.h"
#include "securitymanager.h"
#include "configmanager.h"
#include "thememanager.h"
#include "fsmap.h"
#include "ui/splash/splashscreen.h"
#include "ui/login/loginscreen.h"
#include "ui/desktop/desktop.h"

// ✅ === NOVO: TELA DE EXCEÇÃO ===
#include "fydelispanic.h"

void tratarErroGlobal(QtMsgType tipo, const QMessageLogContext& contexto, const QString& mensagem) {
    if (tipo == QtFatalMsg) {
        FydelisPanic::instancia().definirProcesso("Sistema FydelisTech OS");
        FydelisPanic::instancia().disparar(
            "0x0000FYFAT",
            mensagem,
            contexto.file ? QString::fromUtf8(contexto.file) : "Sistema",
            "0x0"
        );
    }
}
// ✅ === FIM DA TELA DE EXCEÇÃO ===

// ✅ CRIA TODAS AS PASTAS AUTOMATICAMENTE — ORIGINAL INTACTO
static bool criarEstruturaPastas() {
    QStringList pastas = {
        "FydelisSystem/database",
        "FydelisSystem/security",
        "FydelisSystem/profiles",
        "FydelisSystem/kernel",
        "FydelisSystem/drivers",
        "FydelisSystem/services",
        "FydelisSystem/database",
        "Windows/System32",
        "Windows/System64",
        "Windows/System32/WindowsPowerShell",
        "Program Files/FydelisTech-Suite",
        "Program Files/FydelisTech-Suite/FydelisTech-Web",
        "Program Files/FydelisTech-Suite/FydelisTech-DiscoTools",
        "Users",
        "ProgramData"
    };
    bool todasCriadas = true;
    for (const QString &pasta : pastas) {
        if (QDir().mkpath(pasta)) {
            qDebug() << "  ✅" << pasta;
        } else {
            qWarning() << "  ⚠️ Já existe ou não foi possível criar:" << pasta;
            todasCriadas = false;
        }
    }
    return todasCriadas;
}

// ✅ APLICAR TEMA SALVO — ORIGINAL INTACTO
static void aplicarTemaSalvo() {
    QString nomeTema = ConfigManager::instancia().temaAtual();
    qDebug() << "🎨 Aplicando tema salvo:" << nomeTema;
    auto &tm = ThemeManager::instancia();
    
    if (nomeTema == "Azul Celeste") {
        tm.carregarTemaDoJSON(R"({
            "nome": "Azul Celeste",
            "fundo": {"cor1": "#0f2b47", "cor2": "#1a4570", "cor3": "#0a1f35"},
            "janelaVidro": {"fundo": "rgba(40, 80, 120, 0.40)", "borda": "rgba(100, 180, 255, 0.40)", "raioCantos": 24, "brilhoIntensidade": 50},
            "barraTarefas": {"fundo": "rgba(20, 50, 90, 0.50)", "bordaSuperior": "rgba(100, 180, 255, 0.30)"},
            "texto": {"primaria": "#e6f2ff", "secundaria": "#a0c4e8", "destaque": "#74c0fc"}
        })");
    } else if (nomeTema == "Verde Escuro") {
        tm.carregarTemaDoJSON(R"({
            "nome": "Verde Escuro",
            "fundo": {"cor1": "#0f3827", "cor2": "#185038", "cor3": "#0a281c"},
            "janelaVidro": {"fundo": "rgba(40, 100, 70, 0.40)", "borda": "rgba(100, 255, 180, 0.35)", "raioCantos": 24, "brilhoIntensidade": 45},
            "barraTarefas": {"fundo": "rgba(20, 60, 40, 0.50)", "bordaSuperior": "rgba(100, 255, 180, 0.25)"},
            "texto": {"primaria": "#e6fff2", "secundaria": "#8fd8b8", "destaque": "#69db9a"}
        })");
    } else if (nomeTema == "Escuro Total") {
        tm.carregarTemaDoJSON(R"({
            "nome": "Escuro Total",
            "fundo": {"cor1": "#0a0a0f", "cor2": "#151520", "cor3": "#050508"},
            "janelaVidro": {"fundo": "rgba(30, 30, 45, 0.50)", "borda": "rgba(100, 100, 130, 0.30)", "raioCantos": 20, "brilhoIntensidade": 35},
            "barraTarefas": {"fundo": "rgba(15, 15, 25, 0.60)", "bordaSuperior": "rgba(80, 80, 110, 0.25)"},
            "texto": {"primaria": "#e0e0f0", "secundaria": "#9090a0", "destaque": "#b0b0d0"}
        })");
    } else {
        tm.carregarTemaDoJSON(R"({
            "nome": "FydelisTech Vidro Neon",
            "fundo": {"cor1": "#1a0f47", "cor2": "#251b60", "cor3": "#0f173a"},
            "janelaVidro": {"fundo": "rgba(60, 40, 110, 0.40)", "borda": "rgba(140, 180, 255, 0.35)", "raioCantos": 24, "brilhoIntensidade": 50},
            "barraTarefas": {"fundo": "rgba(30, 20, 70, 0.50)", "bordaSuperior": "rgba(140, 180, 255, 0.25)"},
            "texto": {"primaria": "#e6eeff", "secundaria": "#94a3b8", "destaque": "#a5b4fc"}
        })");
    }
}

int main(int argc, char *argv[]) {
    // ✅ === PRIMEIRA LINHA — ATIVAR CAPTURA DE ERROS ===
    qInstallMessageHandler(tratarErroGlobal);

    QApplication app(argc, argv);

    // ==================================================
    // 🚀 ETAPA 0 — CRIAR ESTRUTURA DE PASTAS
    // ==================================================
    criarEstruturaPastas();

    // ==================================================
    // 🔒 ETAPA 1 — INICIALIZAR COFRE SEGURO
    // ==================================================
    if (!SecureVault::instancia().inicializar()) {
        QMessageBox::critical(nullptr, "Erro Fatal",
            "Não foi possível inicializar o sistema seguro.\nContate o administrador.");
        return 1;
    }

    // ==================================================
    // 🔒 ETAPA 2 — INICIALIZAR SEGURANÇA
    // ==================================================
    SecurityManager::instancia().inicializarSeguranca();

    // ==================================================
    // ⚙️ ETAPA 3 — INICIALIZAR BANCO DE CONFIGURAÇÕES
    // ==================================================
    ConfigManager::instancia().inicializar();
    qDebug() << "✅ Banco de configurações SQLite pronto em: FydelisSystem/database/config.db";

    // ==================================================
    // 🎨 ETAPA 3.5 — APLICAR TEMA SALVO
    // ==================================================
    aplicarTemaSalvo();
    qDebug() << "✅ Tema aplicado:" << ConfigManager::instancia().temaAtual();

    // ==================================================
    // 🎬 ETAPA 4 — SPLASH → LOGIN → ÁREA DE TRABALHO
    // ==================================================
    SplashScreen *splash = new SplashScreen;
    splash->show();

    QObject::connect(splash, &SplashScreen::pronto, [&](){
        LoginScreen *login = new LoginScreen;
        login->show();

        QObject::connect(login, &LoginScreen::loginConcluido, [&](){
            login->close();
            DesktopArea *desktop = new DesktopArea;
            desktop->showMaximized();
            qDebug() << "✅ Área de Trabalho carregada com todas as configurações!";
        });

        splash->deleteLater();
    });

    return app.exec();
}