#ifndef PROFILEMANAGER_H
#define PROFILEMANAGER_H

#include <QString>
#include <QJsonObject>

class ProfileManager {
public:
    static ProfileManager& instancia();

    // ✅ Criar estrutura de perfil do usuário
    bool criarPerfilUsuario(const QString &nomeUsuario, const QString &nomeExibicao);

    // ✅ Carregar/Salvar perfil.json
    QJsonObject carregarPerfil(const QString &nomeUsuario);
    bool salvarPerfil(const QString &nomeUsuario, const QJsonObject &dados);

    // ✅ Caminhos do perfil
    QString pastaPerfil(const QString &nomeUsuario);
    QString caminhoPerfilJson(const QString &nomeUsuario);
    QString pastaDesktop(const QString &nomeUsuario);
    QString caminhoTema(const QString &nomeUsuario);

private:
    ProfileManager();
};

#endif // PROFILEMANAGER_H