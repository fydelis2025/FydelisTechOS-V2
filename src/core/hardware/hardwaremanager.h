#ifndef HARDWAREMANAGER_H
#define HARDWAREMANAGER_H

#include <QObject>
#include <QAbstractListModel>
#include <QList>
#include <QTimer>

// 📦 Estrutura de um Dispositivo
struct Dispositivo {
    QString id;              // Identificador único
    QString nome;            // Nome amigável
    QString fabricante;      // Fabricante
    QString tipo;            // vídeo, áudio, rede, armazenamento, etc.
    QString descricao;
    QString caminho;         // Caminho no sistema
    bool temDriver = false;
    bool driverRecomendado = false;
    QString versaoDriver;
    QString urlDownload;     // Link para baixar
    QString status;           // "ok", "faltando", "atualizar"
};

// 📋 Modelo para exibição
class DeviceModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        Nome = Qt::UserRole + 1,
        Tipo,
        Status,
        Icone,
        TemDriver
    };

    explicit DeviceModel(QObject *pai = nullptr);
    int rowCount(const QModelIndex & = QModelIndex()) const override;
    QVariant data(const QModelIndex &indice, int papel) const override;
    QHash<int, QByteArray> roleNames() const override;

    void atualizarLista(const QList<Dispositivo> &lista);

private:
    QList<Dispositivo> m_lista;
};

// 🔍 Gerenciador Principal
class HardwareManager : public QObject {
    Q_OBJECT
public:
    static HardwareManager& instancia();

    bool inicializar();
    const QList<Dispositivo>& todosDispositivos() const;
    DeviceModel* modeloDispositivos();

    // 🔄 Verificação manual ou automática
    void escanearHardware();
    void iniciarMonitoramento(int intervaloMs = 5000); // a cada 5s

signals:
    void dispositivoAdicionado(const Dispositivo &dev);
    void dispositivoRemovido(const QString &id);
    void listaAtualizada();

private:
    HardwareManager();
    ~HardwareManager();

    QList<Dispositivo> escanearWindows();   // WMI / SetupAPI
    QList<Dispositivo> escanearLinux();    // lshw / sysfs
    QString classificarTipoDispositivo(const QString &classe);

    QList<Dispositivo> m_dispositivos;
    DeviceModel *m_modelo;
    QTimer *m_timerMonitor;
};

#endif // HARDWAREMANAGER_H