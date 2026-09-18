#include "installwizard.h"
#include "pages/bemvindopage.h"
#include "pages/idiomapage.h"
#include "pages/discopartpage.h"
#include "pages/userpage.h"
#include "pages/resumopage.h"
#include "pages/installpage.h"
#include "pages/conclupage.h"
#include <QMessageBox>

InstallWizard::InstallWizard(QWidget *parent) : QWizard(parent) {
    setWindowTitle("FydelisTech OS — Instalador");
    setWindowIcon(QIcon(":/images/logo.png"));
    resize(900, 600);
    
    // 🎨 Estilo moderno
    setStyleSheet(R"(
        QWizard { background: qlineargradient(x1:0,y1:0,x2:0,y2:1, stop:0 #0f172a, stop:1 #1e293b); color: white; }
        QLabel { color: white; font-size: 13px; }
        QLineEdit { padding: 8px; border-radius: 6px; border: 1px solid #475569; background: #1e293b; color: white; }
        QPushButton { padding: 8px 16px; border-radius: 6px; background: #2563eb; color: white; font-weight: bold; }
        QPushButton:hover { background: #3b82f6; }
        QProgressBar { border-radius: 6px; background: #1e293b; text-align: center; height: 24px; }
        QProgressBar::chunk { background: qlineargradient(x1:0,y1:0,x2:1,y2:0, stop:0 #2563eb, stop:1 #8b5cf6); border-radius: 6px; }
    )");

    // 📑 Páginas em ordem
    addPage(new BemVindoPage);      // 1 — Logo + Boas-vindas
    addPage(new IdiomaPage);        // 2 — Escolher idioma
    addPage(new DiscoPartPage);     // 3 — Particionamento
    addPage(new UserPage);          // 4 — Usuário + Senha
    addPage(new ResumoPage);        // 5 — Revisão
    addPage(new InstallPage);       // 6 — ⚙️ Instalação + Progress + Slideshow
    addPage(new ConcluPage);        // 7 — ✅ Concluído
}

void InstallWizard::accept() {
    QMessageBox::information(this, "Instalação Concluída",
        "✅ O FydelisTech OS foi instalado com sucesso!\n\n"
        "O sistema será reiniciado agora.\n"
        "Bem-vindo ao futuro, feito no Brasil! 🇧🇷");
    QWizard::accept();
}