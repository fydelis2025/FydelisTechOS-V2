#include "fydelisguard.h"
#include "fg_reputation.h"
#include "fg_inspector.h"
#include <QCoreApplication>
#include <QDebug>
#include <algorithm>

// ==========================================
// 🛡️ FYDELISGUARD — IMPLEMENTAÇÃO
// ==========================================

FydelisGuard& FydelisGuard::instancia() {
    static FydelisGuard inst;
    return inst;
}

FydelisGuard::FydelisGuard(QObject* parent)
    : QObject(parent)
{
    m_timerVerificacao = new QTimer(this);
    connect(m_timerVerificacao, &QTimer::timeout,
            this, &FydelisGuard::verificarTaxaPeriodicamente);
}

bool FydelisGuard::inicializar(bool modoProtecaoMaxima) {
    QMutexLocker locker(&m_mutex);

    m_protecaoMaxima = modoProtecaoMaxima;
    m_ativo = true;

    // ⏰ Limpar contagem de taxa a cada minuto
    m_timerVerificacao->start(60000);

    qInfo() << "🛡️ FydelisGuard ATIVADO — Modo:"
            << (modoProtecaoMaxima ? "PROTEÇÃO MÁXIMA" : "PADRÃO");

    emit protecaoAtivada();
    return true;
}

void FydelisGuard::desativar() {
    QMutexLocker locker(&m_mutex);
    m_ativo = false;
    m_timerVerificacao->stop();
    qWarning() << "⚠️ FydelisGuard DESATIVADO — Sistema vulnerável!";
    emit protecaoDesativada();
}

bool FydelisGuard::estaAtivo() const {
    return m_ativo;
}

// ==========================================
// 🔍 INSPEÇÃO PRINCIPAL — CAMADAS DE DEFESA
// ==========================================

FGVerdeito FydelisGuard::inspecionarPacote(const FGPacoteInfo& pacote) {
    if (!m_ativo) return FGVerdeito::Permitir;

    // 🔒 CAMADA 1 — Lista Negra Administrativa
    if (m_listaNegraIP.contains(pacote.ipOrigem)) {
        registrarEvento(pacote, FGBlockReason::ListaNegraManual, FGVerdeito::Bloquear);
        emit ameacaDetectada(FGBlockReason::ListaNegraManual, pacote);
        return FGVerdeito::Bloquear;
    }

    // ⭐ CAMADA 2 — Reputação de Origem
    FGVerdeito vReputacao = verificarReputacao(pacote);
    if (vReputacao != FGVerdeito::Permitir) return vReputacao;

    // 🎭 CAMADA 3 — Detecção de Spoofing/Origem Falsa
    FGVerdeito vSpoofing = verificarSpoofing(pacote);
    if (vSpoofing != FGVerdeito::Permitir) return vSpoofing;

    // 🤖 CAMADA 4 — Limite de Taxa / Automação em Massa
    FGVerdeito vTaxa = verificarTaxa(pacote);
    if (vTaxa != FGVerdeito::Permitir) return vTaxa;

    // 🔍 CAMADA 5 — Assinatura de Protocolo Anômala
    FGVerdeito vProtocolo = verificarProtocolo(pacote);
    if (vProtocolo != FGVerdeito::Permitir) return vProtocolo;

    // 📝 CAMADA 6 — Assinatura Digital Válida
    FGVerdeito vAssinatura = verificarAssinatura(pacote);
    if (vAssinatura != FGVerdeito::Permitir) return vAssinatura;

    // 🔄 CAMADA 7 — Muitos Saltos / Encaminhamento Oculto
    FGVerdeito vSaltos = verificarSaltos(pacote);
    if (vSaltos != FGVerdeito::Permitir) return vSaltos;

    // 🔒 CAMADA 8 — Certificado e Criptografia
    FGVerdeito vCert = verificarCertificado(pacote);
    if (vCert != FGVerdeito::Permitir) return vCert;

    // ✅ TODAS AS CAMADAS APROVADAS
    return FGVerdeito::Permitir;
}

// ==========================================
// 🔬 MÉTODOS DE DETECÇÃO — Implementação
// ==========================================

FGVerdeito FydelisGuard::verificarReputacao(const FGPacoteInfo& pacote) {
    // ⭐ Consulta banco de reputação (fg_reputation.h)
    int pontuacao = ReputationDB::instancia().pontuacaoIP(pacote.ipOrigem);
    if (pontuacao < -50) {
        registrarEvento(pacote, FGBlockReason::IP_ReputacaoRuim, FGVerdeito::Bloquear);
        emit ameacaDetectada(FGBlockReason::IP_ReputacaoRuim, pacote);
        return FGVerdeito::Bloquear;
    }
    return FGVerdeito::Permitir;
}

FGVerdeito FydelisGuard::verificarSpoofing(const FGPacoteInfo& pacote) {
    // 🎭 Verifica se IP é de origem conhecida ou suspeita de falsificação
    if (FGInspector::detectarSpoofing(pacote)) {
        registrarEvento(pacote, FGBlockReason::SpoofingDetectado, FGVerdeito::Bloquear);
        emit ameacaDetectada(FGBlockReason::SpoofingDetectado, pacote);
        return FGVerdeito::Bloquear;
    }
    return FGVerdeito::Permitir;
}

FGVerdeito FydelisGuard::verificarTaxa(const FGPacoteInfo& pacote) {
    QList<QDateTime>& lista = m_contagemAcessos[pacote.ipOrigem];
    lista.append(QDateTime::currentDateTime());

    // Remove entradas com mais de 1 minuto
    lista.erase(std::remove_if(lista.begin(), lista.end(),
        [](const QDateTime& dt) {
            return dt.secsTo(QDateTime::currentDateTime()) > 60;
        }), lista.end());

    if (lista.size() > m_limitePacotesPorMinuto) {
        registrarEvento(pacote, FGBlockReason::TaxaExcedida, FGVerdeito::Quarentena);
        emit limiteAtingido(pacote.ipOrigem);
        return FGVerdeito::Quarentena;
    }
    return FGVerdeito::Permitir;
}

FGVerdeito FydelisGuard::verificarProtocolo(const FGPacoteInfo& pacote) {
    // 🔍 Compara impressão digital do protocolo com assinaturas conhecidas
    if (FGInspector::protocoloAnomalo(pacote)) {
        registrarEvento(pacote, FGBlockReason::ProtocoloAnomalo, FGVerdeito::Desafiar);
        return m_protecaoMaxima ? FGVerdeito::Bloquear : FGVerdeito::Desafiar;
    }
    return FGVerdeito::Permitir;
}

FGVerdeito FydelisGuard::verificarAssinatura(const FGPacoteInfo& pacote) {
    // 📝 Exige assinatura válida em modo proteção máxima
    if (m_protecaoMaxima && !pacote.temAssinatura) {
        registrarEvento(pacote, FGBlockReason::SemAssinaturaValida, FGVerdeito::Bloquear);
        emit ameacaDetectada(FGBlockReason::SemAssinaturaValida, pacote);
        return FGVerdeito::Bloquear;
    }
    return FGVerdeito::Permitir;
}

FGVerdeito FydelisGuard::verificarSaltos(const FGPacoteInfo& pacote) {
    // 🔄 Mais de 3 saltos = provável ocultação de origem
    if (pacote.saltos > 3) {
        registrarEvento(pacote, FGBlockReason::SaltosExcedidos, FGVerdeito::Desafiar);
        return m_protecaoMaxima ? FGVerdeito::Bloquear : FGVerdeito::Desafiar;
    }
    return FGVerdeito::Permitir;
}

FGVerdeito FydelisGuard::verificarCertificado(const FGPacoteInfo& pacote) {
    // 🔒 Valida certificado/cadeia de confiança
    if (FGInspector::certificadoInvalido(pacote)) {
        registrarEvento(pacote, FGBlockReason::CertificadoInvalido, FGVerdeito::Bloquear);
        emit ameacaDetectada(FGBlockReason::CertificadoInvalido, pacote);
        return FGVerdeito::Bloquear;
    }
    return FGVerdeito::Permitir;
}

// ==========================================
// ⚙️ UTILITÁRIOS E REGISTROS
// ==========================================

void FydelisGuard::registrarEvento(const FGPacoteInfo& pacote,
                                    FGBlockReason motivo,
                                    FGVerdeito acao) {
    QMutexLocker locker(&m_mutex);
    FGEvento ev;
    ev.horario = QDateTime::currentDateTime();
    ev.ip = pacote.ipOrigem;
    ev.motivo = motivo;
    ev.detalhe = QString("%1:%2 → %3").arg(pacote.protocolo)
        .arg(pacote.portaOrigem).arg(pacote.tamanhoBytes);
    ev.acaoTomada = acao;
    m_eventos.prepend(ev);
    if (m_eventos.size() > 1000) m_eventos.removeLast();
}

void FydelisGuard::verificarTaxaPeriodicamente() {
    QMutexLocker locker(&m_mutex);
    m_contagemAcessos.clear(); // Limpa contadores a cada minuto
}

void FydelisGuard::adicionarListaNegra(const QHostAddress& ip, const QString&) {
    QMutexLocker locker(&m_mutex);
    m_listaNegraIP.insert(ip);
    qInfo() << "🚫 IP adicionado à lista negra:" << ip.toString();
}

void FydelisGuard::removerListaNegra(const QHostAddress& ip) {
    QMutexLocker locker(&m_mutex);
    m_listaNegraIP.remove(ip);
}

void FydelisGuard::definirLimiteTaxa(int pacotesPorMinuto) {
    QMutexLocker locker(&m_mutex);
    m_limitePacotesPorMinuto = pacotesPorMinuto;
}

void FydelisGuard::definirModoProtecao(bool maximo) {
    QMutexLocker locker(&m_mutex);
    m_protecaoMaxima = maximo;
}

QList<FGEvento> FydelisGuard::ultimosEventos(int limite) const {
    QMutexLocker locker(&m_mutex);
    return m_eventos.mid(0, limite);
}

int FydelisGuard::pacotesBloqueados() const {
    QMutexLocker locker(&m_mutex);
    int count = 0;
    for (const auto& e : m_eventos)
        if (e.acaoTomada == FGVerdeito::Bloquear) count++;
    return count;
}

int FydelisGuard::pacotesPermitidos() const {
    QMutexLocker locker(&m_mutex);
    return m_eventos.size() - pacotesBloqueados();
}