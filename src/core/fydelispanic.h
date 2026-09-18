#ifndef FYDELISPANIC_H
#define FYDELISPANIC_H

#include <QString>
#include <QStringList>

struct FydelisException {
    QString codigo;
    QString mensagem;
    QString modulo;
    QString endereco;
    QString processo;
    QStringList rastreio;
    QString dataHora;
    bool critico;
};

class FydelisPanic {
public:
    static FydelisPanic& instancia();

    void disparar(const QString& codigo,
                  const QString& mensagem,
                  const QString& modulo = QString(),
                  const QString& endereco = QString(),
                  const QStringList& pilha = QStringList());

    void definirProcesso(const QString& nome, int pid = -1);

private:
    FydelisPanic();
    FydelisException m_ultimoErro;
    QString m_processoAtual;
    int m_pidAtual;
};

#endif // FYDELISPANIC_H