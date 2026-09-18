#include "fg_adminpanel.h"
#include "fydelisguard.h"
#include "fg_rules.h"
#include "fg_reputation.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLineEdit>
#include <QInputDialog>
#include <QMessageBox>
#include <QDateTime>

// ==========================================
// 🎛️ FG_ADMINPANEL — Interface de Controle
// FydelisGuard · FydelisTech OS v2.0
// Salvador, Bahia 🇧🇷
// ==========================================

FGAdminPanel::FGAdminPanel(QWidget* parent)
    : QDialog(parent)
{
    setWindowTitle("🛡️ FydelisGuard — Painel de Controle");
    resize(900, 650);
    setModal(true);

    // 🎨 Estilo — igual ao resto do sistema
    setStyleSheet(R"(
        QDialog {
            background: #0f172a;
            color: #f1f5f9;
        }
        QLabel { color: #e2e8f0; font-size: 13px; }
        QLabel#titulo { font-size: 18px; font-weight: bold; color: #00FF88; }
        QLabel#statusAtivo { color: #00FF88; font-weight: bold; }
        QLabel#statusInativo { color: #ef4444; font-weight: bold; }
        QPushButton {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 6px;
            padding: 10px 16px;
            color: #f1f5f9;
            font-weight: bold;
            min-height: 20px;
        }
        QPushButton:hover { background: #334155; border-color: #00AAFF; }
        QPushButton:pressed { background: #475569; }
        QPushButton#btnAtivar { background: #16a34a; }
        QPushButton#btnAtivar:hover { background: #15803d; }
        QPushButton#btnDesativar { background: #dc2626; }
        QPushButton#btnDesativar:hover { background: #b91c1c; }
        QPushButton#btnMaximo { background: #4f46e5; }
        QPushButton#btnMaximo:hover { background: #4338ca; }
        QTableWidget {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 8px;
            gridline-color: #334155;
        }
        QTableWidget::item { padding: 6px; }
        QHeaderView::section {
            background: #334155;
            color: #f1f5f9;
            padding: 8px;
            border: none;
            font-weight: bold;
        }
        QPushButton:disabled { background: #1e293b; color: #64748b; }
    )");

    montarInterface();
    atualizarListaEventos();
    atualizarEstatisticas();

    // ⏰ Atualizar a cada 5 segundos
    QTimer* timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, [=](){
        atualizarListaEventos();
        atualizarEstatisticas();
    });
    timer->start(5000);
}

void FGAdminPanel::montarInterface() {
    QVBoxLayout* layPrincipal = new QVBoxLayout(this);
    layPrincipal->setSpacing(12);
    layPrincipal->setContentsMargins(20, 20, 20, 20);

    // 📌 TÍTULO E STATUS
    QLabel* titulo = new QLabel("🛡️ FydelisGuard — Firewall de Segurança");
    titulo->setObjectName("titulo");
    layPrincipal->addWidget(titulo);

    QHBoxLayout* layStatus = new QHBoxLayout;
    layStatus->setSpacing(30);

    lblStatus = new QLabel();
    lblStatus->setObjectName(FydelisGuard::instancia().estaAtivo() ? "statusAtivo" : "statusInativo");
    lblStatus->setText(FydelisGuard::instancia().estaAtivo()
        ? "✅ SISTEMA ATIVO — Proteção em execução"
        : "⚠️ SISTEMA DESATIVADO — Vulnerável!");
    layStatus->addWidget(lblStatus);

    lblPermitidos = new QLabel("✅ Permitidos: 0");
    lblBloqueados = new QLabel("🚫 Bloqueados: 0");
    layStatus->addWidget(lblPermitidos);
    layStatus->addWidget(lblBloqueados);
    layStatus->addStretch();
    layPrincipal->addLayout(layStatus);

    // ⚙️ BOTÕES DE CONTROLE
    QHBoxLayout* layBotoes = new QHBoxLayout;
    layBotoes->setSpacing(10);

    btnAtivar = new QPushButton("🔒 Ativar Proteção");
    btnAtivar->setObjectName("btnAtivar");
    btnDesativar = new QPushButton("🔓 Desativar");
    btnDesativar->setObjectName("btnDesativar");
    btnModoMaximo = new QPushButton("🛡️ Proteção Máxima");
    btnModoMaximo->setObjectName("btnMaximo");
    QPushButton* btnLimpar = new QPushButton("🧹 Limpar Logs");
    QPushButton* btnSalvarRep = new QPushButton("💾 Salvar Reputação");
    QPushButton* btnCarregarRep = new QPushButton("📂 Carregar Reputação");

    layBotoes->addWidget(btnAtivar);
    layBotoes->addWidget(btnDesativar);
    layBotoes->addWidget(btnModoMaximo);
    layBotoes->addStretch();
    layBotoes->addWidget(btnLimpar);
    layBotoes->addWidget(btnSalvarRep);
    layBotoes->addWidget(btnCarregarRep);
    layPrincipal->addLayout(layBotoes);

    // 🚫 GERENCIAR LISTA NEGRA
    QGroupBox* grpNegra = new QGroupBox("Gerenciar Lista Negra");
    grpNegra->setStyleSheet("QGroupBox { color: #cbd5e1; font-weight: bold; border: 1px solid #334155; border-radius: 8px; margin-top: 10px; padding-top: 10px; }");
    QHBoxLayout* layNegra = new QHBoxLayout(grpNegra);

    btnAdicionarNegra = new QPushButton("➕ Bloquear IP");
    btnRemoverNegra = new QPushButton("➖ Desbloquear IP");
    layNegra->addWidget(btnAdicionarNegra);
    layNegra->addWidget(btnRemoverNegra);
    layNegra->addStretch();
    layPrincipal->addWidget(grpNegra);

    // 📋 TABELA DE EVENTOS
    tabelaEventos = new QTableWidget;
    tabelaEventos->setColumnCount(4);
    tabelaEventos->setHorizontalHeaderLabels({"Horário", "IP de Origem", "Motivo", "Ação"});
    tabelaEventos->horizontalHeader()->setSectionResizeMode(0, QHeaderView::ResizeToContents);
    tabelaEventos->horizontalHeader()->setSectionResizeMode(1, QHeaderView::Stretch);
    tabelaEventos->horizontalHeader()->setSectionResizeMode(2, QHeaderView::Stretch);
    tabelaEventos->horizontalHeader()->setSectionResizeMode(3, QHeaderView::ResizeToContents);
    tabelaEventos->verticalHeader()->setVisible(false);
    tabelaEventos->setAlternatingRowColors(true);
    tabelaEventos->setSelectionBehavior(QAbstractItemView::SelectRows);
    layPrincipal->addWidget(tabelaEventos);

    // 🔗 CONECTAR SINAIS
    connect(btnAtivar, &QPushButton::clicked, this, [=](){
        FydelisGuard::instancia().inicializar(false);
        atualizarEstatisticas();
        atualizarListaEventos();
        QMessageBox::information(this, "Ativado", "🛡️ FydelisGuard ativado com sucesso!");
    });

    connect(btnDesativar, &QPushButton::clicked, this, [=](){
        if (QMessageBox::warning(this, "Confirmação",
            "⚠️ Desativar o FydelisGuard deixa o sistema VULNERÁVEL!\n\nTem certeza?",
            QMessageBox::Yes | QMessageBox::No) == QMessageBox::Yes) {
            FydelisGuard::instancia().desativar();
            atualizarEstatisticas();
        }
    });

    connect(btnModoMaximo, &QPushButton::clicked, this, [=](){
        FydelisGuard::instancia().definirModoProtecao(true);
        FGRules::instancia().definirExigirAssinatura(true);
        QMessageBox::information(this, "Proteção Máxima",
            "🛡️ Modo Proteção Máxima ativado!\n- Exige assinatura digital\n- Bloqueia saltos > 2\n- Bloqueia protocolos desconhecidos");
    });

    connect(btnLimpar, &QPushButton::clicked, this, &FGAdminPanel::limparLogs);
    connect(btnAdicionarNegra, &QPushButton::clicked, this, &FGAdminPanel::adicionarIPListaNegra);
    connect(btnRemoverNegra, &QPushButton::clicked, this, &FGAdminPanel::removerIPListaNegra);

    connect(btnSalvarRep, &QPushButton::clicked, this, [=](){
        ReputationDB::instancia().salvar("FydelisSystem/reputacao.json");
        QMessageBox::information(this, "Salvo", "✅ Banco de reputação salvo!");
    });

    connect(btnCarregarRep, &QPushButton::clicked, this, [=](){
        ReputationDB::instancia().carregar("FydelisSystem/reputacao.json");
        QMessageBox::information(this, "Carregado", "✅ Banco de reputação carregado!");
    });
}

void FGAdminPanel::atualizarEstatisticas() {
    bool ativo = FydelisGuard::instancia().estaAtivo();
    lblStatus->setObjectName(ativo ? "statusAtivo" : "statusInativo");
    lblStatus->setText(ativo
        ? "✅ SISTEMA ATIVO — Proteção em execução"
        : "⚠️ SISTEMA DESATIVADO — Vulnerável!");

    lblPermitidos->setText(QString("✅ Permitidos: %1").arg(FydelisGuard::instancia().pacotesPermitidos()));
    lblBloqueados->setText(QString("🚫 Bloqueados: %1").arg(FydelisGuard::instancia().pacotesBloqueados()));

    btnAtivar->setEnabled(!ativo);
    btnDesativar->setEnabled(ativo);
}

void FGAdminPanel::atualizarListaEventos() {
    tabelaEventos->setRowCount(0);
    QList<FGEvento> eventos = FydelisGuard::instancia().ultimosEventos(50);

    for (int i = 0; i < eventos.size(); ++i) {
        const FGEvento& ev = eventos[i];
        tabelaEventos->insertRow(i);

        tabelaEventos->setItem(i, 0, new QTableWidgetItem(ev.horario.toString("HH:mm:ss")));
        tabelaEventos->setItem(i, 1, new QTableWidgetItem(ev.ip.toString()));

        QString motivoTexto;
        switch (ev.motivo) {
        case FGBlockReason::IP_ReputacaoRuim: motivoTexto = "⭐ Reputação ruim"; break;
        case FGBlockReason::SpoofingDetectado: motivoTexto = "🎭 Spoofing detectado"; break;
        case FGBlockReason::TaxaExcedida: motivoTexto = "🤖 Taxa excedida"; break;
        case FGBlockReason::ProtocoloAnomalo: motivoTexto = "🔍 Protocolo anômalo"; break;
        case FGBlockReason::SemAssinaturaValida: motivoTexto = "📝 Sem assinatura"; break;
        case FGBlockReason::SaltosExcedidos: motivoTexto = "🔄 Muitos saltos"; break;
        case FGBlockReason::CertificadoInvalido: motivoTexto = "🔒 Certificado inválido"; break;
        case FGBlockReason::ListaNegraManual: motivoTexto = "🚫 Lista negra"; break;
        default: motivoTexto = "Outro"; break;
        }
        tabelaEventos->setItem(i, 2, new QTableWidgetItem(motivoTexto));

        QString acaoTexto;
        switch (ev.acaoTomada) {
        case FGVerdeito::Permitir: acaoTexto = "✅ Permitido"; break;
        case FGVerdeito::Bloquear: acaoTexto = "🚫 Bloqueado"; break;
        case FGVerdeito::Quarentena: acaoTexto = "⚠️ Quarentena"; break;
        case FGVerdeito::Desafiar: acaoTexto = "❓ Verificar"; break;
        default: acaoTexto = "—"; break;
        }
        tabelaEventos->setItem(i, 3, new QTableWidgetItem(acaoTexto));
    }
}

void FGAdminPanel::adicionarIPListaNegra() {
    QString ipTexto = QInputDialog::getText(this, "Bloquear IP", "Digite o IP:");
    if (ipTexto.isEmpty()) return;

    QHostAddress ip(ipTexto);
    if (ip.isNull()) {
        QMessageBox::warning(this, "Erro", "IP inválido!");
        return;
    }

    FydelisGuard::instancia().adicionarListaNegra(ip, "Bloqueio manual");
    QMessageBox::information(this, "Bloqueado", QString("✅ IP %1 bloqueado!").arg(ipTexto));
}

void FGAdminPanel::removerIPListaNegra() {
    QString ipTexto = QInputDialog::getText(this, "Desbloquear IP", "Digite o IP:");
    if (ipTexto.isEmpty()) return;

    QHostAddress ip(ipTexto);
    FydelisGuard::instancia().removerListaNegra(ip);
    QMessageBox::information(this, "Desbloqueado", QString("✅ IP %1 removido da lista negra!").arg(ipTexto));
}

void FGAdminPanel::limparLogs() {
    if (QMessageBox::question(this, "Limpar", "Limpar todos os logs de eventos?")
        != QMessageBox::Yes) return;
    tabelaEventos->setRowCount(0);
}