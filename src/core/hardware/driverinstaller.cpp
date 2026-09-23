#include "driverinstaller.h"
#include <QDir>
#include <QStandardPaths>

// ==========================================
// 📥 GERENCIADOR DE DOWNLOAD E INSTALAÇÃO
// FydelisTech OS v2.0 · Salvador 🇧🇷
// ==========================================

DriverInstaller& DriverInstaller::instancia() {
    static DriverInstaller inst;
    return inst;
}

DriverInstaller::DriverInstaller() : QObject(nullptr) {
    m_rede = new QNetworkAccessManager(this);
    m_processoInstalador = new QProcess(this);
    connect(m_processoInstalador, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &DriverInstaller::processoTerminado);
}

DriverInstaller::~DriverInstaller() {
    if (m_respostaAtual) m_respostaAtual->deleteLater();
}

void DriverInstaller::baixarDriver(const QString &url, const QString &idDispositivo) {
    m_idAtual = idDispositivo;
    
    QString pasta = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + "/FydelisDrivers";
    QDir().mkpath(pasta);
    QString nomeArq = url.split('/').last();
    m_arquivoSalvo = new QFile(pasta + "/" + nomeArq, this);

    if (!m_arquivoSalvo->open(QIODevice::WriteOnly)) {
        emit erroBaixado("Não foi possível salvar o arquivo");
        delete m_arquivoSalvo;
        m_arquivoSalvo = nullptr;
        return;
    }

    QNetworkRequest requisicao(QUrl(url));
    m_respostaAtual = m_rede->get(requisicao);
    
    connect(m_respostaAtual, &QNetworkReply::readyRead, this, &DriverInstaller::dadosRecebidos);
    connect(m_respostaAtual, &QNetworkReply::finished, this, [=](){ downloadConcluido(m_respostaAtual); });
}

void DriverInstaller::dadosRecebidos() {
    if (!m_respostaAtual || !m_arquivoSalvo) return;
    m_arquivoSalvo->write(m_respostaAtual->readAll());
    
    qint64 total = m_respostaAtual->header(QNetworkRequest::ContentLengthHeader).toLongLong();
    if (total > 0) {
        qint64 salvo = m_arquivoSalvo->size();
        emit progressoBaixado(static_cast<int>((salvo * 100) / total));
    }
}

void DriverInstaller::downloadConcluido(QNetworkReply *resp) {
    if (resp->error() == QNetworkReply::NoError) {
        m_arquivoSalvo->close();
        emit baixadoComSucesso(m_arquivoSalvo->fileName());
    } else {
        emit erroBaixado(resp->errorString());
        m_arquivoSalvo->remove();
    }
    m_respostaAtual = nullptr;
}

void DriverInstaller::instalarDriver(const QString &caminhoArquivo, const QString &idDispositivo) {
    m_idAtual = idDispositivo;

    // Detectar tipo de instalador
    if (caminhoArquivo.endsWith(".exe", Qt::CaseInsensitive)) {
        m_processoInstalador->start(caminhoArquivo, QStringList() << "/silent");
    } else if (caminhoArquivo.endsWith(".msi", Qt::CaseInsensitive)) {
        m_processoInstalador->start("msiexec", QStringList() << "/i" << caminhoArquivo << "/quiet");
    } else {
        emit instalacaoConcluida(false, "Formato não suportado");
        return;
    }
}

void DriverInstaller::processoTerminado(int codigoSaida) {
    bool ok = (codigoSaida == 0);
    QString msg = ok ? "✅ Instalação concluída!" : "❌ Erro na instalação (código: " + QString::number(codigoSaida) + ")";
    if (ok && msg.contains("reiniciar", Qt::CaseInsensitive)) {
        m_precisaReiniciar = true;
        msg += "\n⚠️ É recomendado reiniciar o sistema.";
    }
    emit instalacaoConcluida(ok, msg);
}

bool DriverInstaller::precisaReiniciar() const {
    return m_precisaReiniciar;
}