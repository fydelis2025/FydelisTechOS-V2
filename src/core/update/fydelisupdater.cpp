#include "fydelisupdater.h"
#include "../versao.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QMessageBox>
#include <QProcess>
#include <QCoreApplication>
#include <QDebug>

FydelisUpdater& FydelisUpdater::instancia() {
    static FydelisUpdater inst;
    return inst;
}

FydelisUpdater::FydelisUpdater()
    : QObject(nullptr), m_rede(new QNetworkAccessManager(this)), m_verificarAuto(true) {
}

QString FydelisUpdater::versaoAtual() const {
    return FYDELIS_VERSION_STR;
}

UpdateInfo FydelisUpdater::ultimaVerificacao() const {
    return m_ultimaInfo;
}

void FydelisUpdater::verificarAtualizacoes() {
    // 🌐 URL do servidor de atualizações
    QUrl url("https://fydelistech.github.io/updates/versoes.json");
    QNetworkRequest req(url);
    
    QNetworkReply* resp = m_rede->get(req);
    connect(resp, &QNetworkReply::finished, this, [=](){
        if (resp->error() != QNetworkReply::NoError) {
            emit erroOcorrido("Falha na conexão: " + resp->errorString());
            resp->deleteLater();
            return;
        }
        processarRespostaVerificacao(resp->readAll());
        resp->deleteLater();
    });
}

void FydelisUpdater::processarRespostaVerificacao(const QByteArray& dados) {
    QJsonDocument doc = QJsonDocument::fromJson(dados);
    if (!doc.isObject()) {
        emit erroOcorrido("Formato inválido do servidor");
        return;
    }
    
    QJsonObject obj = doc.object();
    QString ultimaVersao = obj["ultimaVersao"].toString();
    QString versaoAtualSistema = versaoAtual();
    
    QVersionNumber vNova = QVersionNumber::fromString(ultimaVersao);
    QVersionNumber vAtual = QVersionNumber::fromString(versaoAtualSistema);
    
    m_ultimaInfo.disponivel = (vNova > vAtual);
    m_ultimaInfo.versaoNova = ultimaVersao;
    m_ultimaInfo.versaoAtual = versaoAtualSistema;
    m_ultimaInfo.dataLancamento = obj["dataLancamento"].toString();
    m_ultimaInfo.logMudancas = obj["logMudancas"].toString();
    m_ultimaInfo.urlDownload = obj["urlDownload"].toString();
    m_ultimaInfo.tamanhoBytes = obj["tamanhoBytes"].toVariant().toLongLong();
    m_ultimaInfo.hashVerificacao = obj["hashSHA256"].toString();
    m_ultimaInfo.eCritico = obj["critico"].toBool(false);
    
    emit verificacaoConcluida(m_ultimaInfo);
}

void FydelisUpdater::baixarAtualizacao() {
    if (!m_ultimaInfo.disponivel) return;
    
    QUrl url(m_ultimaInfo.urlDownload);
    QNetworkRequest req(url);
    QNetworkReply* resp = m_rede->get(req);
    
    connect(resp, &QNetworkReply::downloadProgress, this, &FydelisUpdater::downloadProgresso);
    connect(resp, &QNetworkReply::finished, this, [=](){
        if (resp->error()) {
            emit erroOcorrido("Download falhou: " + resp->errorString());
            resp->deleteLater();
            return;
        }
        
        QDir::home().mkpath(".FydelisCache/updates");
        m_arquivoBaixado = caminhoCache() + "/FydelisTechOS-Setup.exe";
        
        QFile arq(m_arquivoBaixado);
        if (arq.open(QIODevice::WriteOnly)) {
            arq.write(resp->readAll());
            arq.close();
            emit downloadConcluido(m_arquivoBaixado);
        }
        resp->deleteLater();
    });
}

void FydelisUpdater::instalarAtualizacao() {
    if (m_arquivoBaixado.isEmpty()) return;
    
    QProcess::startDetached(m_arquivoBaixado, QStringList() << "/silent");
    qApp->quit(); // Fecha o sistema para instalar
}

QString FydelisUpdater::caminhoCache() const {
    return QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/FydelisUpdates";
}