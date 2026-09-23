#include "cvepanel.h"
#include "cvemonitor.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QMessageBox>

CVEPanel::CVEPanel(QWidget* parent) : QDialog(parent) {
    setWindowTitle("🛡️ Auditoria de Segurança — CVE Shield");
    resize(900, 600);
    setStyleSheet(R"(
        QDialog { background: #0f172a; color: #e2e8f0; }
        QLabel { font-size: 14px; }
        QListWidget { background: #1e293b; border: 1px solid #334155; font-family: Consolas; }
    )");

    QVBoxLayout* principal = new QVBoxLayout(this);
    principal->setSpacing(12);
    principal->setContentsMargins(20, 20, 20, 20);

    // 📊 Cabeçalho
    m_lblStatus = new QLabel("✅ SISTEMA MONITORADO — Auditoria Ativa");
    m_lblStatus->setStyleSheet("font-size: 18px; font-weight: bold; color: #00FF88;");
    principal->addWidget(m_lblStatus);

    // 📈 Contadores
    QHBoxLayout* cnt = new QHBoxLayout;
    m_lblCritico = new QLabel("🔴 Crítico: 0");
    m_lblCritico->setStyleSheet("font-size: 16px; color: #ff4444; font-weight: bold;");
    m_lblAlto = new QLabel("🟠 Alto: 0");
    m_lblAlto->setStyleSheet("font-size: 16px; color: #ff9900; font-weight: bold;");
    m_lblTotal = new QLabel("📋 Total: 0");
    cnt->addWidget(m_lblCritico);
    cnt->addWidget(m_lblAlto);
    cnt->addWidget(m_lblTotal);
    principal->addLayout(cnt);

    // 📋 Lista
    m_lista = new QListWidget;
    principal->addWidget(new QLabel("📋 Últimos Eventos:"));
    principal->addWidget(m_lista);

    // 🔗 CONEXÕES — EM TEMPO REAL
    connect(&CVEMonitor::instancia(), &CVEMonitor::alertaCritico,
            this, [this](const QString& cve, const QString& msg) {
                m_lblStatus->setText("🚨 AMEAÇA CRÍTICA DETECTADA!");
                m_lblStatus->setStyleSheet("font-size: 18px; font-weight: bold; color: #ff4444;");
                QMessageBox::critical(this, "🛡️ ALERTA DE SEGURANÇA — CRÍTICO", msg);
                carregarLista();
                QTimer::singleShot(6000, [this]() {
                    m_lblStatus->setText("✅ SISTEMA MONITORADO");
                    m_lblStatus->setStyleSheet("font-size: 18px; font-weight: bold; color: #00FF88;");
                });
            });

    connect(&CVEMonitor::instancia(), &CVEMonitor::estatisticasAtualizadas,
            this, [this](int cr, int al, int total) {
                m_lblCritico->setText(QString("🔴 Crítico: %1").arg(cr));
                m_lblAlto->setText(QString("🟠 Alto: %1").arg(al));
                m_lblTotal->setText(QString("📋 Total: %1").arg(total));
            });

    // ⏳ Atualização
    QTimer* timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &CVEPanel::carregarLista);
    timer->start(4000);
    carregarLista();
}

void CVEPanel::carregarLista() {
    m_lista->clear();
    auto evts = CVEMonitor::instancia().ultimosEventos(30);
    for (const auto& e : evts) {
        QString linha = QString("%1 | %2 | %3 | %4")
            .arg(e["data"].toString(), e["risco"].toString().left(4),
                 e["cve"].toString().left(15), e["modulo"].toString());

        QListWidgetItem* item = new QListWidgetItem(linha);
        if (e["risco"].toString() == "CRITICO") item->setForeground(QColor("#ff4444"));
        else if (e["risco"].toString() == "ALTO") item->setForeground(QColor("#ff9900"));
        else if (e["risco"].toString() == "MEDIO") item->setForeground(QColor("#ffdd00"));
        else item->setForeground(QColor("#88cc88"));

        m_lista->addItem(item);
    }
}