#include "securitymanager.h"
#include <QFile>
#include <QDir>
#include <QRandomGenerator>
#include <QCryptographicHash>
#include <QDebug>

#define PASTA_SEGURANCA    "FydelisSystem/security"
#define ARQ_SALTE_GLOBAL   PASTA_SEGURANCA "/salte_senhas.bin"
#define ARQ_CHAVE_PRIVADA  PASTA_SEGURANCA "/chave_privada.key"

SecurityManager::SecurityManager() {
    inicializarSeguranca();
}

SecurityManager& SecurityManager::instancia() {
    static SecurityManager inst;
    return inst;
}

QString SecurityManager::pastaSeguranca() {
    return PASTA_SEGURANCA;
}

// ✅ Gerar bytes criptograficamente seguros
QByteArray SecurityManager::gerarBytesAleatorios(int qtde) {
    QByteArray res;
    res.resize(qtde);
    for (int i = 0; i < qtde; i += 4) {
        quint32 rnd = QRandomGenerator::global()->generate();
        res[i] = (rnd >>  0) & 0xFF;
        if (i+1 < qtde) res[i+1] = (rnd >>  8) & 0xFF;
        if (i+2 < qtde) res[i+2] = (rnd >> 16) & 0xFF;
        if (i+3 < qtde) res[i+3] = (rnd >> 24) & 0xFF;
    }
    return res;
}

bool SecurityManager::inicializarSeguranca() {
    QDir().mkpath(PASTA_SEGURANCA);

    // 🗝️ Salte Global — se não existir, cria e NUNCA MUDA
    if (!QFile::exists(ARQ_SALTE_GLOBAL)) {
        m_salteGlobal = gerarBytesAleatorios(32);
        QFile f(ARQ_SALTE_GLOBAL);
        if (f.open(QIODevice::WriteOnly)) {
            f.write(m_salteGlobal);
            f.close();
            qDebug() << "✅ Salte global gerado e salvo";
        } else {
            qCritical() << "❌ Não foi possível salvar salte global";
            return false;
        }
    } else {
        QFile f(ARQ_SALTE_GLOBAL);
        if (f.open(QIODevice::ReadOnly)) {
            m_salteGlobal = f.readAll();
            f.close();
        }
    }

    // 🔑 Chave Privada do Sistema
    if (!QFile::exists(ARQ_CHAVE_PRIVADA)) {
        m_chavePrivada = gerarBytesAleatorios(64);
        QFile f(ARQ_CHAVE_PRIVADA);
        if (f.open(QIODevice::WriteOnly)) {
            f.write(m_chavePrivada);
            f.close();
            qDebug() << "✅ Chave privada do sistema gerada";
        } else {
            qCritical() << "❌ Não foi possível salvar chave privada";
            return false;
        }
    } else {
        QFile f(ARQ_CHAVE_PRIVADA);
        if (f.open(QIODevice::ReadOnly)) {
            m_chavePrivada = f.readAll();
            f.close();
        }
    }

    return true;
}

QByteArray SecurityManager::salteGlobal() {
    return m_salteGlobal;
}

QByteArray SecurityManager::chavePrivadaSistema() {
    return m_chavePrivada;
}