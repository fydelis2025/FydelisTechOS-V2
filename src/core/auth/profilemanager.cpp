#include "profilemanager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

#define PASTA_PERFIS  "FydelisSystem/profiles"

ProfileManager::ProfileManager() {
    QDir().mkpath(PASTA_PERFIS);
}

ProfileManager& ProfileManager::instancia() {
    static ProfileManager inst;
    return inst;
}

QString ProfileManager::pastaPerfil(const QString &nomeUsuario) {
    return PASTA_PERFIS "/" + nomeUsuario.toLower();
}

QString ProfileManager::caminhoPerfilJson(const QString &nomeUsuario) {
    return pastaPerfil(nomeUsuario) + "/perfil.json";
}

QString ProfileManager::pastaDesktop(const QString &nomeUsuario) {
    return pastaPerfil(nomeUsuario) + "/desktop";
}

QString ProfileManager::caminhoTema(const QString &nomeUsuario) {
    return pastaPerfil(nomeUsuario) + "/tema.qss";
}

bool ProfileManager::criarPerfilUsuario(const QString &nomeUsuario, const QString &nomeExibicao) {
    QString pasta = pastaPerfil(nomeUsuario);
    QString usuarioMin = nomeUsuario.toLower();

    // 📂 Criar todas as pastas
    QDir dir;
    dir.mkpath(pasta + "/desktop");
    dir.mkpath(pasta + "/Documents");
    dir.mkpath(pasta + "/Downloads");
    dir.mkpath(pasta + "/Config");

    // 📄 Criar perfil.json padrão
    QJsonObject perfil;
    perfil["nome_usuario"] = usuarioMin;
    perfil["nome_exibicao"] = nomeExibicao;
    perfil["foto_perfil"] = "";
    perfil["tema_atual"] = "padrao";
    perfil["idioma"] = "pt_BR";
    perfil["ultimo_acesso"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    QJsonDocument doc(perfil);
    QFile f(caminhoPerfilJson(nomeUsuario));
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        f.write(doc.toJson(QJsonDocument::Indented));
        f.close();
    }

    // 🎨 Criar tema.qss padrão
    QFile tema(caminhoTema(nomeUsuario));
    if (tema.open(QIODevice::WriteOnly | QIODevice::Text)) {
        tema.write("/* Estilo personalizado do usuário */\n");
        tema.write("/* FydelisTech OS - Tema Padrão */\n");
        tema.close();
    }

    qDebug() << "✅ Perfil criado para:" << nomeUsuario;
    return true;
}

QJsonObject ProfileManager::carregarPerfil(const QString &nomeUsuario) {
    QFile f(caminhoPerfilJson(nomeUsuario));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};

    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) return {};
    return doc.object();
}

bool ProfileManager::salvarPerfil(const QString &nomeUsuario, const QJsonObject &dados) {
    QJsonDocument doc(dados);
    QFile f(caminhoPerfilJson(nomeUsuario));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
    f.write(doc.toJson(QJsonDocument::Indented));
    return true;
}