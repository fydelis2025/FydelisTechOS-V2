// ==========================================
// AUTENTICAÇÃO — Criptografia + SQLite
// FydelisTech OS v2.0 · Salvador 🇧🇷
// ==========================================
#include "usuario.h"
#include "profilemanager.h"   // ✅ Integrar perfis
#include <sqlite3.h>
#include <QCryptographicHash>
#include <QUuid>
#include <QFile>
#include <QDir>
#include <QDebug>

// 📂 CAMINHOS — EXATAMENTE COMO VOCÊ DEFINIU!
#define BANCO_USUARIOS  "FydelisSystem/database/usuarios.db"
#define TAM_SALTE       16  // bytes aleatórios por usuário

// ✅ GARANTIR QUE A PASTA DO BANCO EXISTA
static bool garantirPastaBanco() {
    return QDir().mkpath("FydelisSystem/database");
}

// ✅ GERAR SALTE ALEATÓRIO (novo para cada usuário)
static QString gerarSalte() {
    return QUuid::createUuid().toString(QUuid::WithoutBraces).left(TAM_SALTE);
}

// ✅ CRIPTOGRAFAR SENHA — SHA3-512 + Salte Único
static QString hashSenha(const QString &senha, const QString &salte) {
    QString combinado = senha + salte;  // Senha + Salte → NÃO tem como adivinhar!
    QByteArray hash = QCryptographicHash::hash(combinado.toUtf8(), 
                                               QCryptographicHash::Sha3_512);
    return hash.toHex();  // 128 caracteres — impossível de reverter
}

// ✅ CRIAR TABELA SE NÃO EXISTIR
static bool criarTabelaSeNaoExiste(sqlite3 *db) {
    const char *sql = R"(
        CREATE TABLE IF NOT EXISTS usuarios (
            nome_usuario TEXT PRIMARY KEY,
            nome_exibicao TEXT NOT NULL,
            hash_senha TEXT NOT NULL,
            salte TEXT NOT NULL,
            tipo_conta TEXT NOT NULL DEFAULT 'padrao',
            foto_perfil TEXT DEFAULT '',
            ativo INTEGER DEFAULT 1,
            ultimo_login INTEGER DEFAULT 0
        );
    )";
    char *erro = nullptr;
    int rc = sqlite3_exec(db, sql, nullptr, nullptr, &erro);
    if (rc != SQLITE_OK) {
        qCritical() << "❌ Erro ao criar tabela:" << erro;
        sqlite3_free(erro);
        return false;
    }
    return true;
}

// ✅ CRIAR USUÁRIO — Chamado na primeira instalação
bool GerenciadorUsuarios::criarUsuario(
    const QString &nomeUsuario,
    const QString &senha,
    const QString &nomeExibicao,
    TipoConta tipo
) {
    // Garantir que a pasta existe
    if (!garantirPastaBanco()) return false;
    sqlite3 *db;
    if (sqlite3_open(BANCO_USUARIOS, &db) != SQLITE_OK) {
        qCritical() << "❌ Não foi possível abrir o banco de usuários";
        return false;
    }
    // Garantir que a tabela existe
    if (!criarTabelaSeNaoExiste(db)) {
        sqlite3_close(db);
        return false;
    }
    // 🔑 Gerar salte ÚNICO para esse usuário
    QString salte = gerarSalte();
    QString hash = hashSenha(senha, salte);
    // 📝 Inserir no banco
    QString sql = R"(
        INSERT INTO usuarios 
        (nome_usuario, nome_exibicao, hash_senha, salte, tipo_conta)
        VALUES (?, ?, ?, ?, ?);
    )";
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(db, sql.toUtf8().constData(), -1, &stmt, nullptr);
    sqlite3_bind_text(stmt, 1, nomeUsuario.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, nomeExibicao.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, hash.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, salte.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 5, (tipo == TipoConta::Admin) ? "admin" : "padrao", -1, SQLITE_TRANSIENT);
    bool ok = (sqlite3_step(stmt) == SQLITE_DONE);
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    if (!ok) {
        qCritical() << "❌ Erro ao inserir usuário no banco";
        return false;
    }

    // ==================================================
    // ✅ INTEGRAÇÃO COM GERENCIADOR DE PERFIS
    // ==================================================
    // 📂 Cria perfil.json + pastas desktop/Documents/Downloads/tema.qss
    if (!ProfileManager::instancia().criarPerfilUsuario(nomeUsuario, nomeExibicao)) {
        qWarning() << "⚠️ Usuário criado no banco, mas houve aviso ao criar pastas de perfil";
    }

    qDebug() << "✅ Usuário criado com sucesso:" << nomeUsuario;
    return true;
}

// ✅ VALIDAR LOGIN — Chamado na Tela de Login
bool GerenciadorUsuarios::validarLogin(
    const QString &nomeUsuario,
    const QString &senhaDigitada
) {
    sqlite3 *db;
    if (sqlite3_open(BANCO_USUARIOS, &db) != SQLITE_OK) return false;

    // 🔍 Buscar salte e hash do usuário
    QString sql = "SELECT salte, hash_senha, ativo FROM usuarios WHERE nome_usuario = ?;";
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(db, sql.toUtf8().constData(), -1, &stmt, nullptr);
    sqlite3_bind_text(stmt, 1, nomeUsuario.toUtf8().constData(), -1, SQLITE_TRANSIENT);

    QString salteSalvo, hashSalvo;
    int ativo = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        salteSalvo = QString::fromUtf8((const char*)sqlite3_column_text(stmt, 0));
        hashSalvo = QString::fromUtf8((const char*)sqlite3_column_text(stmt, 1));
        ativo = sqlite3_column_int(stmt, 2);
    } else {
        sqlite3_finalize(stmt);
        sqlite3_close(db);
        qWarning() << "⚠️ Usuário não encontrado:" << nomeUsuario;
        return false; // Usuário não existe
    }
    sqlite3_finalize(stmt);

    if (!ativo) {
        sqlite3_close(db);
        qWarning() << "⚠️ Conta desativada:" << nomeUsuario;
        return false; // Conta bloqueada
    }

    // 🔐 Recalcular hash com a senha digitada + salte salvo
    QString hashCalculado = hashSenha(senhaDigitada, salteSalvo);

    // ✅ Comparar — se igual, login autorizado!
    bool senhaCorreta = (hashCalculado == hashSalvo);

    // 📝 Atualizar último login
    if (senhaCorreta) {
        QString upd = "UPDATE usuarios SET ultimo_login = strftime('%s','now') WHERE nome_usuario = ?;";
        sqlite3_stmt *updStmt;
        sqlite3_prepare_v2(db, upd.toUtf8().constData(), -1, &updStmt, nullptr);
        sqlite3_bind_text(updStmt, 1, nomeUsuario.toUtf8().constData(), -1, SQLITE_TRANSIENT);
        sqlite3_step(updStmt);
        sqlite3_finalize(updStmt);
        qDebug() << "✅ Login autorizado:" << nomeUsuario;
    } else {
        qWarning() << "❌ Senha incorreta para:" << nomeUsuario;
    }

    sqlite3_close(db);
    return senhaCorreta;
}

// ✅ CARREGAR DADOS DO USUÁRIO — Após login, para a Área de Trabalho
Usuario GerenciadorUsuarios::carregarPerfil(const QString &nomeUsuario) {
    Usuario u;
    u.nomeUsuario = nomeUsuario;

    sqlite3 *db;
    if (sqlite3_open(BANCO_USUARIOS, &db) != SQLITE_OK) return u;

    QString sql = "SELECT nome_exibicao, tipo_conta, foto_perfil FROM usuarios WHERE nome_usuario = ?;";
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(db, sql.toUtf8().constData(), -1, &stmt, nullptr);
    sqlite3_bind_text(stmt, 1, nomeUsuario.toUtf8().constData(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt) == SQLITE_ROW) {
        u.nomeExibicao = QString::fromUtf8((const char*)sqlite3_column_text(stmt, 0));
        QString tipoStr = QString::fromUtf8((const char*)sqlite3_column_text(stmt, 1));
        u.tipo = (tipoStr == "admin") ? TipoConta::Admin : TipoConta::Padrao;
        u.caminhoFoto = QString::fromUtf8((const char*)sqlite3_column_text(stmt, 2));
    }

    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return u;
}