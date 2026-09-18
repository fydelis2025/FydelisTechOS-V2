// ==========================================
// PONTO DE ENTRADA — INSTALADOR FYDELIS TECH OS
// De Salvador • Bahia 🇧🇷
// ==========================================

#include <QApplication>
#include <QDir>
#include <QDebug>
#include "installwizard.h"

// ✅ AQUI FICA A FUNÇÃO — COLA EXATAMENTE AQUI!
static bool criarEstruturaPastas() {
    QStringList pastas = {
        // 🛡️ Sistema FydelisTech
        "FydelisSystem/database",
        "FydelisSystem/security",
        "FydelisSystem/profiles",
        "FydelisSystem/kernel",
        "FydelisSystem/drivers",
        "FydelisSystem/services",
        "FydelisSystem/Lixeira",       // 🗑️ Lixeira

        // 👤 USUÁRIO — PASTAS PESSOAIS
        "Users/Fydelis/Downloads",      // 📥 Downloads
        "Users/Fydelis/Documentos",     // 📄 Documentos
        "Users/Fydelis/Imagens",        // 🖼️ Imagens
        "Users/Fydelis/Músicas",        // 🎵 Músicas
        "Users/Fydelis/Vídeos",         // 🎬 Vídeos

        // 🪟 Compatibilidade Windows
        "Windows/System32",
        "Windows/System64",
        "Windows/System32/WindowsPowerShell",

        // ✅ APLICATIVOS — FYDELIS TECH SUITE
        "Program Files/FydelisTech-Suite",
        "Program Files/FydelisTech-Suite/FydelisTech-Web",
        "Program Files/FydelisTech-Suite/FydelisTech-DiscoTools",

        // 📦 Dados do Sistema
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

// ==========================================
// 🚀 PONTO DE ENTRADA DO INSTALADOR
// ==========================================
int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    // ✅ 1º PASSO: CRIA TODAS AS PASTAS ANTES DE TUDO!
    criarEstruturaPastas();

    // ✅ 2º PASSO: ABRE O ASSISTENTE DE INSTALAÇÃO
    InstallWizard assistente;
    assistente.show();

    return app.exec();
}