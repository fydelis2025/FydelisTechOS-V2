#ifndef DEVICEDATABASE_H
#define DEVICEDATABASE_H

#include <QString>
#include <QMap>

// ==========================================
// 📚 BASE DE DADOS DE DISPOSITIVOS E DRIVERS
// FydelisTech OS v2.0 · Salvador 🇧🇷
// ==========================================

struct DriverRecomendado {
    QString idHardware;
    QString nomeDispositivo;
    QString fabricante;
    QString urlDownload;
    QString versao;
    QString tipoArquivo; // exe / msi / zip
    QString hashVerificacao;
};

class DeviceDatabase {
public:
    static DeviceDatabase& instancia();

    // 🔍 Procurar driver recomendado
    DriverRecomendado buscarDriverParaDispositivo(const QString &idHardware);

    // ✅ Verificar se o dispositivo tem suporte oficial
    bool temSuporte(const QString &idHardware);

private:
    DeviceDatabase();
    void carregarBase();

    QMap<QString, DriverRecomendado> m_drivers;
};

#endif // DEVICEDATABASE_H