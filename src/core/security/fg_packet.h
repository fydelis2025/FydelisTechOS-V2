#ifndef FG_PACKET_H
#define FG_PACKET_H

#include <QString>
#include <QHostAddress>
#include <QDateTime>

// ==========================================
// 📦 FG_PACKET — Estrutura de Pacote
// FydelisGuard · FydelisTech OS v2.0
// Salvador, Bahia 🇧🇷
// ==========================================

enum class FGBlockReason {
    Nenhum = 0,
    IP_ReputacaoRuim,
    SpoofingDetectado,
    TaxaExcedida,
    ProtocoloAnomalo,
    SemAssinaturaValida,
    SaltosExcedidos,
    HorarioAnomalo,
    TamanhoSuspeito,
    ListaNegraManual,
    CertificadoInvalido,
    CorrelacaoSuspeita
};

enum class FGVerdeito {
    Permitir = 0,
    Bloquear,
    Descartar,
    Desafiar,
    Quarentena
};

struct FGPacoteInfo {
    QHostAddress ipOrigem;
    QHostAddress ipDestino;
    quint16 portaOrigem = 0;
    quint16 portaDestino = 0;
    QString protocolo;
    qint64 tamanhoBytes = 0;
    QDateTime timestamp;
    int saltos = 0;
    bool temAssinatura = false;
    QString assinaturaRemetente;
    QString idDispositivo;
    QString impressaoDigital;
};

struct FGEvento {
    QDateTime horario;
    QHostAddress ip;
    FGBlockReason motivo;
    QString detalhe;
    FGVerdeito acaoTomada;
};

#endif // FG_PACKET_H