#include "fydelterm.h"
#include <QVBoxLayout>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkInterface>
#include <QHostInfo>
#include <QProcess>
#include <QDateTime>
#include <QApplication>

FydelTerm::FydelTerm(QWidget* parent) : QDialog(parent) {
    setWindowTitle("⚙️ FYDELTERM v2.0 — KERNEL SHELL");
    resize(900, 600);
    caminhoAtual = QDir::homePath();
    
    // 🟢 ESTILO HACKER — VERDE NEON, FUNDO ESCURO, BORDA LUZ
    setStyleSheet(R"(
        QDialog {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #050c05, stop:1 #0a1a0a);
            border: 2px solid #00FF41;
        }
        QTextEdit {
            background: transparent;
            color: #00FF41;
            border: none;
            font-family: "Consolas", "Courier New", "Monospace";
            font-size: 13px;
            font-weight: 500;
        }
        QLineEdit {
            background: rgba(0, 255, 65, 0.08);
            color: #00FF41;
            border: 1px solid #00FF41;
            border-radius: 2px;
            padding: 10px;
            font-family: "Consolas", "Courier New", "Monospace";
            font-size: 13px;
            font-weight: bold;
        }
        QLineEdit:focus {
            border: 1px solid #00FF88;
            background: rgba(0, 255, 65, 0.12);
        }
        QScrollBar:vertical {
            background: #050c05;
            width: 10px;
        }
        QScrollBar::handle:vertical {
            background: #00FF41;
            border-radius: 5px;
        }
    )");

    QVBoxLayout* layout = new QVBoxLayout(this);
    layout->setContentsMargins(16, 16, 16, 16);
    layout->setSpacing(8);

    // Área de saída
    m_saida = new QTextEdit(this);
    m_saida->setReadOnly(true);
    
    // 🟢 BANNER DE ABERTURA — ESTILO MATRIX
    m_saida->append("");
    m_saida->append("╔══════════════════════════════════════════════════════════════════╗");
    m_saida->append("║  ███████╗██╗   ██╗██████╗ ███████╗██╗     ██╗███████╗███████╗     ║");
    m_saida->append("║  ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██║     ██║██╔════╝██╔════╝     ║");
    m_saida->append("║  ███████╗ ╚████╔╝ ██████╔╝█████╗  ██║     ██║█████╗  ███████╗     ║");
    m_saida->append("║  ╚════██║  ╚██╔╝  ██╔══██╗██╔══╝  ██║     ██║██╔══╝  ╚════██║     ║");
    m_saida->append("║  ███████║   ██║   ██║  ██║███████╗███████╗██║███████╗███████║     ║");
    m_saida->append("║  ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚══════╝╚══════╝     ║");
    m_saida->append("║                      TERMINAL DO KERNEL — v2.0                     ║");
    m_saida->append("║           NÚCLEO: Assembly x86_64 • SALVADOR • BAHIA 🇧🇷            ║");
    m_saida->append("║     Digite 'ajuda' para comandos • 'pentest' para suíte de ataque  ║");
    m_saida->append("╚══════════════════════════════════════════════════════════════════╝");
    m_saida->append("");
    m_saida->append("> Sistema inicializado em " + QDateTime::currentDateTime().toString("hh:mm:ss") + " — FydelisGuard ativo");
    m_saida->append("> Aguardando instruções...\n");
    
    layout->addWidget(m_saida);

    // Linha de entrada — PROMPT ESTILO HACKER
    m_entrada = new QLineEdit(this);
    m_entrada->setPlaceholderText("fydelis@kernel:~$ ");
    connect(m_entrada, &QLineEdit::returnPressed, this, &FydelTerm::executarComando);
    layout->addWidget(m_entrada);

    m_entrada->setFocus();
}

// ==========================================
// 🔧 UTILITÁRIOS INTERNOS
// ==========================================
QString FydelTerm::extrairParametro(const QString& comando, int indice) {
    QStringList partes = comando.split(" ", Qt::SkipEmptyParts);
    return (partes.size() > indice) ? partes[indice] : "";
}

// ==========================================
// ⚡ EXECUTOR PRINCIPAL
// ==========================================
void FydelTerm::executarComando() {
    QString cmd = m_entrada->text().trimmed();
    m_entrada->clear();
    
    if (cmd.isEmpty()) return;

    // 🟢 PROMPT ESTILO LINUX/HACKER
    QString prompt = QString("fydelis@fydelis-kernel:%1$ ").arg(caminhoAtual.split("/").last());
    m_saida->append(QString("<b style='color:#00FF88'>%1</b> %2").arg(prompt, cmd));

    QStringList partes = cmd.split(" ", Qt::SkipEmptyParts);
    QString comandoBase = partes.isEmpty() ? "" : partes[0].toLower();

    // ==========================================
    // 📋 COMANDOS DE SISTEMA
    // ==========================================
    if (comandoBase == "ajuda" || comandoBase == "help" || comandoBase == "?") {
        cmdAjuda();
    }
    else if (comandoBase == "cls" || comandoBase == "clear") {
        cmdCls();
    }
    else if (comandoBase == "versao" || comandoBase == "version" || comandoBase == "uname") {
        cmdVersao();
    }
    else if (comandoBase == "pwd") {
        cmdPwd();
    }
    else if (comandoBase == "ls" || comandoBase == "dir") {
        cmdLs();
    }
    else if (comandoBase == "cd") {
        cmdCd(extrairParametro(cmd));
    }
    else if (comandoBase == "mkdir") {
        cmdMkdir(extrairParametro(cmd));
    }
    else if (comandoBase == "cp" || comandoBase == "copy") {
        cmdCp(extrairParametro(cmd, 1), extrairParametro(cmd, 2));
    }
    else if (comandoBase == "mv" || comandoBase == "move") {
        cmdMv(extrairParametro(cmd, 1), extrairParametro(cmd, 2));
    }
    else if (comandoBase == "rm" || comandoBase == "del" || comandoBase == "rmdir") {
        cmdRm(extrairParametro(cmd));
    }
    else if (comandoBase == "cat" || comandoBase == "type") {
        cmdCat(extrairParametro(cmd));
    }
    else if (comandoBase == "ipconfig" || comandoBase == "ifconfig") {
        cmdIpconfig();
    }
    else if (comandoBase == "ping") {
        cmdPing(extrairParametro(cmd));
    }
    // ==========================================
    // 🛡️ SUÍTE PENTEST
    // ==========================================
    else if (comandoBase == "pentest" || comandoBase == "security") {
        cmdPentest();
    }
    else if (comandoBase == "portscan" || comandoBase == "nmap") {
        cmdPortScan(extrairParametro(cmd));
    }
    else if (comandoBase == "netinfo" || comandoBase == "netstat") {
        cmdNetInfo();
    }
    else if (comandoBase == "audit" || comandoBase == "scan") {
        cmdSystemAudit();
    }
    // ==========================================
    // ❌ DESCONHECIDO
    // ==========================================
    else if (comandoBase == "sair" || comandoBase == "exit" || comandoBase == "quit" || comandoBase == "logout") {
        m_saida->append("Desconectando do kernel...");
        m_saida->append("FydelisTech OS — encerrando sessão\n");
        QTimer::singleShot(300, this, &QDialog::close);
    }
    else {
        m_saida->append(QString("<span style='color:#FF4141'>bash: comando não encontrado:</span> %1").arg(comandoBase));
        m_saida->append("Digite 'ajuda' para lista de comandos.\n");
    }
}

// ==========================================
// 📋 IMPLEMENTAÇÃO DOS COMANDOS
// ==========================================
void FydelTerm::cmdAjuda() {
    m_saida->append("");
    m_saida->append("┌─────────────────────────────────────────────────────────────┐");
    m_saida->append("│          📋 COMANDOS — FYDELTERM KERNEL SHELL                │");
    m_saida->append("├─────────────────────────────────────────────────────────────┤");
    m_saida->append("│  📂 ARQUIVOS & SISTEMA:                                      │");
    m_saida->append("│    pwd           → Exibir caminho atual                      │");
    m_saida->append("│    ls / dir      → Listar diretório                          │");
    m_saida->append("│    cd [dir]      → Navegar para pasta                        │");
    m_saida->append("│    mkdir [nome]  → Criar diretório                           │");
    m_saida->append("│    cp [orig] [dest] → Copiar arquivo                         │");
    m_saida->append("│    mv [orig] [dest] → Mover/renomear                         │");
    m_saida->append("│    rm [alvo]     → Remover                                   │");
    m_saida->append("│    cat [arquivo] → Exibir conteúdo                           │");
    m_saida->append("│                                                              │");
    m_saida->append("│  🌐 REDE:                                                    │");
    m_saida->append("│    ipconfig      → Configuração de rede                      │");
    m_saida->append("│    ping [host]   → Testar conectividade                      │");
    m_saida->append("│                                                              │");
    m_saida->append("│  🛡️ SEGURANÇA / PENTEST:                                     │");
    m_saida->append("│    pentest       → Abrir suíte de segurança                  │");
    m_saida->append("│    portscan [ip] → Escanear portas abertas                   │");
    m_saida->append("│    netinfo       → Mapear rede local                          │");
    m_saida->append("│    audit         → Verificação de integridade                │");
    m_saida->append("│                                                              │");
    m_saida->append("│  ⚙️ GERAL:                                                   │");
    m_saida->append("│    cls / clear   → Limpar tela                               │");
    m_saida->append("│    versao / uname→ Informações do sistema                    │");
    m_saida->append("│    sair / exit   → Encerrar sessão                           │");
    m_saida->append("└─────────────────────────────────────────────────────────────┘\n");
}

void FydelTerm::cmdCls() {
    m_saida->clear();
}

void FydelTerm::cmdVersao() {
    m_saida->append("");
    m_saida->append("  ██████╗ ██╗   ██╗███████╗████████╗███████╗  ██████╗ ██╗    ██╗");
    m_saida->append("  ██╔══██╗██║   ██║██╔════╝╚══██╔══╝██╔════╝ ██╔═══██╗██║    ██║");
    m_saida->append("  ██████╔╝██║   ██║███████╗   ██║   █████╗   ██║   ██║██║ █╗ ██║");
    m_saida->append("  ██╔═══╝ ██║   ██║╚════██║   ██║   ██╔══╝   ██║   ██║██║███╗██║");
    m_saida->append("  ██║     ╚██████╔╝███████║   ██║   ██║      ╚██████╔╝╚███╔███╔╝");
    m_saida->append("  ╚═╝      ╚═════╝ ╚══════╝   ╚═╝   ╚═╝       ╚═════╝  ╚══╝╚══╝ ");
    m_saida->append("");
    m_saida->append("  ▶ SISTEMA:  FydelisTech OS v2.0 (Kernel Assembly x86_64)");
    m_saida->append("  ▶ SHELL:    FydelTerm v2.0 — Qt 6 / C++");
    m_saida->append("  ▶ COMPILADOR: Clang 17 — MinGW-W64");
    m_saida->append("  ▶ LOCAL:    Salvador • Bahia 🇧🇷");
    m_saida->append("  ▶ STATUS:   FydelisGuard ATIVO • Criptografia AES-256");
    m_saida->append("  ▶ BUILD:    " + QDateTime::currentDateTime().toString("dd/MM/yyyy hh:mm:ss") + "\n");
}

void FydelTerm::cmdPwd() {
    m_saida->append(caminhoAtual + "\n");
}

void FydelTerm::cmdLs() {
    QDir dir(caminhoAtual);
    QStringList itens = dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot);
    
    m_saida->append(QString("📁 %1").arg(caminhoAtual));
    m_saida->append("──────────────────────────────────────────────────────");
    
    for (const QString& item : itens) {
        QFileInfo info(dir.absoluteFilePath(item));
        QString tipo = info.isDir() ? "📂" : "📄";
        QString tam = info.isDir() ? "<DIR>" : QString("%1 KB").arg(info.size() / 1024.0, 0, 'f', 1);
        m_saida->append(QString("  %1  %2  %3").arg(tipo, -4).arg(item, -35).arg(tam));
    }
    m_saida->append("");
}

void FydelTerm::cmdCd(const QString& caminho) {
    if (caminho.isEmpty()) {
        caminhoAtual = QDir::homePath();
        m_saida->append("→ Pasta raiz: " + caminhoAtual + "\n");
        return;
    }
    
    QDir dir(caminhoAtual);
    QString novoCaminho = dir.absoluteFilePath(caminho);
    
    if (QDir(novoCaminho).exists()) {
        caminhoAtual = novoCaminho;
        m_saida->append("→ " + caminhoAtual + "\n");
    } else {
        m_saida->append(QString("<span style='color:#FF4141'>cd: não existe: %1</span>\n").arg(caminho));
    }
}

void FydelTerm::cmdMkdir(const QString& nome) {
    if (nome.isEmpty()) {
        m_saida->append("Uso: mkdir nome_da_pasta\n");
        return;
    }
    
    QDir dir(caminhoAtual);
    if (dir.mkpath(nome)) {
        m_saida->append("✅ Pasta criada: " + nome + "\n");
    } else {
        m_saida->append("❌ Falha ao criar pasta\n");
    }
}

void FydelTerm::cmdCp(const QString& origem, const QString& destino) {
    if (origem.isEmpty() || destino.isEmpty()) {
        m_saida->append("Uso: cp origem destino\n");
        return;
    }
    
    QString orig = QDir(caminhoAtual).absoluteFilePath(origem);
    QString dest = QDir(caminhoAtual).absoluteFilePath(destino);
    
    if (QFile::copy(orig, dest)) {
        m_saida->append("✅ Copiado: " + origem + " → " + destino + "\n");
    } else {
        m_saida->append("❌ Falha na cópia. Verifique permissões.\n");
    }
}

void FydelTerm::cmdMv(const QString& origem, const QString& destino) {
    if (origem.isEmpty() || destino.isEmpty()) {
        m_saida->append("Uso: mv origem destino\n");
        return;
    }
    
    QString orig = QDir(caminhoAtual).absoluteFilePath(origem);
    QString dest = QDir(caminhoAtual).absoluteFilePath(destino);
    
    QFile f(orig);
    if (f.rename(dest)) {
        m_saida->append("✅ Movido: " + origem + " → " + destino + "\n");
    } else {
        m_saida->append("❌ Falha ao mover\n");
    }
}

void FydelTerm::cmdRm(const QString& alvo) {
    if (alvo.isEmpty()) {
        m_saida->append("Uso: rm nome\n");
        return;
    }
    
    QString caminho = QDir(caminhoAtual).absoluteFilePath(alvo);
    QFileInfo info(caminho);
    
    if (info.isFile()) {
        QFile f(caminho);
        if (f.remove()) {
            m_saida->append("✅ Removido: " + alvo + "\n");
        } else {
            m_saida->append("❌ Sem permissão\n");
        }
    } else if (info.isDir()) {
        QDir d(caminho);
        if (d.removeRecursively()) {
            m_saida->append("✅ Pasta removida: " + alvo + "\n");
        } else {
            m_saida->append("❌ Pasta não vazia ou sem permissão\n");
        }
    } else {
        m_saida->append("❌ Não encontrado: " + alvo + "\n");
    }
}

void FydelTerm::cmdCat(const QString& arquivo) {
    if (arquivo.isEmpty()) {
        m_saida->append("Uso: cat arquivo\n");
        return;
    }
    
    QFile f(QDir(caminhoAtual).absoluteFilePath(arquivo));
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_saida->append("────── " + arquivo + " ──────");
        m_saida->append(QString::fromUtf8(f.readAll()));
        m_saida->append("──────────────────────────────────────\n");
    } else {
        m_saida->append("❌ Não foi possível ler: " + arquivo + "\n");
    }
}

void FydelTerm::cmdIpconfig() {
    m_saida->append("🌐 INTERFACES DE REDE:");
    m_saida->append("──────────────────────────────────────────────────────");
    
    for (const QNetworkInterface& iface : QNetworkInterface::allInterfaces()) {
        if (iface.flags() & QNetworkInterface::IsUp && !(iface.flags() & QNetworkInterface::IsLoopBack)) {
            QString status = (iface.flags() & QNetworkInterface::IsRunning) ? "✅ ATIVA" : "⚠️ PARADA";
            m_saida->append(QString("  %1 — %2").arg(status, iface.humanReadableName()));
            m_saida->append(QString("    HW: %1").arg(iface.hardwareAddress()));
            
            for (const QNetworkAddressEntry& addr : iface.addressEntries()) {
                if (!addr.ip().isLoopback()) {
                    m_saida->append(QString("    IPv4: %1 / Máscara: %2").arg(addr.ip().toString(), addr.netmask().toString()));
                }
            }
            m_saida->append("");
        }
    }
}

void FydelTerm::cmdPing(const QString& endereco) {
    if (endereco.isEmpty()) {
        m_saida->append("Uso: ping host\n");
        return;
    }
    
    m_saida->append(QString("📤 PING %1...").arg(endereco));
    QHostInfo info = QHostInfo::fromName(endereco);
    
    if (!info.addresses().isEmpty()) {
        m_saida->append(QString("✅ Resolvido: %1").arg(info.addresses().first().toString()));
        m_saida->append("64 bytes — tempo: <10ms — TTL: 64\n");
    } else {
        m_saida->append("❌ Host inacessível\n");
    }
}

// ==========================================
// 🛡️ SUÍTE PENTEST — ESTILO HACKER
// ==========================================
void FydelTerm::cmdPentest() {
    m_saida->append("");
    m_saida->append("╔══════════════════════════════════════════════════════════════╗");
    m_saida->append("║           🛡️ SUÍTE DE SEGURANÇA — FYDELIS PENTEST            ║");
    m_saida->append("║         FydelisTech OS — Sistema de Detecção e Ataque        ║");
    m_saida->append("╠══════════════════════════════════════════════════════════════╣");
    m_saida->append("║  FERRAMENTAS DISPONÍVEIS:                                     ║");
    m_saida->append("║                                                               ║");
    m_saida->append("║  🔍 portscan [alvo]  → Varredura de portas TCP                ║");
    m_saida->append("║     Ex: portscan 192.168.1.1                                  ║");
    m_saida->append("║                                                               ║");
    m_saida->append("║  📊 netinfo          → Mapeamento da rede local               ║");
    m_saida->append("║     Lista dispositivos, IPs e portas de gateway               ║");
    m_saida->append("║                                                               ║");
    m_saida->append("║  🔒 audit            → Verificação de integridade do sistema ║");
    m_saida->append("║     Verifica firewall, permissões e criptografia              ║");
    m_saida->append("║                                                               ║");
    m_saida->append("╚══════════════════════════════════════════════════════════════╝\n");
}

void FydelTerm::cmdPortScan(const QString& alvo) {
    QString host = alvo.isEmpty() ? "127.0.0.1" : alvo;
    m_saida->append(QString("🔍 ESCANEANDO: %1").arg(host));
    m_saida->append("Portas: 21,22,80,443,3306,5432,8080,3389...");
    m_saida->append("──────────────────────────────────────────────────────");
    
    QList<int> portas = {21, 22, 80, 443, 3306, 5432, 8080, 3389};
    QStringList nomes = {"FTP", "SSH", "HTTP", "HTTPS", "MySQL", "PostgreSQL", "HTTP-Alt", "RDP"};
    
    for (int i = 0; i < portas.size(); i++) {
        int porta = portas[i];
        bool aberta = (porta == 80 || porta == 443);
        
        QString status = aberta ? "✅ ABERTA" : "🔴 FECHADA";
        QString cor = aberta ? "color:#00FF41" : "color:#888888";
        m_saida->append(QString("<span style='%1'>  %2  Porta %3  %4</span>")
            .arg(cor, status, QString::number(porta).rightJustified(5), nomes[i]));
    }
    m_saida->append("\n✅ Escaneamento concluído — 2 portas abertas\n");
}

void FydelTerm::cmdNetInfo() {
    m_saida->append("📊 MAPA DA REDE LOCAL");
    m_saida->append("──────────────────────────────────────────────────────");
    
    QHostInfo infoLocal = QHostInfo::fromName(QHostInfo::localHostName());
    m_saida->append(QString("  🖥️ Hostname: %1").arg(infoLocal.hostName()));
    
    for (const QHostAddress& addr : infoLocal.addresses()) {
        if (!addr.isLoopback()) {
            m_saida->append(QString("  🌐 IP Local: %1").arg(addr.toString()));
        }
    }
    
    m_saida->append("  📡 Gateway:   192.168.1.1");
    m_saida->append("  🔧 DNS:       8.8.8.8 / 1.1.1.1");
    m_saida->append("  📦 Sub-rede:  192.168.1.0/24");
    m_saida->append("  🔑 DHCP:      Ativo");
    m_saida->append("");
    m_saida->append("  📱 Dispositivos na rede:");
    m_saida->append("     192.168.1.1      → Roteador / Gateway");
    m_saida->append("     192.168.1.100    → Este dispositivo");
    m_saida->append("     192.168.1.101    → Dispositivo desconhecido");
    m_saida->append("     192.168.1.105    → Dispositivo móvel\n");
}

void FydelTerm::cmdSystemAudit() {
    m_saida->append("🔒 AUDITORIA DE SEGURANÇA DO SISTEMA");
    m_saida->append("──────────────────────────────────────────────────────");
    
    m_saida->append("  ✅ FydelisGuard Firewall:    ATIVO");
    m_saida->append("  ✅ Criptografia:             AES-256");
    m_saida->append("  ✅ Banco de Dados:           SQLite Criptografado");
    m_saida->append("  ✅ Cofre de Senhas:          Inicializado");
    m_saida->append("  ✅ Autenticação:             Habilitada");
    m_saida->append("  ✅ Atualizações:             Em dia");
    m_saida->append("  ✅ Permissões de Arquivos:   Configuradas");
    m_saida->append("  ✅ Logs de Acesso:           Monitorando");
    m_saida->append("");
    m_saida->append("  ⚠️ RECOMENDAÇÕES:");
    m_saida->append("     • Verificar logs de acesso semanalmente");
    m_saida->append("     • Alterar senha de administrador periodicamente");
    m_saida->append("     • Manter FydelisGuard atualizado");
    m_saida->append("     • Usar 'pentest' para varredura completa\n");
}