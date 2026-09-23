#include "hardwarepanel.h"
#include "driverinstaller.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QMessageBox>

// ==========================================
// 🖥️ PAINEL DE HARDWARE E DRIVERS
// FydelisTech OS v2.0 · Salvador 🇧🇷
// ==========================================

HardwarePanel::HardwarePanel(QWidget *pai) : QDialog(pai) {
    setWindowTitle("🔧 Hardware e Drivers — FydelisTech OS");
    resize(900, 650);

    setStyleSheet(R"(
        QDialog { background: #0f172a; color: #f1f5f9; font-family: Segoe UI, sans-serif; }
        QLabel { color: #e2e8f0; }
        QLabel#titulo { font-size: 18px; font-weight: bold; }
        QLabel#semDriver { color: #f87171; font-weight: bold; }
        QLabel#comDriver { color: #34d399; font-weight: bold; }
        QPushButton {
            background: #4f46e5; border: none; border-radius: 8px;
            padding: 10px 16px; font-weight: bold; min-height: 20px;
        }
        QPushButton:hover { background: #6366f1; }
        QPushButton:pressed { background: #4338ca; }
        QPushButton:disabled { background: #374151; color: #6b7280; }
        QPushButton#baixar { background: #10b981; }
        QPushButton#baixar:hover { background: #34d399; }
        QPushButton#instalar { background: #f59e0b; }
        QPushButton#instalar:hover { background: #fbbf24; }
        QPushButton#verificar { background: #3b82f6; }
        QPushButton#verificar:hover { background: #60a5fa; }
        QListView {
            background: #020617; border: 2px solid #1e293b; border-radius: 10px;
            padding: 6px; font-size: 14px;
        }
        QListView::item { padding: 8px; border-radius: 6px; margin: 2px; }
        QListView::item:selected { background: #4f46e5; }
        QGroupBox {
            border: 1px solid #334155; border-radius: 8px; margin-top: 10px;
            padding-top: 10px; font-weight: bold; color: #94a3b8;
        }
    )");

    montarInterface();
    atualizarLista();
}

void HardwarePanel::montarInterface() {
    QVBoxLayout *layPrincipal = new QVBoxLayout(this);
    layPrincipal->setContentsMargins(20, 20, 20, 20);
    layPrincipal->setSpacing(16);

    // 📊 Cabeçalho
    QHBoxLayout *layCab = new QHBoxLayout;
    QLabel *titulo = new QLabel("🔧 Dispositivos Conectados");
    titulo->setObjectName("titulo");
    layCab->addWidget(titulo);
    layCab->addStretch();

    m_lblTotal = new QLabel;
    m_lblSemDriver = new QLabel;
    m_lblSemDriver->setObjectName("semDriver");
    layCab->addWidget(m_lblTotal);
    layCab->addSpacing(16);
    layCab->addWidget(m_lblSemDriver);
    layPrincipal->addLayout(layCab);

    // 📋 Lista
    m_listaDispositivos = new QListView;
    connect(m_listaDispositivos, &QListView::clicked,
            this, &HardwarePanel::dispositivoSelecionado);
    layPrincipal->addWidget(m_listaDispositivos);

    // ⚙️ Detalhes
    QGroupBox *grpDetalhes = new QGroupBox("📋 Detalhes do Dispositivo");
    QVBoxLayout *layDet = new QVBoxLayout(grpDetalhes);

    m_nomeDispositivo = new QLabel("Selecione um dispositivo acima");
    m_nomeDispositivo->setStyleSheet("font-size: 15px; font-weight: bold;");
    layDet->addWidget(m_nomeDispositivo);

    m_fabricante = new QLabel;
    m_tipo = new QLabel;
    m_status = new QLabel;
    m_versaoDriver = new QLabel;
    layDet->addWidget(m_fabricante);
    layDet->addWidget(m_tipo);
    layDet->addWidget(m_status);
    layDet->addWidget(m_versaoDriver);

    m_progresso = new QLabel;
    m_progresso->setVisible(false);
    layDet->addWidget(m_progresso);

    layPrincipal->addWidget(grpDetalhes);

    // 🎯 Ações
    QHBoxLayout *layAcoes = new QHBoxLayout;

    m_btnVerificar = new QPushButton("🔄 Verificar Novamente");
    m_btnVerificar->setObjectName("verificar");
    connect(m_btnVerificar, &QPushButton::clicked, this, &HardwarePanel::verificarNovamente);
    layAcoes->addWidget(m_btnVerificar);

    layAcoes->addStretch();

    m_btnBaixar = new QPushButton("📥 Baixar Driver");
    m_btnBaixar->setObjectName("baixar");
    m_btnBaixar->setEnabled(false);
    connect(m_btnBaixar, &QPushButton::clicked, this, &HardwarePanel::baixarDriverAtual);
    layAcoes->addWidget(m_btnBaixar);

    m_btnInstalar = new QPushButton("⚙️ Instalar");
    m_btnInstalar->setObjectName("instalar");
    m_btnInstalar->setEnabled(false);
    connect(m_btnInstalar, &QPushButton::clicked, this, &HardwarePanel::instalarDriver);
    layAcoes->addWidget(m_btnInstalar);

    layPrincipal->addLayout(layAcoes);
}

void HardwarePanel::atualizarLista() {
    auto &hw = HardwareManager::instancia();
    hw.escanearHardware();
    m_listaDispositivos->setModel(hw.modeloDispositivos());

    const auto &lista = hw.todosDispositivos();
    int semDriver = 0;
    for (const auto &d : lista) if (!d.temDriver) semDriver++;

    m_lblTotal->setText(QString("Total: %1 dispositivo(s)").arg(lista.size()));
    m_lblSemDriver->setText(semDriver > 0 ? QString("⚠️ Sem driver: %1").arg(semDriver) : "✅ Todos com driver");
}

void HardwarePanel::dispositivoSelecionado(const QModelIndex &indice) {
    auto &hw = HardwareManager::instancia();
    m_dispositivoAtual = hw.todosDispositivos().at(indice.row());

    m_nomeDispositivo->setText(m_dispositivoAtual.nome);
    m_fabricante->setText("🏭 Fabricante: " + m_dispositivoAtual.fabricante);
    m_tipo->setText("📦 Tipo: " + m_dispositivoAtual.tipo);
    m_status->setText(QString("🔍 Status: %1").arg(m_dispositivoAtual.temDriver ? "✅ Funcionando" : "⚠️ Sem driver"));
    m_versaoDriver->setText("🔖 Versão: " + (m_dispositivoAtual.versaoDriver.isEmpty() ? "—" : m_dispositivoAtual.versaoDriver));

    bool precisa = !m_dispositivoAtual.temDriver;
    m_btnBaixar->setEnabled(precisa && !m_dispositivoAtual.urlDownload.isEmpty());
    m_btnInstalar->setEnabled(!m_caminhoDriverBaixado.isEmpty());
}

void HardwarePanel::verificarNovamente() {
    atualizarLista();
    QMessageBox::information(this, "Verificação", "✅ Escaneamento concluído!");
}

void HardwarePanel::baixarDriverAtual() {
    m_progresso->setVisible(true);
    m_progresso->setText("⏳ Baixando...");
    m_btnBaixar->setEnabled(false);

    auto &dl = DriverInstaller::instancia();
    connect(&dl, &DriverInstaller::progressoBaixado, this, [this](int p){
        m_progresso->setText(QString("📥 Baixando: %1%").arg(p));
    });
    connect(&dl, &DriverInstaller::baixadoComSucesso, this, [this](const QString &caminho){
        m_caminhoDriverBaixado = caminho;
        m_progresso->setText("✅ Baixado! Pronto para instalar.");
        m_btnInstalar->setEnabled(true);
    });
    connect(&dl, &DriverInstaller::erroBaixado, this, [this](const QString &erro){
        m_progresso->setText("❌ Erro: " + erro);
        m_btnBaixar->setEnabled(true);
    });

    dl.baixarDriver(m_dispositivoAtual.urlDownload, m_dispositivoAtual.id);
}

void HardwarePanel::instalarDriver() {
    QMessageBox::StandardButton resp = QMessageBox::question(
        this, "Confirmar Instalação",
        "Deseja instalar o driver agora?\nIsso pode demorar alguns minutos.");
    if (resp != QMessageBox::Yes) return;

    m_progresso->setText("⚙️ Instalando...");
    m_btnInstalar->setEnabled(false);

    auto &dl = DriverInstaller::instancia();
    connect(&dl, &DriverInstaller::instalacaoConcluida, this, [this](bool ok, QString msg){
        m_progresso->setText(msg);
        if (ok) {
            QMessageBox::information(this, "Concluído", msg);
            atualizarLista();
        } else {
            QMessageBox::warning(this, "Aviso", msg);
        }
    });

    dl.instalarDriver(m_caminhoDriverBaixado, m_dispositivoAtual.id);
}