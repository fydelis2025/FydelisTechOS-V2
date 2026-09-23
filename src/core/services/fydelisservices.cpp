#include "fydelisservices.h"
#include "../security/fydelisguard.h"
#include "../security/fydelisav.h"
#include <QDebug>

FydelisServices& FydelisServices::instancia() {
    static FydelisServices inst;
    return inst;
}

FydelisServices::FydelisServices() {
    inicializarListaServicos();
    
    // 🔄 Atualiza status a cada 5s
    m_timerMonitor = new QTimer(this);
    connect(m_timerMonitor, &QTimer::timeout, this, [=](){
        for (auto* serv : m_servicos) {
            if (serv->id == "firewall") {
                serv->status = FydelisGuard::instancia().estaAtivo() 
                    ? ServicoStatus::Executando : ServicoStatus::Parado;
            }
            if (serv->id == "antivirus") {
                serv->status = FydelisAV::instancia().estaAtivo()
                    ? ServicoStatus::Executando : ServicoStatus::Parado;
            }
        }
    });
    m_timerMonitor->start(5000);
}

void FydelisServices::inicializarListaServicos() {
    // 🔥 FIREWALL — FydelisGuard
    auto* fw = new ServicoModel;
    fw->id = "firewall";
    fw->nomeExibicao = "FydelisGuard — Firewall";
    fw->descricao = "Monitoramento e bloqueio de conexões de rede";
    fw->icone = ":/fydelis/icons/hardware/placa_rede.png";
    fw->versao = "2.0.0";
    fw->tipoInicio = Inicializacao::Automatico;
    fw->status = ServicoStatus::Parado;
    m_servicos.append(fw);

    // 🛡️ ANTIVÍRUS — FydelisAV
    auto* av = new ServicoModel;
    av->id = "antivirus";
    av->nomeExibicao = "FydelisAV — Antivírus";
    av->descricao = "Verificação de arquivos, detecção de ameaças em tempo real";
    av->icone = ":/fydelis/icons/security/shield.png";
    av->versao = "1.0.0";
    av->tipoInicio = Inicializacao::Automatico;
    av->status = ServicoStatus::Parado;
    m_servicos.append(av);

    // 🔐 REPUTAÇÃO
    auto* rep = new ServicoModel;
    rep->id = "reputation";
    rep->nomeExibicao = "Banco de Reputação";
    rep->descricao = "Avaliação de IPs e padrões de tráfego";
    rep->icone = ":/fydelis/icons/security/star.png";
    rep->versao = "1.0.0";
    rep->tipoInicio = Inicializacao::Automatico;
    rep->status = ServicoStatus::Executando;
    m_servicos.append(rep);
}

bool FydelisServices::iniciarServico(const QString& id) {
    if (id == "firewall") {
        FydelisGuard::instancia().inicializar(false);
        emit servicoStatusAlterado(id, ServicoStatus::Executando);
        return true;
    }
    if (id == "antivirus") {
        FydelisAV::instancia().inicializar();
        emit servicoStatusAlterado(id, ServicoStatus::Executando);
        return true;
    }
    return false;
}

bool FydelisServices::pararServico(const QString& id) {
    if (id == "firewall") {
        FydelisGuard::instancia().desativar();
        emit servicoStatusAlterado(id, ServicoStatus::Parado);
        return true;
    }
    if (id == "antivirus") {
        FydelisAV::instancia().desativar();
        emit servicoStatusAlterado(id, ServicoStatus::Parado);
        return true;
    }
    return false;
}

QList<ServicoModel*> FydelisServices::todosServicos() {
    return m_servicos;
}

ServicoModel* FydelisServices::obterServico(const QString& id) {
    for (auto* s : m_servicos)
        if (s->id == id) return s;
    return nullptr;
}