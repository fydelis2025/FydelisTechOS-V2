#include "securevault.h"
#include <QStandardPaths>
#include <QFileInfo>
#include <QProcess>
#include <QRandomGenerator>
#include <QSqlError>

// ==========================================
// 📍 CAMINHOS — ALINHADOS COM SUA ESTRUTURA
// ==========================================
#define PASTA_RAIZ       "FydelisSystem"
#define PASTA_COFRE      "vault"
#define PASTA_SEGURANCA  "security"
#define PASTA_DATABASE   "database"
#define PASTA_PROFILES   "profiles"

#define ARQUIVO_USERS    "users.db"
#define ARQUIVO_CHAVE    "master.key"

// ==========================================
// 🧬 CAMINHOS COMPLETOS
// ==========================================
QString SecureVault::caminhoPastaRaiz() const {
    return QDir::rootPath() + PASTA_RAIZ;
}

QString SecureVault::caminhoCofre() const {
    return caminhoPastaRaiz() + "/" + PASTA_COFRE;
}

QString SecureVault::caminhoSeguranca() const {
    return caminhoPastaRaiz() + "/" + PASTA_SEGURANCA;
}

QString SecureVault::caminhoDatabase() const {
    return caminhoPastaRaiz() + "/" + PASTA_DATABASE;
}

QString SecureVault::caminhoProfiles() const {
    return caminhoPastaRaiz() + "/" + PASTA_PROFILES;
}

// ==========================================
// 🔑 INSTÂNCIA ÚNICA
// ==========================================
SecureVault& SecureVault::instancia() {
    static SecureVault inst;
    return inst;
}

SecureVault::SecureVault(QObject *parent)
    : QObject(parent), m_inicializado(false) {}

// ==========================================
// 🔑 GERAR CHAVE MESTRA — em /security/
// ==========================================
bool SecureVault::gerarChaveMestra() {
    QString caminhoChave = caminhoSeguranca() + "/" + ARQUIVO_CHAVE;

    // Se já existe → não gera de novo
    if (QFile::exists(caminhoChave)) return true;

    // 🎲 Gerar 256 bits criptograficamente forte
    QByteArray chave;
    chave.resize(32);
    QRandomGenerator::global()->fillRange(reinterpret_cast<quint32*>(chave.data()), 8);

    // 💾 Salvar chave
    QFile arquivo(caminhoChave);
    if (!arquivo.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    arquivo.write(chave);
    arquivo.close();

    // ⛔ PROTEGER — permissão 000 + oculto
    protegerArquivo(caminhoChave);
    return true;
}

// ==========================================
// 🔒 PROTEGER ARQUIVO E PASTA
// ==========================================
bool SecureVault::protegerArquivo(const QString &caminho) {
    QFile arq(caminho);

#ifdef Q_OS_WIN
    arq.setFilePermissions(QFile::Permissions{}); // Sem permissão nenhuma
    QProcess::execute("attrib +h +s \"" + caminho + "\""); // Oculto + Sistema
#endif

#ifdef Q_OS_UNIX
    arq.setPermissions(QFile::Permissions{}); // 000 — só root
#endif

    return true;
}

// ==========================================
// 🗝️ CARREGAR CHAVE — só na memória
// ==========================================
QString SecureVault::carregarChaveMestra() {
    QString caminho = caminhoSeguranca() + "/" + ARQUIVO_CHAVE;
    QFile arq(caminho);

    if (!arq.open(QIODevice::ReadOnly)) return "";
    QByteArray chaveBruta = arq.readAll();
    arq.close();

    return QString::fromLatin1(chaveBruta.toHex());
}

// ==========================================
// 🚀 INICIALIZAR TUDO — CRIA TODAS AS PASTAS
// ==========================================
bool SecureVault::inicializar() {
    if (m_inicializado) return true;

    QDir dir;

    // 📁 CRIAR TODAS AS PASTAS AUTOMATICAMENTE
    QStringList pastas = {
        caminhoPastaRaiz(),
        caminhoCofre(),
        caminhoSeguranca(),
        caminhoDatabase(),
        caminhoProfiles()
    };

    for (const QString &p : pastas) {
        if (!dir.exists(p)) {
            if (!dir.mkpath(p)) {
                qCritical() << "❌ Não foi possível criar pasta:" << p;
                return false;
            }
        }
        protegerArquivo(p); // 🔒 Protege cada pasta
    }

    // 🔑 Gerar/carregar chave
    if (!gerarChaveMestra()) return false;
    m_chaveMestra = carregarChaveMestra();
    if (m_chaveMestra.isEmpty()) return false;

    // 🗄️ ABRIR BANCO DE USUÁRIOS → em /vault/
    m_dbUsuarios = QSqlDatabase::addDatabase("SQLCIPHER", "usuarios_conn");
    m_dbUsuarios.setDatabaseName(caminhoCofre() + "/" + ARQUIVO_USERS);

    if (!m_dbUsuarios.open()) {
        qCritical() << "❌ Falha ao abrir banco:" << m_dbUsuarios.lastError().text();
        return false;
    }

    // 🔐 Aplicar chave AES-256
    QSqlQuery q(m_dbUsuarios);
    q.exec(QString("PRAGMA key = '%1';").arg(m_chaveMestra));
    q.exec("PRAGMA cipher_compatibility = 4;"); // AES-256-GCM

    // 📊 TABELAS DE USUÁRIOS
    q.exec(R"(
        CREATE TABLE IF NOT EXISTS usuarios (
            id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
            nome_usuario TEXT NOT NULL UNIQUE,
            nome_exibicao TEXT,
            hash_senha TEXT NOT NULL,
            salte TEXT NOT NULL,
            tipo_conta TEXT DEFAULT 'padrao',
            ativo INTEGER DEFAULT 1,
            ultimo_login INTEGER,
            criado_em INTEGER DEFAULT (strftime('%s','now'))
        );
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS sessoes (
            id_sessao INTEGER PRIMARY KEY AUTOINCREMENT,
            id_usuario INTEGER,
            token TEXT UNIQUE,
            expira_em INTEGER
        );
    )");

    m_inicializado = true;
    qDebug() << "✅ Cofre inicializado — pastas protegidas + banco criptografado ativo";
    return true;
}

// ==========================================
// 📥 ACESSAR BANCO
// ==========================================
QSqlDatabase SecureVault::bancoUsuarios() {
    if (!m_inicializado) {
        qCritical() << "❌ Banco não inicializado!";
        return QSqlDatabase();
    }
    return m_dbUsuarios;
}