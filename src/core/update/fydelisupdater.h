#ifndef FYDELISUPDATER_H
#define FYDELISUPDATER_H
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QVersionNumber>

struct UpdateInfo {
    bool disponivel;
    QString versaoNova;
    QString versaoAtual;
    QString dataLancamento;
    QString logMudancas;
    QString urlDownload;
    qint64 tamanhoBytes;
    QString hashVerificacao;
    bool eCritico;
};

class FydelisUpdater : public QObject {
    Q_OBJECT
public:
    static FydelisUpdater& instancia();
    
    QString versaoAtual() const;
    UpdateInfo ultimaVerificacao() const;
    
    void verificarAtualizacoes();
    void baixarAtualizacao();
    void instalarAtualizacao();
    void definirVerificarAuto(bool sim);

signals:
    void verificacaoConcluida(const UpdateInfo& info);
    void downloadProgresso(qint64 recebido, qint64 total);
    void downloadConcluido(const QString& caminhoArquivo);
    void erroOcorrido(const QString& mensagem);
    void atualizacaoInstalada();

private:
    FydelisUpdater();
    void processarRespostaVerificacao(const QByteArray& dados);
    QString caminhoCache() const;
    
    QNetworkAccessManager* m_rede;
    UpdateInfo m_ultimaInfo;
    QString m_arquivoBaixado;
    bool m_verificarAuto;
};
#endif