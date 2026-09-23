#include "partitionmanager.h"
#include <QStorageInfo>
#include <QDebug>
#include <QProcess>
#include <QRegularExpression>

// ⚙️ CONFIGURAÇÕES
#define ESPACO_MINIMO_INSTALACAO  (8LL * 1024 * 1024 * 1024) // 8 GB em bytes

PartitionManager::PartitionManager(QObject *parent)
    : QObject(parent)
{
}

// ==========================================
// 💽 LISTAR DISCOS E PARTIÇÕES DISPONÍVEIS
// ==========================================
QList<Particao> PartitionManager::listarDiscos()
{
    m_discos.clear();

#ifdef Q_OS_LINUX
    // 🐧 Linux: ler do /sys/block e /proc/partitions
    QProcess proc;
    proc.start("lsblk", QStringList() << "-b" << "-P" << "-o" << "NAME,SIZE,TYPE,MOUNTPOINT,LABEL");
    proc.waitForFinished(3000);

    QString saida = QString::fromUtf8(proc.readAllStandardOutput());
    QStringList linhas = saida.split('\n', Qt::SkipEmptyParts);

    for (const QString &linha : linhas) {
        // Extrair campos: NAME="sda" SIZE="123456789" TYPE="part" ...
        QRegularExpression re("NAME=\"([^\"]+)\"\\s+SIZE=\"(\\d+)\"\\s+TYPE=\"(\\w+)\"\\s+MOUNTPOINT=\"([^\"]*)\"\\s+LABEL=\"([^\"]*)\"");
        auto match = re.match(linha);
        if (!match.hasMatch()) continue;

        QString tipo = match.captured(3);
        if (tipo != "part" && tipo != "disk") continue;

        Particao p;
        p.dispositivo = "/dev/" + match.captured(1);
        p.nome = match.captured(5);
        if (p.nome.isEmpty()) p.nome = (tipo == "disk") ? "Disco " + match.captured(1) : "Partição " + match.captured(1);
        p.tamanhoTotal = match.captured(2).toLongLong();
        p.tamanhoUsado = 0; // Será calculado se montado
        p.selecionada = false;
        p.instalarAqui = false;
        p.usarDiscoInteiro = (tipo == "disk");

        m_discos.append(p);
    }
#endif

#ifdef Q_OS_WIN
    // 🪟 Windows: usar QStorageInfo
    for (const QStorageInfo &info : QStorageInfo::mountedVolumes()) {
        if (info.isValid() && !info.isReadOnly() && info.isReady()) {
            Particao p;
            p.dispositivo = info.rootPath();
            p.nome = info.displayName();
            if (p.nome.isEmpty()) p.nome = p.dispositivo;
            p.tamanhoTotal = info.bytesTotal();
            p.tamanhoUsado = info.bytesTotal() - info.bytesAvailable();
            p.selecionada = false;
            p.instalarAqui = false;
            p.usarDiscoInteiro = false;
            m_discos.append(p);
        }
    }
#endif

    qDebug() << "✅ Discos/partições encontradas:" << m_discos.size();
    return m_discos;
}

// ==========================================
// ✅ VALIDAR SE A PARTIÇÃO TEM ESPAÇO SUFICIENTE
// ==========================================
bool PartitionManager::validarParticao(const Particao &p)
{
    if (p.tamanhoTotal < espacoNecessario()) {
        qWarning() << "❌ Espaço insuficiente. Necessário:" << espacoNecessario()/(1024*1024*1024) << "GB";
        return false;
    }
    return true;
}

// ==========================================
// 📏 ESPAÇO MÍNIMO NECESSÁRIO PARA INSTALAR
// ==========================================
qint64 PartitionManager::espacoNecessario()
{
    return ESPACO_MINIMO_INSTALACAO; // 8 GB
}

// ==========================================
// 💽 PARTICIONAR DISCO INTEIRO
// ==========================================
bool PartitionManager::particionarDiscoInteiro(const QString &dispositivo)
{
    qDebug() << "⚠️ Particionando disco inteiro:" << dispositivo;

#ifdef Q_OS_LINUX
    // 🐧 Linux: criar tabela de partição GPT e partição única
    QProcess::execute("parted", QStringList() << "-s" << dispositivo << "mklabel" << "gpt");
    QProcess::execute("parted", QStringList() << "-s" << dispositivo << "mkpart" << "primary" << "0%" << "100%");
    QProcess::execute("partprobe", QStringList() << dispositivo);
    return true;
#endif

#ifdef Q_OS_WIN
    // 🪟 Windows: particionamento será feito pelo instalador sem formatação automática
    qWarning() << "⚠️ No Windows, selecione a partição manualmente";
    return true;
#endif

    return false;
}

// ==========================================
// 📂 CRIAR PARTIÇÃO PERSONALIZADA
// ==========================================
bool PartitionManager::criarParticao(const QString &dispositivo, qint64 inicio, qint64 fim)
{
    qDebug() << "📂 Criando partição:" << dispositivo << inicio << fim;

#ifdef Q_OS_LINUX
    QString inicioMB = QString::number(inicio / (1024*1024)) + "M";
    QString fimMB = QString::number(fim / (1024*1024)) + "M";

    QProcess proc;
    proc.start("parted", QStringList() << "-s" << dispositivo << "mkpart" << "primary" << inicioMB << fimMB);
    proc.waitForFinished(5000);
    return (proc.exitCode() == 0);
#endif

    return true;
}

// ==========================================
// 🚀 INSTALAR GRUB (BOOTLOADER — LINUX)
// ==========================================
bool PartitionManager::instalarGRUB(const QString &dispositivo)
{
    qDebug() << "🚀 Instalando GRUB em:" << dispositivo;

#ifdef Q_OS_LINUX
    // Em instalação real: chroot e grub-install
    // Aqui simulamos o sucesso
    QProcess::execute("grub-install", QStringList() << "--target=x86_64-efi" << "--efi-directory=/mnt/boot/efi" << "--root-directory=/mnt" << dispositivo);
    QProcess::execute("update-grub");
    return true;
#endif

    // No Windows: bootloader nativo
    return true;
}