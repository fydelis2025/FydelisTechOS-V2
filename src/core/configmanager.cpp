// ==========================================
// GERENCIADOR DE CONFIGURAÇÕES DO SISTEMA
// FydelisTech OS v2.0 · Salvador 🇧🇷
// ==========================================
#include "configmanager.h"
#include <sqlite3.h>
#include <QDir>
#include <QDebug>
#include <QVariant>

// ✅ CAMINHO EXATO — FydelisSystem/database/config.db
#define BANCO_CONFIG  "FydelisSystem/database/config.db"

ConfigManager::ConfigManager() {
    inicializar();
}

ConfigManager& ConfigManager::instancia() {
    static ConfigManager inst;
    return inst;
}

QString ConfigManager::caminhoBanco() {
    return BANCO_CONFIG;
}

// ✅ GARANTIR PASTA E CRIAR BANCO + TABELA SE NÃO EXISTIR
bool ConfigManager::inicializar() {
    // Garante que a pasta FydelisSystem/database existe
    QDir().mkpath("FydelisSystem/database");

    sqlite3 *db;
    if (sqlite3_open(BANCO_CONFIG, &db) != SQLITE_OK) {
        qCritical() << "❌ Não foi possível abrir/criar config.db";
        return false;
    }

    // Cria a tabela se não existir
    const char *sql = R"(
        CREATE TABLE IF NOT EXISTS configuracoes (
            chave TEXT PRIMARY KEY,
            valor TEXT NOT NULL,
            tipo TEXT DEFAULT 'string'
        );
    )";

    char *erro = nullptr;
    int rc = sqlite3_exec(db, sql, nullptr, nullptr, &erro);
    if (rc != SQLITE_OK) {
        qCritical() << "❌ Erro ao criar tabela de configurações:" << erro;
        sqlite3_free(erro);
    } else {
        qDebug() << "✅ Banco config.db pronto em:" << BANCO_CONFIG;
    }

    sqlite3_close(db);
    return (rc == SQLITE_OK);
}

// ✅ LER VALOR DE CONFIGURAÇÃO
QVariant ConfigManager::valor(const QString &chave, const QVariant &padrao) {
    sqlite3 *db;
    if (sqlite3_open(BANCO_CONFIG, &db) != SQLITE_OK) return padrao;

    QString sql = "SELECT valor, tipo FROM configuracoes WHERE chave = ?;";
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(db, sql.toUtf8().constData(), -1, &stmt, nullptr);
    sqlite3_bind_text(stmt, 1, chave.toUtf8().constData(), -1, SQLITE_TRANSIENT);

    QVariant res = padrao;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        QString val = QString::fromUtf8((const char*)sqlite3_column_text(stmt, 0));
        QString tipo = QString::fromUtf8((const char*)sqlite3_column_text(stmt, 1));

        if (tipo == "bool") res = (val == "1" || val.toLower() == "true");
        else if (tipo == "int") res = val.toInt();
        else res = val;
    }

    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return res;
}

// ✅ SALVAR VALOR DE CONFIGURAÇÃO
bool ConfigManager::definirValor(const QString &chave, const QVariant &valor) {
    sqlite3 *db;
    if (sqlite3_open(BANCO_CONFIG, &db) != SQLITE_OK) return false;

    QString tipo;
    QString valStr;
    if (valor.typeId() == QMetaType::Bool) {
        tipo = "bool"; valStr = valor.toBool() ? "1" : "0";
    } else if (valor.typeId() == QMetaType::Int) {
        tipo = "int"; valStr = QString::number(valor.toInt());
    } else {
        tipo = "string"; valStr = valor.toString();
    }

    QString sql = R"(
        INSERT OR REPLACE INTO configuracoes (chave, valor, tipo)
        VALUES (?, ?, ?);
    )";
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(db, sql.toUtf8().constData(), -1, &stmt, nullptr);
    sqlite3_bind_text(stmt, 1, chave.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, valStr.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, tipo.toUtf8().constData(), -1, SQLITE_TRANSIENT);

    bool ok = (sqlite3_step(stmt) == SQLITE_DONE);
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return ok;
}

// ==========================================
// 🎨 TEMA
// ==========================================
QString ConfigManager::temaAtual() {
    return valor("sistema.tema", "Vidro Neon").toString();
}
bool ConfigManager::definirTemaAtual(const QString &nome) {
    return definirValor("sistema.tema", nome);
}

// ==========================================
// 🖥️ VÍDEO / TELA
// ==========================================
QString ConfigManager::resolucaoTela() {
    return valor("video.resolucao", "1920 × 1080").toString();
}
bool ConfigManager::definirResolucaoTela(const QString &res) {
    return definirValor("video.resolucao", res);
}

int ConfigManager::taxaAtualizacao() {
    return valor("video.taxa_hz", 60).toInt();
}
bool ConfigManager::definirTaxaAtualizacao(int hz) {
    return definirValor("video.taxa_hz", hz);
}

// ==========================================
// 🎧 SOM
// ==========================================
int ConfigManager::volumePrincipal() {
    return valor("som.volume", 75).toInt();
}
bool ConfigManager::definirVolumePrincipal(int vol) {
    return definirValor("som.volume", vol);
}

bool ConfigManager::somLigado() {
    return valor("som.ligado", true).toBool();
}
bool ConfigManager::definirSomLigado(bool ligado) {
    return definirValor("som.ligado", ligado);
}

QString ConfigManager::dispositivoSom() {
    return valor("som.dispositivo", "Alto-falante").toString();
}
bool ConfigManager::definirDispositivoSom(const QString &nome) {
    return definirValor("som.dispositivo", nome);
}

// ==========================================
// 📡 REDE
// ==========================================
bool ConfigManager::dhcpAtivado() {
    return valor("rede.dhcp", true).toBool();
}
bool ConfigManager::definirDHCP(bool ativo) {
    return definirValor("rede.dhcp", ativo);
}

QString ConfigManager::ipManual() {
    return valor("rede.ip", "192.168.1.100").toString();
}
bool ConfigManager::definirIPManual(const QString &ip) {
    return definirValor("rede.ip", ip);
}

QString ConfigManager::mascaraRede() {
    return valor("rede.mascara", "255.255.255.0").toString();
}
bool ConfigManager::definirMascaraRede(const QString &masc) {
    return definirValor("rede.mascara", masc);
}

QString ConfigManager::gateway() {
    return valor("rede.gateway", "192.168.1.1").toString();
}
bool ConfigManager::definirGateway(const QString &gw) {
    return definirValor("rede.gateway", gw);
}

QString ConfigManager::dnsPrimario() {
    return valor("rede.dns1", "8.8.8.8").toString();
}
bool ConfigManager::definirDNSPrimario(const QString &dns) {
    return definirValor("rede.dns1", dns);
}

QString ConfigManager::dnsSecundario() {
    return valor("rede.dns2", "8.8.4.4").toString();
}
bool ConfigManager::definirDNSSecundario(const QString &dns) {
    return definirValor("rede.dns2", dns);
}

// ==========================================
// 🖨️ IMPRESSORA
// ==========================================
QString ConfigManager::impressoraPadrao() {
    return valor("impressora.padrao", "").toString();
}
bool ConfigManager::definirImpressoraPadrao(const QString &nome) {
    return definirValor("impressora.padrao", nome);
}

// ==========================================
// 🔋 ENERGIA
// ==========================================
QString ConfigManager::planoEnergia() {
    return valor("energia.plano", "Balanceado").toString();
}
bool ConfigManager::definirPlanoEnergia(const QString &nome) {
    return definirValor("energia.plano", nome);
}

int ConfigManager::desligarTelaBateria() {
    return valor("energia.tela_bateria_min", 5).toInt();
}
bool ConfigManager::definirDesligarTelaBateria(int min) {
    return definirValor("energia.tela_bateria_min", min);
}

int ConfigManager::desligarTelaTomada() {
    return valor("energia.tela_tomada_min", 15).toInt();
}
bool ConfigManager::definirDesligarTelaTomada(int min) {
    return definirValor("energia.tela_tomada_min", min);
}

// ==========================================
// 🌍 REGIÃO
// ==========================================
QString ConfigManager::idioma() {
    return valor("regiao.idioma", "pt_BR").toString();
}
bool ConfigManager::definirIdioma(const QString &sigla) {
    return definirValor("regiao.idioma", sigla);
}

// ==========================================
// 🔒 SEGURANÇA
// ==========================================
bool ConfigManager::firewallAtivado() {
    return valor("seguranca.firewall", true).toBool();
}
bool ConfigManager::definirFirewall(bool ativo) {
    return definirValor("seguranca.firewall", ativo);
}

bool ConfigManager::protecaoTempoReal() {
    return valor("seguranca.protecao_rt", true).toBool();
}
bool ConfigManager::definirProtecaoTempoReal(bool ativo) {
    return definirValor("seguranca.protecao_rt", ativo);
}