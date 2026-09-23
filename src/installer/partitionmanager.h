#ifndef PARTITIONMANAGER_H
#define PARTITIONMANAGER_H

#include <QObject>
#include <QList>
#include <QString>

struct Particao {
    QString dispositivo;   // /dev/sda ou C:
    QString nome;          // "Sistema", "Arquivos"
    qint64 tamanhoTotal;   // Em bytes
    qint64 tamanhoUsado;
    bool selecionada;
    bool instalarAqui;
    bool usarDiscoInteiro;
};

class PartitionManager : public QObject {
    Q_OBJECT
public:
    explicit PartitionManager(QObject *parent = nullptr);
    QList<Particao> listarDiscos();
    bool validarParticao(const Particao &p);
    qint64 espacoNecessario(); // ~8GB mínimo
    bool particionarDiscoInteiro(const QString &dispositivo);
    bool criarParticao(const QString &dispositivo, qint64 inicio, qint64 fim);
    bool instalarGRUB(const QString &dispositivo);

private:
    QList<Particao> m_discos;
};

#endif // PARTITIONMANAGER_H