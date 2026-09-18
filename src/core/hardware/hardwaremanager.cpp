#include "hardwaremanager.h"
#include <QDebug>
#include <QProcess>
#include <QRegularExpression>

// ==========================================
// 🔍 GERENCIADOR DE HARDWARE — DETECÇÃO
// FydelisTech OS v2.0 · Salvador 🇧🇷
// ==========================================

HardwareManager& HardwareManager::instancia() {
    static HardwareManager inst;
    return inst;
}

HardwareManager::HardwareManager() : QObject(nullptr) {
    m_modelo = new DeviceModel(this);
    m_timerMonitor = new QTimer(this);
    connect(m_timerMonitor, &QTimer::timeout, this, &HardwareManager::escanearHardware);
}

HardwareManager::~HardwareManager() {
    m_timerMonitor->stop();
}

bool HardwareManager::inicializar() {
    escanearHardware();
    return true;
}

void HardwareManager::escanearHardware() {
    m_dispositivos.clear();

#ifdef Q_OS_WIN
    m_dispositivos = escanearWindows();
#else
    m_dispositivos = escanearLinux();
#endif

    m_modelo->atualizarLista(m_dispositivos);
    emit listaAtualizada();
}

QList<Dispositivo> HardwareManager::escanearWindows() {
    QList<Dispositivo> lista;

    // Comando WMI para listar dispositivos
    QProcess processo;
    processo.start("wmic", QStringList() << "path" << "Win32_PnPEntity" << "get"
        << "Name,Manufacturer,DeviceID,Service,Status" << "/format:list");
    
    if (!processo.waitForFinished(5000)) return lista;

    QString saida = QString::fromLocal8Bit(processo.readAllStandardOutput());
    QStringList blocos = saida.split("\n\n", Qt::SkipEmptyParts);

    for (const QString &bloco : blocos) {
        Dispositivo dev;
        QStringList linhas = bloco.split('\n', Qt::SkipEmptyParts);
        
        for (const QString &linha : linhas) {
            QString chave = linha.section('=', 0, 0).trimmed();
            QString valor = linha.section('=', 1).trimmed();
            
            if (chave == "Name") dev.nome = valor;
            else if (chave == "Manufacturer") dev.fabricante = valor;
            else if (chave == "DeviceID") dev.id = valor;
            else if (chave == "Status") {
                dev.status = valor.isEmpty() ? "desconhecido" : valor.toLower();
                dev.temDriver = (dev.status == "ok" || dev.status == "funciona");
            }
        }

        if (!dev.nome.isEmpty() && !dev.nome.startsWith("PnP")) {
            dev.tipo = classificarTipoDispositivo(dev.id + " " + dev.nome);
            lista.append(dev);
        }
    }

    return lista;
}

QList<Dispositivo> HardwareManager::escanearLinux() {
    QList<Dispositivo> lista;
    QProcess processo;
    processo.start("lshw", QStringList() << "-short");
    
    if (!processo.waitForFinished(3000)) return lista;

    QString saida = QString::fromLocal8Bit(processo.readAllStandardOutput());
    QStringList linhas = saida.split('\n');

    for (const QString &linha : linhas.mid(2)) {
        if (linha.isEmpty()) continue;
        QStringList partes = linha.split(QRegularExpression("\\s+"));
        if (partes.size() < 4) continue;

        Dispositivo dev;
        dev.tipo = partes[0];
        dev.nome = partes.mid(3).join(" ");
        dev.status = "ok";
        dev.temDriver = true;
        lista.append(dev);
    }

    return lista;
}

QString HardwareManager::classificarTipoDispositivo(const QString &texto) {
    QString menor = texto.toLower();
    if (menor.contains("video") || menor.contains("display") || menor.contains("gpu") || menor.contains("vga")) return "Vídeo";
    if (menor.contains("audio") || menor.contains("som") || menor.contains("sound")) return "Áudio";
    if (menor.contains("network") || menor.contains("rede") || menor.contains("ethernet") || menor.contains("wi-fi")) return "Rede";
    if (menor.contains("usb")) return "USB";
    if (menor.contains("storage") || menor.contains("disk") || menor.contains("hd")) return "Armazenamento";
    if (menor.contains("printer") || menor.contains("impressora")) return "Impressora";
    if (menor.contains("keyboard") || menor.contains("mouse")) return "Entrada";
    return "Outro";
}

const QList<Dispositivo>& HardwareManager::todosDispositivos() const {
    return m_dispositivos;
}

DeviceModel* HardwareManager::modeloDispositivos() {
    return m_modelo;
}

void HardwareManager::iniciarMonitoramento(int intervaloMs) {
    m_timerMonitor->start(intervaloMs);
}

// ==========================================
// 📋 MODELO DE EXIBIÇÃO
// ==========================================
DeviceModel::DeviceModel(QObject *pai) : QAbstractListModel(pai) {}

int DeviceModel::rowCount(const QModelIndex &) const {
    return m_lista.size();
}

QVariant DeviceModel::data(const QModelIndex &indice, int papel) const {
    if (!indice.isValid() || indice.row() >= m_lista.size()) return {};
    const Dispositivo &dev = m_lista.at(indice.row());

    switch (papel) {
        case Nome: return dev.nome;
        case Tipo: return dev.tipo;
        case Status: return dev.status;
        case TemDriver: return dev.temDriver;
        case Icone: 
            if (dev.tipo == "Vídeo") return "🎬";
            if (dev.tipo == "Áudio") return "🔊";
            if (dev.tipo == "Rede") return "🌐";
            if (dev.tipo == "Armazenamento") return "💽";
            if (dev.tipo == "Impressora") return "🖨️";
            return "🔌";
        default: return {};
    }
}

QHash<int, QByteArray> DeviceModel::roleNames() const {
    static QHash<int, QByteArray> mapa {
        {Nome, "nome"}, {Tipo, "tipo"}, {Status, "status"},
        {TemDriver, "temDriver"}, {Icone, "icone"}
    };
    return mapa;
}

void DeviceModel::atualizarLista(const QList<Dispositivo> &lista) {
    beginResetModel();
    m_lista = lista;
    endResetModel();
}