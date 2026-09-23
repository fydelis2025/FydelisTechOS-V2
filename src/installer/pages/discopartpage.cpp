#include "discopartpage.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QMessageBox>

DiscoPartPage::DiscoPartPage(QWidget *parent) : QWizardPage(parent) {
    setTitle("Disco e Particionamento");
    setSubTitle("Escolha onde instalar o FydelisTech OS.");

    m_pm = new PartitionManager(this);

    // Lista de discos
    m_listaDiscos = new QListWidget;
    connect(m_listaDiscos, &QListWidget::itemSelectionChanged, this, &DiscoPartPage::atualizarEspaco);

    // Opções
    m_radioDiscoInteiro = new QRadioButton("Instalar usando o disco inteiro (recomendado)");
    m_radioParticaoManual = new QRadioButton("Eu quero particionar manualmente");
    m_radioDiscoInteiro->setChecked(true);

    m_lblEspaco = new QLabel;
    m_lblEspaco->setStyleSheet("padding:8px; border-radius:6px; background:#1e293b;");

    registerField("usarDiscoInteiro", m_radioDiscoInteiro);

    // Layout
    auto *lay = new QVBoxLayout;
    lay->addWidget(new QLabel("Disco disponível:"));
    lay->addWidget(m_listaDiscos);
    lay->addSpacing(10);
    lay->addWidget(m_radioDiscoInteiro);
    lay->addWidget(m_radioParticaoManual);
    lay->addSpacing(10);
    lay->addWidget(m_lblEspaco);
    lay->addStretch();
    setLayout(lay);
}

void DiscoPartPage::initializePage() {
    m_listaDiscos->clear();
    m_discos = m_pm->listarDiscos();

    for (const Particao &p : m_discos) {
        QString tamanhoGB = QString::number(p.tamanhoTotal / (1024.0*1024*1024), 'f', 2) + " GB";
        QString texto = QString("%1 — %2 (%3)").arg(p.dispositivo, p.nome, tamanhoGB);
        auto *item = new QListWidgetItem(texto);
        item->setData(Qt::UserRole, QVariant::fromValue(p));
        m_listaDiscos->addItem(item);
    }
    if (m_listaDiscos->count() > 0) m_listaDiscos->setCurrentRow(0);
}

void DiscoPartPage::atualizarEspaco() {
    if (!m_listaDiscos->currentItem()) return;
    Particao p = m_listaDiscos->currentItem()->data(Qt::UserRole).value<Particao>();
    qint64 gb = p.tamanhoTotal / (1024*1024*1024);
    bool ok = m_pm->validarParticao(p);

    if (ok) {
        m_lblEspaco->setText(QString("✅ Espaço suficiente: %1 GB<br>Mínimo necessário: 8 GB").arg(gb));
        m_lblEspaco->setStyleSheet("padding:8px; border-radius:6px; background:#064e3b; color:#a7f3d0;");
    } else {
        m_lblEspaco->setText(QString("❌ Espaço insuficiente: %1 GB<br>Mínimo necessário: 8 GB").arg(gb));
        m_lblEspaco->setStyleSheet("padding:8px; border-radius:6px; background:#7f1d1d; color:#fecaca;");
    }
}

bool DiscoPartPage::validatePage() {
    if (!m_listaDiscos->currentItem()) {
        QMessageBox::warning(this, "Aviso", "Selecione um disco!");
        return false;
    }
    Particao p = m_listaDiscos->currentItem()->data(Qt::UserRole).value<Particao>();
    if (!m_pm->validarParticao(p)) {
        QMessageBox::warning(this, "Espaço Insuficiente", "O disco precisa ter pelo menos 8 GB livres.");
        return false;
    }
    registerField("dispositivo", p.dispositivo);
    return true;
}