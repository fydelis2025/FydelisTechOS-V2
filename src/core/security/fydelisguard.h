#ifndef FYDELISGUARD_H
#define FYDELISGUARD_H

#include <QObject>
#include <QString>
#include <QHostAddress>
#include <QDateTime>
#include <QMutex>
#include <QTimer>

// ==========================================
// 🛡️ FYDELISGUARD — Firewall & Security Core
// Defesa em múltiplas camadas · FydelisTech OS
// Salvador, Bahia 🇧🇷 — v2.0
// ==========================================

// 🚫 Motivos de bloqueio
enum class FGBlockReason {
    Nenhum = 0,
    IP_ReputacaoRuim,        // ⭐ Origem com histórico suspeito
    SpoofingDetectado,       // 🎭 Origem falsificada
    TaxaExcedida,            // 🤖 Ataque em massa / automação
    ProtocoloAnomalo,        // 🔍 Assinatura de protocolo estranha
    SemAssinaturaValida,     // 📝 Mensagem sem assinatura confiável
    SaltosExcedidos,         // 🔄 Muitos encaminhamentos (ocultação)
    HorarioAnomalo,          // ⏰ Fora do padrão de uso
    TamanhoSuspeito,         // 📦 Pacote com tamanho inválido
    ListaNegraManual,        // 🚫 Bloqueio administrativo
    CertificadoInvalido,    // 🔒 Certificado/criptografia falsa
    CorrelacaoSuspeita       // 🕵️ Correlação de dados suspeita
};

// ⚖️ Veredito do pacote
enum class FGVerdeito {
    Permitir = 0,
    Bloquear,
    Descartar,
    Desafiar,    // ⚠️ Exige verificação extra antes de liberar
    Quarentena   // 🧪 Monitorar e analisar antes de permitir
};

// 📦 Dados do pacote inspecionado
struct FGPacoteInfo {
    QHostAddress ipOrigem;
    QHostAddress ipDestino;
    quint16 portaOrigem = 0;
    quint16 portaDestino = 0;
    QString protocolo;       // TCP / UDP / WebSocket / HTTPS / Fydelis
    qint64 tamanhoBytes = 0;
    QDateTime timestamp;
    int saltos = 0;          // 🔄 Quantos servidores intermediários
    bool temAssinatura = false;
    QString assinaturaRemetente;
    QString idDispositivo;
    QString impressaoDigital; // 🔍 Hash único de protocolo + comportamento
};

// 📜 Registro de evento
struct FGEvento {
    QDateTime horario;
    QHostAddress ip;
    FGBlockReason motivo;
    QString detalhe;
    FGVerdeito acaoTomada;
};

class FydelisGuard : public QObject {
    Q_OBJECT
public:
    static FydelisGuard& instancia();

    // ✅ Inicialização
    bool inicializar(bool modoProtecaoMaxima = false);
    void desativar();
    bool estaAtivo() const;

    // 🔍 INSPEÇÃO PRINCIPAL — Ponto central de defesa
    FGVerdeito inspecionarPacote(const FGPacoteInfo& pacote);

    // ⚙️ Controles administrativos
    void adicionarListaNegra(const QHostAddress& ip, const QString& motivo = "");
    void removerListaNegra(const QHostAddress& ip);
    void definirLimiteTaxa(int pacotesPorMinuto);
    void definirModoProtecao(bool maximo);

    // 📋 Logs e estatísticas
    QList<FGEvento> ultimosEventos(int limite = 100) const;
    int pacotesBloqueados() const;
    int pacotesPermitidos() const;

signals:
    void ameacaDetectada(FGBlockReason motivo, const FGPacoteInfo& pacote);
    void limiteAtingido(const QHostAddress& ip);
    void protecaoAtivada();
    void protecaoDesativada();

private slots:
    void verificarTaxaPeriodicamente();

private:
    explicit FydelisGuard(QObject* parent = nullptr);
    ~FydelisGuard() = default;
    FydelisGuard(const FydelisGuard&) = delete;
    FydelisGuard& operator=(const FydelisGuard&) = delete;

    // 🔬 MÉTODOS DE DETECÇÃO — CADA CAMADA DE DEFESA
    FGVerdeito verificarReputacao(const FGPacoteInfo& pacote);
    FGVerdeito verificarSpoofing(const FGPacoteInfo& pacote);
    FGVerdeito verificarTaxa(const FGPacoteInfo& pacote);
    FGVerdeito verificarProtocolo(const FGPacoteInfo& pacote);
    FGVerdeito verificarAssinatura(const FGPacoteInfo& pacote);
    FGVerdeito verificarSaltos(const FGPacoteInfo& pacote);
    FGVerdeito verificarCertificado(const FGPacoteInfo& pacote);

    void registrarEvento(const FGPacoteInfo& pacote, FGBlockReason motivo, FGVerdeito acao);

    // 📊 Estado interno
    bool m_ativo = false;
    bool m_protecaoMaxima = false;
    int m_limitePacotesPorMinuto = 60;

    // 📋 Bancos de dados internos
    QSet<QHostAddress> m_listaNegraIP;
    QMap<QHostAddress, QList<QDateTime>> m_contagemAcessos;
    QList<FGEvento> m_eventos;

    mutable QMutex m_mutex;
    QTimer* m_timerVerificacao;
};

#endif // FYDELISGUARD_H