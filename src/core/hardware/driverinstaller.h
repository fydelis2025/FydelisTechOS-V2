#ifndef DRIVERINSTALLER_H
#define DRIVERINSTALLER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QProcess>

class DriverInstaller : public QObject {
    Q_OBJECT
public:
    static DriverInstaller& instancia();

    // 📥 Baixar driver
    void baixarDriver(const QString &url, const QString &idDispositivo);

    // ⚙️ Instalar (executa o instalador)
    void instalarDriver(const QString &caminhoArquivo, const QString &idDispositivo);

    // ✅ Verificar se precisa reiniciar
    bool precisaReiniciar() const;

signals:
    void progressoBaixado(int porcentagem);
    void baixadoComSucesso(const QString &caminho);
    void erroBaixado(const QString &mensagem);
    void instalacaoConcluida(bool sucesso, const QString &mensagem);

private slots:
    void dadosRecebidos();
    void downloadConcluido(QNetworkReply *resposta);
    void processoTerminado(int codigoSaida);

private:
    DriverInstaller();
    ~DriverInstaller();

    QNetworkAccessManager *m_rede;
    QNetworkReply *m_respostaAtual;
    QFile *m_arquivoSalvo;
    QString m_idAtual;
    QProcess *m_processoInstalador;
    bool m_precisaReiniciar = false;
};

#endif // DRIVERINSTALLER_H