#include "updatepanel.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QMessageBox>
#include <QDesktopServices>
#include <QUrl>

UpdatePanel::UpdatePanel(QWidget *parent) : QDialog(parent) {
    setWindowTitle("🔄 Atualizações — FydelisTech OS");
    resize(600, 450);

    QVBoxLayout* principal = new QVBoxLayout(this);
    principal->setSpacing(16);
    principal->setContentsMargins(20, 20, 20, 20);

    // 📌 Versão Atual
    m_lblVersaoAtual = new QLabel;
    m_lblVersaoAtual->setText(QString(
        "<b>Versão Instalada:</b> FydelisTech OS %1")
        .arg(FydelisUpdater::instancia().versaoAtual()));
    m_lblVersaoAtual->setStyleSheet("font-size: 14px; padding: 10px; background: #1e293b; border-radius: 8px;");
    principal->addWidget(m_lblVersaoAtual);

    // 📋 Status
    m_lblStatus = new QLabel("Clique em Verificar para checar atualizações...");
    m_lblStatus->setWordWrap(true);
    principal->addWidget(m_lblStatus);

    // 📝 Mudanças
    m_lblMudancas = new QLabel;
    m_lblMudancas->setWordWrap(true);
    m_lblMudancas->setStyleSheet("padding: 12px; background: #0f172a; border-radius: 8px;");
    m_lblMudancas->setVisible(false);
    principal->addWidget(m_lblMudancas);

    // 📊 Barra de Progresso
    m_barraProgresso = new QProgressBar;
    m_barraProgresso->setVisible(false);
    principal->addWidget(m_barraProgresso);

    // 🔘 Botões
    QHBoxLayout* botoes = new QHBoxLayout;
    
    m_btnVerificar = new QPushButton("🔍 Verificar Atualizações");
    m_btnVerificar->setStyleSheet("padding: 10px; font-weight: bold;");
    connect(m_btnVerificar, &QPushButton::clicked, this, &UpdatePanel::verificarAgora);
    botoes->addWidget(m_btnVerificar);

    m_btnInstalar = new QPushButton("⬇️ Baixar e Instalar");
    m_btnInstalar->setStyleSheet("background: #00AA55; padding: 10px; font-weight: bold;");
    m_btnInstalar->setEnabled(false);
    connect(m_btnInstalar, &QPushButton::clicked, this, &UpdatePanel::baixarEInstalar);
    botoes->addWidget(m_btnInstalar);

    principal->addLayout(botoes);

    // 🔗 Conexões com o Atualizador
    connect(&FydelisUpdater::instancia(), &FydelisUpdater::verificacaoConcluida,
            this, &UpdatePanel::aoVerificarConcluida);
    connect(&FydelisUpdater::instancia(), &FydelisUpdater::downloadProgresso,
            this, &UpdatePanel::aoProgresso);
    connect(&FydelisUpdater::instancia(), &FydelisUpdater::downloadConcluido,
            this, &UpdatePanel::aoDownloadConcluido);
    connect(&FydelisUpdater::instancia(), &FydelisUpdater::erroOcorrido,
            this, &UpdatePanel::aoErro);
}

void UpdatePanel::verificarAgora() {
    m_btnVerificar->setEnabled(false);
    m_lblStatus->setText("🔄 Conectando ao servidor...");
    FydelisUpdater::instancia().verificarAtualizacoes();
}

void UpdatePanel::aoVerificarConcluida(const UpdateInfo& info) {
    m_btnVerificar->setEnabled(true);
    
    if (!info.disponivel) {
        m_lblStatus->setText("✅ Você já usa a versão mais recente!");
        m_lblStatus->setStyleSheet("color: #00FF88; font-weight: bold;");
        m_btnInstalar->setEnabled(false);
        return;
    }

    QString avisoCritico = info.eCritico ? 
        "<span style='color:#FF4444; font-weight:bold'>⚠️ ATUALIZAÇÃO CRÍTICA — Recomendado instalar agora!</span><br><br>" : "";

    m_lblStatus->setText(QString(
        "🎉 <b>Nova Versão Disponível!</b><br>"
        "Atual: %1 → Nova: <b>%2</b><br>"
        "Lançamento: %3<br><br>%4")
        .arg(info.versaoAtual)
        .arg(info.versaoNova)
        .arg(info.dataLancamento)
        .arg(avisoCritico));
    
    m_lblMudancas->setText("<b>📋 O que mudou:</b><br>" + info.logMudancas);
    m_lblMudancas->setVisible(true);
    m_btnInstalar->setEnabled(true);
}

void UpdatePanel::baixarEInstalar() {
    m_btnInstalar->setEnabled(false);
    m_btnVerificar->setEnabled(false);
    m_barraProgresso->setVisible(true);
    m_lblStatus->setText("⬇️ Baixando atualização...");
    FydelisUpdater::instancia().baixarAtualizacao();
}

void UpdatePanel::aoProgresso(qint64 recebido, qint64 total) {
    if (total > 0) {
        m_barraProgresso->setValue(static_cast<int>((recebido * 100) / total));
    }
}

void UpdatePanel::aoDownloadConcluido(const QString& caminho) {
    m_barraProgresso->setVisible(false);
    m_lblStatus->setText(QString("✅ Download concluído!<br>Arquivo: %1").arg(caminho));
    
    QMessageBox::StandardButton resp = QMessageBox::question(this,
        "Instalar Agora?",
        "A atualização foi baixada com sucesso!\n\nDeseja instalar agora?\n\nO sistema será reiniciado.");
    
    if (resp == QMessageBox::Yes) {
        FydelisUpdater::instancia().instalarAtualizacao();
    }
}

void UpdatePanel::aoErro(const QString& mensagem) {
    m_btnVerificar->setEnabled(true);
    m_btnInstalar->setEnabled(false);
    m_lblStatus->setText("❌ Erro: " + mensagem);
    m_lblStatus->setStyleSheet("color: #FF6666;");
}