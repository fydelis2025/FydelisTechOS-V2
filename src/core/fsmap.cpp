#include "fsmap.h"
#include <QString>
#include <QMap>
#include <QFileInfo>
#include <QDir>

// ✅ Usuário logado no momento
static QString g_usuarioAtual = "Fydelis";

// ✅ Tabela de substituição
static QMap<QString, QString> g_mapeamento = {
    {"C:/Windows/",          CAMINHO_WINDOWS},
    {"C:/WINDOWS/",          CAMINHO_WINDOWS},
    {"C:/Windows/System32/", CAMINHO_SYSTEM32},
    {"C:/Program Files/",    CAMINHO_PROGRAMFILES},
    {"C:/Program Files (x86)/", CAMINHO_PROGRAMFILES_X86},
    {"C:/Users/",            CAMINHO_USERS},
    {"C:/ProgramData/",      CAMINHO_PROGRAMDATA}
};

void fs_definirUsuarioAtual(const char* nomeUsuario) {
    g_usuarioAtual = QString::fromUtf8(nomeUsuario);
}

const char* fs_map_windows_to_native(const char* caminhoWindows) {
    static QString resultado;
    QString entrada = QString::fromUtf8(caminhoWindows);

    // ✅ Normalizar barras: \ → /
    entrada = entrada.replace("\\", "/");

    // ✅ Remover letra da unidade C:
    if (entrada.startsWith("C:/")) entrada = entrada.mid(3);

    // ✅ Substituir "current" pelo usuário real logado
    entrada = entrada.replace("/Users/current/", QString("/Users/") + g_usuarioAtual + "/");

    // ✅ Se não encontrar mapeamento, retorna como está
    resultado = "/" + entrada;
    return resultado.toUtf8().constData();
}