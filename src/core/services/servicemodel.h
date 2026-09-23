#ifndef SERVICEMODEL_H
#define SERVICEMODEL_H
#include <QString>
#include <QObject>

enum class ServicoStatus {
    Parado,
    Executando,
    Pausado,
    Erro,
    NaoInstalado
};

enum class Inicializacao {
    Manual,
    Automatico,
    Desativado
};

class ServicoModel : public QObject {
    Q_OBJECT
public:
    QString id;
    QString nomeExibicao;
    QString descricao;
    QString icone;
    ServicoStatus status;
    Inicializacao tipoInicio;
    QString versao;
    QString caminhoExecutavel;

    bool podeIniciar() const { return status == ServicoStatus::Parado || status == ServicoStatus::Erro; }
    bool podeParar() const { return status == ServicoStatus::Executando; }
    bool podePausar() const { return status == ServicoStatus::Executando; }
};
#endif