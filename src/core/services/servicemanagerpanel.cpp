#include "servicemanagerpanel.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QMessageBox>
#include <QIcon>
#include <QDebug>

ServicoManagerPanel::ServicoManagerPanel(QWidget *parent) : QDialog(parent) {
    setWindowTitle("FydelisServices — Gerenciador de Serviços");
    resize(900, 600);

    QVBoxLayout* principal = new QVBoxLayout(this);
    principal->setSpacing(10);
    principal->setContentsMargins(16, 16, 16, 16);

    // 📋 Título
    QLabel* titulo = new QLabel("⚙️ Serviços do Sistema");
    titulo->setStyleSheet("font-size: 18px; font-weight: bold;");
    principal->addWidget(titulo);

    // 📊 Lista
    m_lista = new QListWidget;
    m_lista->setIconSize(QSize(32, 32));
    connect(m_lista, &QListWidget::itemSelectionChanged, this, &ServicoManagerPanel::atualizarLista);
    principal->addWidget(m_lista);

    // 📝 Detalhes
    m_lblDetalhes = new QLabel;
    m_lblDetalhes->setStyleSheet("padding: 10px; background: #1e293b; border-radius: 8px;");
    principal->addWidget(m_lblDetalhes);

    // 🔘 Botões
    QHBoxLayout* botoes = new QHBoxLayout;
    
    m_btnIniciar = new QPushButton("▶️ Iniciar");
    connect(m_btnIniciar, &QPushButton::clicked, this, &ServicoManagerPanel::iniciarSelecionado);
    botoes->addWidget(m_btnIniciar);

    m_btnParar = new QPushButton("⏹️ Parar");
    connect(m_btnParar, &QPushButton::clicked, this, &ServicoManagerPanel::pararSelecionado);
    botoes->addWidget(m_btnParar);

    m_btnReiniciar = new QPushButton("🔄 Reiniciar");
    connect(m_btnReiniciar, &QPushButton::clicked, this, &ServicoManagerPanel::reiniciarSelecionado);
    botoes->addWidget(m_btnReiniciar);

    principal->addLayout(botoes);

    // 🔄 Sincronização em tempo real
    connect(&FydelisServices::instancia(), &FydelisServices::servicoStatusAlterado,
            this, &ServicoManagerPanel::alterarStatusServico);

    atualizarLista();
}

void ServicoManagerPanel::atualizarLista() {
    m_lista->clear();
    
    for (auto* serv : FydelisServices::instancia().todosServicos()) {
        QString statusTxt = statusParaTexto(serv->status);
        QString cor = statusParaCor(serv->status);
        
        QListWidgetItem* item = new QListWidgetItem(
            QString("%1 | %2 — %3").arg(statusTxt, serv->nomeExibicao, serv->versao),
            m_lista
        );
        item->setForeground(QColor(cor));
        item->setData(Qt::UserRole, serv->id);
    }

    // Detalhes do selecionado
    auto selecionado = m_lista->currentItem();
    if (selecionado) {
        QString id = selecionado->data(Qt::UserRole).toString();
        auto* serv = FydelisServices::instancia().obterServico(id);
        if (serv) {
            m_lblDetalhes->setText(
                QString("<b>%1</b><br>"
                        "Status: <span style='color:%2'>%3</span><br>"
                        "Versão: %4<br>"
                        "Início: %5<br>"
                        "<i>%6</i>")
                .arg(serv->nomeExibicao)
                .arg(statusParaCor(serv->status))
                .arg(statusParaTexto(serv->status))
                .arg(serv->versao)
                .arg(serv->tipoInicio == Inicializacao::Automatico ? "Automático" : "Manual")
                .arg(serv->descricao)
            );
            m_btnIniciar->setEnabled(serv->podeIniciar());
            m_btnParar->setEnabled(serv->podeParar());
        }
    }
}

void ServicoManagerPanel::iniciarSelecionado() {
    auto item = m_lista->currentItem();
    if (!item) return;
    QString id = item->data(Qt::UserRole).toString();
    FydelisServices::instancia().iniciarServico(id);
    QMessageBox::information(this, "Sucesso", "✅ Serviço iniciado!");
    atualizarLista();
}

void ServicoManagerPanel::pararSelecionado() {
    auto item = m_lista->currentItem();
    if (!item) return;
    QString id = item->data(Qt::UserRole).toString();
    FydelisServices::instancia().pararServico(id);
    QMessageBox::information(this, "Sucesso", "⏹️ Serviço parado!");
    atualizarLista();
}

void ServicoManagerPanel::reiniciarSelecionado() {
    pararSelecionado();
    iniciarSelecionado();
}

void ServicoManagerPanel::alterarStatusServico(const QString&, ServicoStatus) {
    atualizarLista();
}

QString ServicoManagerPanel::statusParaTexto(ServicoStatus s) {
    switch(s) {
    case ServicoStatus::Executando: return "✅ EM EXECUÇÃO";
    case ServicoStatus::Parado: return "⏹️ PARADO";
    case ServicoStatus::Pausado: return "⏸️ PAUSADO";
    case ServicoStatus::Erro: return "❌ ERRO";
    default: return "❓ DESCONHECIDO";
    }
}

QString ServicoManagerPanel::statusParaCor(ServicoStatus s) {
    switch(s) {
    case ServicoStatus::Executando: return "#00FF88";
    case ServicoStatus::Parado: return "#FF8800";
    case ServicoStatus::Pausado: return "#FFFF00";
    case ServicoStatus::Erro: return "#FF4444";
    default: return "#888888";
    }
}