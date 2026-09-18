#include "controlpanel.h"
#include "thememanager.h"
#include "configmanager.h"
#include "hardwarepanel.h"   // ✅ ESTA LINHA!
#include "hardwaremanager.h"
#include <QIcon>
#include <QListWidgetItem>
#include <QMessageBox>
#include <QSpinBox>
#include <QRadioButton>
#include <QProgressBar>
#include "services/servicemanagerpanel.h"
#include "../core/security/fydelisguard.h"  // 🔥 Firewall
#include "../core/security/fg_reputation.h" // ⭐ Reputação
#include "../core/security/fydelisav.h"     // 🛡️ Antivírus
#include "update/updatepanel.h"


// ==========================================
// 🎛️ PAINEL DE CONTROLE — FYDELIS TECH OS
// Conectado ao SQLite → FydelisSystem/database/config.db
// De Salvador • Bahia 🇧🇷
// ==========================================
ControlPanel::ControlPanel(QWidget *parent) : QDialog(parent) {
    setWindowTitle("Painel de Controle — FydelisTech OS");
    resize(960, 600);
    setModal(true);

    // ✅ GARANTIR QUE O BANCO ESTÁ PRONTO
    ConfigManager::instancia().inicializar();

    // 🎨 CARREGAR TEMA AUTOMATICAMENTE
    auto &tema = ThemeManager::instancia();
    // 🎯 APLICAR CORES DO TEMA — SUBSTITUI AS CORES FIXAS
    setStyleSheet(QString(R"(
        QDialog { background: %1; color: %2; }
        QListWidget {
            background: rgba(30, 20, 70, 0.6); border: none; padding: 8px;
            font-size: 14px; outline: none;
        }
        QListWidget::item {
            padding: 10px; margin: 2px; border-radius: 6px;
        }
        QListWidget::item:selected {
            background: #4f46e5; color: white;
        }
        QWidget#pagina { background: rgba(30, 20, 70, 0.3); padding: 16px; }
        QLabel { color: %2; font-size: 14px; }
        QGroupBox {
            border: 1px solid rgba(140, 180, 255, 0.3); border-radius: 8px;
            margin-top: 12px; padding: 12px; font-weight: bold;
            color: %3;
        }
        QPushButton {
            background: #4f46e5; border: none; border-radius: 6px;
            padding: 8px 16px; color: white; font-weight: bold;
        }
        QPushButton:hover { background: #6366f1; }
        QLineEdit, QComboBox, QSlider, QSpinBox {
            background: rgba(30, 20, 70, 0.6); border: 1px solid rgba(140, 180, 255, 0.3);
            border-radius: 4px; padding: 6px; color: white;
        }
        QCheckBox { color: %2; }
        QPushButton#btnSecundario {
            background: rgba(50, 50, 80, 0.6); color: %2;
        }
        QPushButton#btnSecundario:hover { background: rgba(80, 80, 120, 0.6); }
    )").arg(tema.corFundo(), tema.corTextoPrimaria(), tema.corTextoDestaque()));

    // 📦 Layout principal
    QHBoxLayout *lay = new QHBoxLayout(this);
    lay->setContentsMargins(0, 0, 0, 0);
    lay->setSpacing(0);

   // 📋 Lista de Categorias (esquerda)
   m_listaCategorias = new QListWidget(this);
   m_listaCategorias->setFixedWidth(240);
   m_listaCategorias->setIconSize(QSize(28, 28));
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/hardware/som.png"),         "🎧 Áudio e Som");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/hardware/monitor.png"),      "🖥️ Vídeo e Tela");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/hardware/placa_rede.png"),   "📡 Rede e Internet");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/hardware/bateria.png"),      "🔋 Opções de Energia");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/hardware/placa_rede.png"),   "🔧 Hardware e Drivers");  // ✅ NOVO
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/acao/salvar.png"),          "💾 Backup e Restauração");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/pastas/pasta_usuarios.png"), "👤 Contas de Usuário");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/sistema/icone_configuracao.png"), "🌍 Região e Idioma");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/hardware/impressora.png"),   "🖨️ Impressoras");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/sistema/icone_sistema.png"), "🛡️ Segurança e Manutenção");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/sistema/icone_configuracao.png"), "🧱 Firewall");
   m_listaCategorias->addItem(QIcon(":/fydelis/icons/pastas/pasta_sistema.png"),  "🎨 Aparência e Temas");
   lay->addWidget(m_listaCategorias);

   // 📄 Área de Conteúdo (direita) — MESMA ORDEM ACIMA!
   m_paginas = new QStackedWidget(this);
   m_paginas->addWidget(criarPaginaAudio());      // 0
   m_paginas->addWidget(criarPaginaVideo());      // 1
   m_paginas->addWidget(criarPaginaRede());      // 2
   m_paginas->addWidget(criarPaginaEnergia());    // 3
   m_paginas->addWidget(criarPaginaHardware());   // 4 ✅ NOVO — função que criamos
   m_paginas->addWidget(criarPaginaBackup());    // 5
   m_paginas->addWidget(criarPaginaUsuarios());   // 6
   m_paginas->addWidget(criarPaginaRegiao());     // 7
   m_paginas->addWidget(criarPaginaImpressora()); // 8
   m_paginas->addWidget(criarPaginaSeguranca()); // 9
   m_paginas->addWidget(criarPaginaFirewall());   // 10
   m_paginas->addWidget(criarPaginaTemas());      // 11
   lay->addWidget(m_paginas);

    // 🔗 Conectar seleção
    connect(m_listaCategorias, &QListWidget::currentItemChanged,
            this, &ControlPanel::itemSelecionado);
    m_listaCategorias->setCurrentRow(0);
}

// ==========================================
// 🔄 TROCAR PÁGINA AO CLICAR
// ==========================================
void ControlPanel::itemSelecionado(QListWidgetItem *item) {
    if (!item) return;
    int indice = m_listaCategorias->row(item);
    m_paginas->setCurrentIndex(indice);
}

// ==========================================
// 🎧 PÁGINA: ÁUDIO E SOM — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaAudio() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🎧 Áudio e Som</h2><p>Configurações de alto-falante, microfone e dispositivos de som</p>"));

    QGroupBox *gVolume = new QGroupBox("Volume Principal");
    QVBoxLayout *lVol = new QVBoxLayout(gVolume);
    QSlider *sVol = new QSlider(Qt::Horizontal); sVol->setRange(0,100);
    QCheckBox *chkSomLigado = new QCheckBox("🔊 Som ligado");

    // ✅ CARREGAR VALORES DO BANCO
    sVol->setValue(ConfigManager::instancia().volumePrincipal());
    chkSomLigado->setChecked(ConfigManager::instancia().somLigado());

    lVol->addWidget(new QLabel("Nível de volume:"));
    lVol->addWidget(sVol);
    lVol->addWidget(chkSomLigado);
    lay->addWidget(gVolume);

    QGroupBox *gDispositivos = new QGroupBox("Dispositivos de Reprodução");
    QVBoxLayout *lDisp = new QVBoxLayout(gDispositivos);
    QComboBox *cDisp = new QComboBox;
    cDisp->addItem("🔊 Alto-falante (Padrão)");
    cDisp->addItem("🎧 Fones de Ouvido");
    cDisp->addItem("🔊 Dispositivo HDMI");

    // ✅ CARREGAR DISPOSITIVO SALVO
    QString dispSalvo = ConfigManager::instancia().dispositivoSom();
    if (dispSalvo == "Fones de Ouvido") cDisp->setCurrentIndex(1);
    else if (dispSalvo == "HDMI") cDisp->setCurrentIndex(2);
    else cDisp->setCurrentIndex(0);

    lDisp->addWidget(new QLabel("Selecione um dispositivo:"));
    lDisp->addWidget(cDisp);
    lay->addWidget(gDispositivos);

    // ✅ SALVAR NO SQLITE AO MUDAR
    connect(sVol, &QSlider::valueChanged, [](int vol){
        ConfigManager::instancia().definirVolumePrincipal(vol);
    });
    connect(chkSomLigado, &QCheckBox::toggled, [](bool ligado){
        ConfigManager::instancia().definirSomLigado(ligado);
    });
    connect(cDisp, QOverload<int>::of(&QComboBox::currentIndexChanged), [=](int i){
        QStringList disp = {"Alto-falante", "Fones de Ouvido", "HDMI"};
        ConfigManager::instancia().definirDispositivoSom(disp[i]);
    });

    lay->addStretch();
    return pag;
}

// ==========================================
// 🖥️ PÁGINA: VÍDEO E TELA — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaVideo() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🖥️ Vídeo e Tela</h2><p>Resolução, taxa de atualização e aparência</p>"));

    QGroupBox *gRes = new QGroupBox("Resolução de Tela");
    QVBoxLayout *lRes = new QVBoxLayout(gRes);
    QComboBox *cRes = new QComboBox;
    cRes->addItem("1920 × 1080 — Recomendado");
    cRes->addItem("1366 × 768");
    cRes->addItem("1280 × 720");

    // ✅ CARREGAR RESOLUÇÃO SALVA
    QString resSalva = ConfigManager::instancia().resolucaoTela();
    if (resSalva.contains("1366")) cRes->setCurrentIndex(1);
    else if (resSalva.contains("1280")) cRes->setCurrentIndex(2);
    else cRes->setCurrentIndex(0);

    lRes->addWidget(new QLabel("Resolução:"));
    lRes->addWidget(cRes);
    lay->addWidget(gRes);

    QGroupBox *gTaxa = new QGroupBox("Taxa de Atualização");
    QVBoxLayout *lTaxa = new QVBoxLayout(gTaxa);
    QComboBox *cTaxa = new QComboBox;
    cTaxa->addItem("60 Hz — Recomendado");
    cTaxa->addItem("144 Hz");
    cTaxa->addItem("75 Hz");

    // ✅ CARREGAR TAXA SALVA
    int hz = ConfigManager::instancia().taxaAtualizacao();
    if (hz == 144) cTaxa->setCurrentIndex(1);
    else if (hz == 75) cTaxa->setCurrentIndex(2);
    else cTaxa->setCurrentIndex(0);

    lTaxa->addWidget(new QLabel("Taxa de atualização:"));
    lTaxa->addWidget(cTaxa);
    lay->addWidget(gTaxa);

    // ✅ SALVAR NO SQLITE AO MUDAR
    connect(cRes, QOverload<int>::of(&QComboBox::currentIndexChanged), [=](int i){
        QStringList res = {"1920 × 1080", "1366 × 768", "1280 × 720"};
        ConfigManager::instancia().definirResolucaoTela(res[i]);
    });
    connect(cTaxa, QOverload<int>::of(&QComboBox::currentIndexChanged), [=](int i){
        QList<int> taxas = {60, 144, 75};
        ConfigManager::instancia().definirTaxaAtualizacao(taxas[i]);
    });

    lay->addStretch();
    return pag;
}

// ==========================================
// 📡 PÁGINA: REDE E INTERNET — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaRede() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>📡 Rede e Internet</h2><p>Configurações de adaptador, IP, DNS e Proxy</p>"));

    QGroupBox *gStatus = new QGroupBox("Status da Conexão");
    QVBoxLayout *lStatus = new QVBoxLayout(gStatus);
    lStatus->addWidget(new QLabel("✅ Conectado — Rede Local"));
    lStatus->addWidget(new QLabel("Endereço IP: " + ConfigManager::instancia().ipManual()));
    lStatus->addWidget(new QLabel("Máscara: " + ConfigManager::instancia().mascaraRede()));
    lStatus->addWidget(new QLabel("Gateway: " + ConfigManager::instancia().gateway()));
    lay->addWidget(gStatus);

    QGroupBox *gConfig = new QGroupBox("Configuração de IP");
    QVBoxLayout *lConfig = new QVBoxLayout(gConfig);
    QCheckBox *cDHCP = new QCheckBox("Obter endereço IP automaticamente (DHCP)");

    // ✅ CARREGAR DHCP SALVO
    cDHCP->setChecked(ConfigManager::instancia().dhcpAtivado());

    lConfig->addWidget(cDHCP);
    lay->addWidget(gConfig);

    // ✅ SALVAR DHCP AO MUDAR
    connect(cDHCP, &QCheckBox::toggled, [](bool ativo){
        ConfigManager::instancia().definirDHCP(ativo);
    });

    lay->addStretch();
    return pag;
}

// ==========================================
// 🔋 PÁGINA: ENERGIA — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaEnergia() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🔋 Opções de Energia</h2><p>Gerenciamento de consumo e suspensão</p>"));

    QGroupBox *gPlano = new QGroupBox("Plano de Energia");
    QVBoxLayout *lPlano = new QVBoxLayout(gPlano);
    QComboBox *cPlano = new QComboBox;
    cPlano->addItem("⚡ Alto Desempenho");
    cPlano->addItem("🔋 Balanceado — Recomendado");
    cPlano->addItem("🌿 Economia de Energia");

    // ✅ CARREGAR PLANO SALVO
    QString plano = ConfigManager::instancia().planoEnergia();
    if (plano.contains("Alto")) cPlano->setCurrentIndex(0);
    else if (plano.contains("Economia")) cPlano->setCurrentIndex(2);
    else cPlano->setCurrentIndex(1);

    lPlano->addWidget(cPlano);
    lay->addWidget(gPlano);

    QGroupBox *gTela = new QGroupBox("Desligar Tela Após");
    QVBoxLayout *lTela = new QVBoxLayout(gTela);
    lTela->addWidget(new QLabel("Na bateria:  " + QString::number(ConfigManager::instancia().desligarTelaBateria()) + " minutos"));
    lTela->addWidget(new QLabel("Na tomada:  " + QString::number(ConfigManager::instancia().desligarTelaTomada()) + " minutos"));
    lay->addWidget(gTela);

    // ✅ SALVAR PLANO AO MUDAR
    connect(cPlano, QOverload<int>::of(&QComboBox::currentIndexChanged), [=](int i){
        QStringList planos = {"Alto Desempenho", "Balanceado", "Economia de Energia"};
        ConfigManager::instancia().definirPlanoEnergia(planos[i]);
    });

    lay->addStretch();
    return pag;
}

// ==========================================
// 💾 PÁGINA: BACKUP E RESTAURAÇÃO
// ==========================================
QWidget* ControlPanel::criarPaginaBackup() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>💾 Backup e Restauração</h2><p>Salvar e restaurar arquivos, sistema e configurações</p>"));

    QGroupBox *gBackup = new QGroupBox("Criar Backup");
    QVBoxLayout *lBackup = new QVBoxLayout(gBackup);
    lBackup->addWidget(new QLabel("Último backup: Nunca"));
    lBackup->addSpacing(8);
    QPushButton *btnBackup = new QPushButton("💾 Fazer Backup Agora");
    connect(btnBackup, &QPushButton::clicked, [](){
        QMessageBox::information(nullptr, "Backup", "Iniciando backup do sistema...\n\nFydelisSystem + Usuários + Configurações\n\nBanco SQLite: FydelisSystem/database/config.db");
    });
    lBackup->addWidget(btnBackup);
    lay->addWidget(gBackup);

    QGroupBox *gRestaurar = new QGroupBox("Restaurar Sistema");
    QVBoxLayout *lRest = new QVBoxLayout(gRestaurar);
    lRest->addWidget(new QLabel("Escolha um ponto de restauração:"));
    lRest->addSpacing(8);
    QPushButton *btnRest = new QPushButton("↩️ Restaurar");
    btnRest->setObjectName("btnSecundario");
    lRest->addWidget(btnRest);
    lay->addWidget(gRestaurar);

    lay->addStretch();
    return pag;
}

// ==========================================
// 👤 PÁGINA: CONTAS DE USUÁRIO
// ==========================================
QWidget* ControlPanel::criarPaginaUsuarios() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>👤 Contas de Usuário</h2><p>Gerenciar contas, permissões e senhas</p>"));

    QGroupBox *gLista = new QGroupBox("Contas no Sistema");
    QVBoxLayout *lLista = new QVBoxLayout(gLista);
    lLista->addWidget(new QLabel("👤 fydelis — Administrador"));
    lLista->addWidget(new QLabel("👤 convidado — Usuário Padrão"));
    lay->addWidget(gLista);

    QGroupBox *gAcoes = new QGroupBox("Ações");
    QVBoxLayout *lAcoes = new QVBoxLayout(gAcoes);
    QPushButton *btnNovo = new QPushButton("➕ Criar Nova Conta");
    QPushButton *btnSenha = new QPushButton("🔑 Alterar Senha");
    QPushButton *btnTipo = new QPushButton("⚙️ Alterar Tipo de Conta");
    lAcoes->addWidget(btnNovo);
    lAcoes->addWidget(btnSenha);
    lAcoes->addWidget(btnTipo);
    lay->addWidget(gAcoes);

    lay->addStretch();
    return pag;
}

// ==========================================
// 🌍 PÁGINA: REGIÃO E IDIOMA — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaRegiao() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🌍 Região e Idioma</h2><p>Formato de data, hora, moeda e idioma do sistema</p>"));

    QGroupBox *gIdioma = new QGroupBox("Idioma do Sistema");
    QVBoxLayout *lIdioma = new QVBoxLayout(gIdioma);
    QComboBox *cIdioma = new QComboBox;
    cIdioma->addItem("🇧🇷 Português (Brasil)");
    cIdioma->addItem("🇺🇸 English (United States)");
    cIdioma->addItem("🇪🇸 Español");

    // ✅ CARREGAR IDIOMA SALVO
    QString lang = ConfigManager::instancia().idioma();
    if (lang == "en_US") cIdioma->setCurrentIndex(1);
    else if (lang == "es_ES") cIdioma->setCurrentIndex(2);
    else cIdioma->setCurrentIndex(0);

    lIdioma->addWidget(cIdioma);
    lay->addWidget(gIdioma);

    QGroupBox *gRegiao = new QGroupBox("Formato Regional");
    QVBoxLayout *lRegiao = new QVBoxLayout(gRegiao);
    lRegiao->addWidget(new QLabel("País/Região: Brasil"));
    lRegiao->addWidget(new QLabel("Data: DD/MM/AAAA"));
    lRegiao->addWidget(new QLabel("Hora: 24h"));
    lRegiao->addWidget(new QLabel("Moeda: R$ Real"));
    lay->addWidget(gRegiao);

    // ✅ SALVAR IDIOMA AO MUDAR
    connect(cIdioma, QOverload<int>::of(&QComboBox::currentIndexChanged), [=](int i){
        QStringList langs = {"pt_BR", "en_US", "es_ES"};
        ConfigManager::instancia().definirIdioma(langs[i]);
    });

    lay->addStretch();
    return pag;
}

// ==========================================
// 🖨️ PÁGINA: IMPRESSORAS — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaImpressora() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🖨️ Dispositivos e Impressoras</h2><p>Instalar e gerenciar impressoras e dispositivos</p>"));

    QGroupBox *gImp = new QGroupBox("Impressoras Instaladas");
    QVBoxLayout *lImp = new QVBoxLayout(gImp);
    QString impPadrao = ConfigManager::instancia().impressoraPadrao();
    if (impPadrao.isEmpty()) impPadrao = "Não configurada";
    lImp->addWidget(new QLabel("🖨️ Impressora Padrão — " + impPadrao));
    lay->addWidget(gImp);

    QPushButton *btnAdd = new QPushButton("➕ Adicionar Impressora");
    QPushButton *btnPorta = new QPushButton("🔌 Portas de Impressão");
    lay->addWidget(btnAdd);
    lay->addWidget(btnPorta);

    lay->addStretch();
    return pag;
}

// ==========================================
// 🛡️ PÁGINA: SEGURANÇA E MANUTENÇÃO — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaSeguranca() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🛡️ Segurança e Manutenção</h2><p>Verificação de integridade, atualizações e proteção</p>"));

    QGroupBox *gStatus = new QGroupBox("Status de Segurança");
    QVBoxLayout *lStatus = new QVBoxLayout(gStatus);
    QString fw = ConfigManager::instancia().firewallAtivado() ? "✅ Ativado" : "❌ Desativado";
    QString rt = ConfigManager::instancia().protecaoTempoReal() ? "✅ Ativada" : "❌ Desativada";
    lStatus->addWidget(new QLabel("🛡️ Firewall: " + fw));
    lStatus->addWidget(new QLabel("🔒 Proteção em Tempo Real: " + rt));
    lStatus->addWidget(new QLabel("✅ Integridade do Sistema: Verificada"));
    lStatus->addWidget(new QLabel("⚠️ Atualizações: Verificando..."));
    lay->addWidget(gStatus);

    QGroupBox *gManutencao = new QGroupBox("Manutenção do Sistema");
    QVBoxLayout *lManut = new QVBoxLayout(gManutencao);
    QPushButton *btnVerificar = new QPushButton("🔍 Verificar Integridade do Sistema");
    QPushButton *btnLimpar = new QPushButton("🧹 Limpar Arquivos Temporários");
    QPushButton *btnAtualizar = new QPushButton("⬆️ Verificar Atualizações");
    lManut->addWidget(btnVerificar);
    lManut->addWidget(btnLimpar);
    lManut->addWidget(btnAtualizar);
    lay->addWidget(gManutencao);

    lay->addStretch();
    return pag;
}

// ==========================================
// 🧱 PÁGINA: FIREWALL — CONECTADO AO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaFirewall() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🧱 Firewall do FydelisTech</h2><p>Regras de entrada e saída, segurança de rede</p>"));

    QGroupBox *gStatus = new QGroupBox("Status do Firewall");
    QVBoxLayout *lStatus = new QVBoxLayout(gStatus);
    QCheckBox *cAtivo = new QCheckBox("🔒 Ativar Firewall");

    // ✅ CARREGAR STATUS DO BANCO
    cAtivo->setChecked(ConfigManager::instancia().firewallAtivado());

    lStatus->addWidget(cAtivo);
    lStatus->addWidget(new QLabel("📊 Conexões bloqueadas hoje: 0"));
    lay->addWidget(gStatus);

    QGroupBox *gRegras = new QGroupBox("Regras Permitidas");
    QVBoxLayout *lRegras = new QVBoxLayout(gRegras);
    lRegras->addWidget(new QLabel("✅ SSH (Porta 22) — Permitido"));
    lRegras->addWidget(new QLabel("✅ Web (Porta 80/443) — Permitido"));
    lRegras->addWidget(new QLabel("⚠️ Área de Trabalho Remota — Bloqueado"));
    lay->addWidget(gRegras);

    QPushButton *btnRegras = new QPushButton("⚙️ Gerenciar Regras Avançadas");
    lay->addWidget(btnRegras);

    // ✅ SALVAR STATUS AO MUDAR
    connect(cAtivo, &QCheckBox::toggled, [](bool ativo){
        ConfigManager::instancia().definirFirewall(ativo);
    });

    lay->addStretch();
    return pag;
}


// ==========================================
// 🔧 PÁGINA: HARDWARE E DRIVERS
// ==========================================
QWidget* ControlPanel::criarPaginaHardware() {
    QWidget *pag = new QWidget;
    pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);

    lay->addWidget(new QLabel(
        "<h2>🔧 Hardware e Drivers</h2>"
        "<p>Detectar dispositivos, baixar e instalar drivers</p>"
    ));

    QPushButton *btnAbrir = new QPushButton("🔍 Abrir Gerenciador de Hardware");
    btnAbrir->setMinimumHeight(60);
    btnAbrir->setStyleSheet(R"(
        QPushButton {
            background: #4f46e5; border: none; border-radius: 10px;
            font-size: 15px; font-weight: bold; padding: 12px;
        }
        QPushButton:hover { background: #6366f1; }
    )");

    connect(btnAbrir, &QPushButton::clicked, [](){
        HardwarePanel janela;
        janela.exec();
    });

    lay->addWidget(btnAbrir);
    lay->addStretch();
    return pag;
}

QPushButton* btnServicos = new QPushButton("⚙️ Serviços do Sistema");
connect(btnServicos, &QPushButton::clicked, this, [](){
    ServicoManagerPanel janela;
    janela.exec();
});

// Dentro do método que monta a interface do ControlPanel
//Segurança do FydelistechOS
QPushButton* btnSeguranca = new QPushButton("🛡️ Segurança & Firewall");
btnSeguranca->setStyleSheet(R"(
    QPushButton {
        background: #1e293b;
        border: 1px solid #00FF88;
        border-radius: 8px;
        padding: 12px;
        color: #f1f5f9;
        font-weight: bold;
        font-size: 14px;
    }
    QPushButton:hover { background: #0f4d35; }
)");

connect(btnSeguranca, &QPushButton::clicked, [](){
    FGAdminPanel janela;
    janela.exec();
});

//Atualizações do FydelistechOS
QPushButton* btnAtualizacoes = new QPushButton("🔄 Atualizações do Sistema");
btnAtualizacoes->setStyleSheet(R"(
    QPushButton {
        background: #1e293b;
        border: 1px solid #00AAFF;
        border-radius: 8px;
        padding: 12px;
        color: #f1f5f9;
        font-weight: bold;
        font-size: 14px;
    }
    QPushButton:hover { background: #0f2d47; }
)");
connect(btnAtualizacoes, &QPushButton::clicked, this, [](){
    UpdatePanel janela;
    janela.exec();
});

// ==========================================
// 🎨 PÁGINA: TEMAS — SALVA NO SQLITE
// ==========================================
QWidget* ControlPanel::criarPaginaTemas() {
    QWidget *pag = new QWidget; pag->setObjectName("pagina");
    QVBoxLayout *lay = new QVBoxLayout(pag);
    lay->addWidget(new QLabel("<h2>🎨 Personalização e Aparência</h2><p>Escolha o visual do sistema — muda na hora e salva automaticamente!</p>"));

    QGroupBox *gTemas = new QGroupBox("Temas Prontos");
    QVBoxLayout *lTemas = new QVBoxLayout(gTemas);
    QPushButton *btnRoxo = new QPushButton("💜 FydelisTech Vidro Neon — Padrão");
    QPushButton *btnAzul = new QPushButton("💙 Azul Celeste");
    QPushButton *btnVerde = new QPushButton("💚 Verde Escuro");
    QPushButton *btnEscuro = new QPushButton("🖤 Escuro Total");

    // 🎯 APLICAR TEMA + SALVAR NO SQLITE
    connect(btnRoxo, &QPushButton::clicked, [](){
        ThemeManager::instancia().carregarTemaDoJSON(R"({
            "nome": "FydelisTech Vidro Neon",
            "fundo": {"cor1": "#1a0f47", "cor2": "#251b60", "cor3": "#0f173a"},
            "janelaVidro": {"fundo": "rgba(60, 40, 110, 0.40)", "borda": "rgba(140, 180, 255, 0.35)", "raioCantos": 24, "brilhoIntensidade": 50},
            "barraTarefas": {"fundo": "rgba(30, 20, 70, 0.50)", "bordaSuperior": "rgba(140, 180, 255, 0.25)"},
            "texto": {"primaria": "#e6eeff", "secundaria": "#94a3b8", "destaque": "#a5b4fc"}
        })");
        ConfigManager::instancia().definirTemaAtual("Vidro Neon"); // ✅ SALVA NO BANCO
        QMessageBox::information(nullptr, "Tema Aplicado", "💜 Tema Vidro Neon Ativado!\n\n✅ Salvo no SQLite — mantém ao reiniciar!");
    });

    connect(btnAzul, &QPushButton::clicked, [](){
        ThemeManager::instancia().carregarTemaDoJSON(R"({
            "nome": "Azul Celeste",
            "fundo": {"cor1": "#0f2b47", "cor2": "#1a4570", "cor3": "#0a1f35"},
            "janelaVidro": {"fundo": "rgba(40, 80, 120, 0.40)", "borda": "rgba(100, 180, 255, 0.40)", "raioCantos": 24, "brilhoIntensidade": 50},
            "barraTarefas": {"fundo": "rgba(20, 50, 90, 0.50)", "bordaSuperior": "rgba(100, 180, 255, 0.30)"},
            "texto": {"primaria": "#e6f2ff", "secundaria": "#a0c4e8", "destaque": "#74c0fc"}
        })");
        ConfigManager::instancia().definirTemaAtual("Azul Celeste");
        QMessageBox::information(nullptr, "Tema Aplicado", "💙 Tema Azul Celeste Ativado!\n\n✅ Salvo no SQLite!");
    });

    connect(btnVerde, &QPushButton::clicked, [](){
        ThemeManager::instancia().carregarTemaDoJSON(R"({
            "nome": "Verde Escuro",
            "fundo": {"cor1": "#0f3827", "cor2": "#185038", "cor3": "#0a281c"},
            "janelaVidro": {"fundo": "rgba(40, 100, 70, 0.40)", "borda": "rgba(100, 255, 180, 0.35)", "raioCantos": 24, "brilhoIntensidade": 45},
            "barraTarefas": {"fundo": "rgba(20, 60, 40, 0.50)", "bordaSuperior": "rgba(100, 255, 180, 0.25)"},
            "texto": {"primaria": "#e6fff2", "secundaria": "#8fd8b8", "destaque": "#69db9a"}
        })");
        ConfigManager::instancia().definirTemaAtual("Verde Escuro");
        QMessageBox::information(nullptr, "Tema Aplicado", "💚 Tema Verde Escuro Ativado!\n\n✅ Salvo no SQLite!");
    });

    connect(btnEscuro, &QPushButton::clicked, [](){
        ThemeManager::instancia().carregarTemaDoJSON(R"({
            "nome": "Escuro Total",
            "fundo": {"cor1": "#0a0a0f", "cor2": "#151520", "cor3": "#050508"},
            "janelaVidro": {"fundo": "rgba(30, 30, 45, 0.50)", "borda": "rgba(100, 100, 130, 0.30)", "raioCantos": 20, "brilhoIntensidade": 35},
            "barraTarefas": {"fundo": "rgba(15, 15, 25, 0.60)", "bordaSuperior": "rgba(80, 80, 110, 0.25)"},
            "texto": {"primaria": "#e0e0f0", "secundaria": "#9090a0", "destaque": "#b0b0d0"}
        })");
        ConfigManager::instancia().definirTemaAtual("Escuro Total");
        QMessageBox::information(nullptr, "Tema Aplicado", "🖤 Tema Escuro Total Ativado!\n\n✅ Salvo no SQLite!");
    });

    lTemas->addWidget(btnRoxo);
    lTemas->addWidget(btnAzul);
    lTemas->addWidget(btnVerde);
    lTemas->addWidget(btnEscuro);
    lay->addWidget(gTemas);
    lay->addStretch();
    return pag;
}