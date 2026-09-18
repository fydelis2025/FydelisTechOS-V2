#ifndef USUARIO_H
#define USUARIO_H

#include <QString>

// 📋 TIPOS DE CONTA
enum class TipoConta {
    Padrao,
    Admin
};

// 👤 ESTRUTURA DO USUÁRIO
struct Usuario {
    QString nomeUsuario;
    QString nomeExibicao;
    TipoConta tipo;
    QString caminhoFoto;
};

// 🛠️ GERENCIADOR DE USUÁRIOS — Classe central
class GerenciadorUsuarios {
public:
    // ✅ Criar usuário — chamado na instalação
    static bool criarUsuario(
        const QString &nomeUsuario,
        const QString &senha,
        const QString &nomeExibicao,
        TipoConta tipo = TipoConta::Padrao
    );

    // ✅ Validar login — chamado na Tela de Login
    static bool validarLogin(
        const QString &nomeUsuario,
        const QString &senhaDigitada
    );

    // ✅ Carregar perfil — após login, para a Área de Trabalho
    static Usuario carregarPerfil(const QString &nomeUsuario);
};

#endif // USUARIO_H